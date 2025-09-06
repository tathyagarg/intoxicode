from json import loads
import os

from sanic import json, Blueprint
from sanic.response import file_stream
from sanic_ext import openapi

from .models import Package 
from .utils import is_valid_tar_gz, is_valid_version

blueprint = Blueprint('Packages', url_prefix='/packages')

@blueprint.post("/create")
@openapi.definition(
    body={
        "multipart/form-data": {
            "type": "object",
            "properties": {
                "json": {
                    "type": "string",
                    "description": "JSON string containing package metadata",
                    "example": '{"name": "mypackage", "version": "1.0.0", "description": "A sample package"}'
                },
                "package": {
                    "type": "string",
                    "format": "binary",
                    "description": "The package file in tar.gz format"
                }
            },
            "required": ["json", "package"]
        }
    },
    description="Create a new package",
    summary="Upload a new package",
    response=[
        {
            "status": 201,
            "description": "Package created successfully",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "message": {"type": "string", "example": "Package created"}
                    }
                }
            }
        },
        {
            "status": 400,
            "description": "Bad request - missing fields or invalid file",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Invalid JSON"},
                        "code": {"type": "integer", "example": 400}
                    }
                }
            }
        },
        {
            "status": 401,
            "description": "Unauthorized - authentication required",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Authentication required"},
                        "code": {"type": "integer", "example": 401}
                    }
                }
            }
        },
        {
            "status": 403,
            "description": "Forbidden - permission denied",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "You do not have permission to update this package"},
                        "code": {"type": "integer", "example": 403}
                    }
                }
            }
        },
        {
            "status": 409,
            "description": "Conflict - package already exists",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Package with this name and version already exists"},
                        "code": {"type": "integer", "example": 409}
                    }
                }
            }
        }
    ],
    secured={"apiKey": []}
)
async def create_package(request):
    data = loads(request.form.get('json'))
    if not data:
        return json({"error": "Invalid JSON"}, status=400)

    file = request.files.get('package')
    if not file:
        return json({"error": "Package file is required"}, status=400)

    if len(file.body) > 50 * 1024 * 1024:
        return json({"error": "Package file is too large"}, status=400)

    name = data.get('name')
    version = data.get('version')
    description = data.get('description', '')

    if not name or not version:
        return json({"error": "Name and version are required"}, status=400)

    if not request.ctx.user:
        return json({"error": "Authentication required"}, status=401)

    if not is_valid_version(version):
        return json({"error": "Version must follow semantic versioning (e.g., v1.0.0)"}, status=400)

    existing_package = Package.get_or_none((Package.name == name) & (Package.version == version))
    if existing_package:
        return json({"error": "Package with this name and version already exists"}, status=409)

    package_line = Package.get_or_none(Package.name == name)
    if package_line and package_line.author != request.ctx.user:
        return json({"error": "You do not have permission to update this package"}, status=403)

    file_path = f'packages/{name}_{version}.tar.gz'

    with open(file_path, 'wb') as f:
        f.write(file.body)

    if not is_valid_tar_gz(file_path):
        os.remove(file_path)
        return json({"error": "Invalid tar.gz file"}, status=400)

    major, minor, patch = map(int, version.lstrip('v').split('.'))

    _ = Package.create(
        name=name,
        version=version,

        major=major,
        minor=minor,
        patch=patch,

        description=description,
        author=request.ctx.user
    )

    return json({"message": "Package created"}, status=201)

@blueprint.get("/download/<name>/<version>")
@openapi.definition(
    description="Download a package by name and version",
    summary="Download package",
    parameter=[
        {
            "name": "name",
            "in": "path",
            "required": True,
            "description": "The name of the package to download"
        },
        {
            "name": "version",
            "in": "path",
            "required": True,
            "description": "The version of the package to download"
        }
    ],
    response=[
        {
            "status": 200,
            "description": "Package file",
            "content": {
                "application/gzip": {
                    "schema": {
                        "type": "string",
                        "format": "binary"
                    }
                }
            }
        },
        {
            "status": 404,
            "description": "Package not found",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Package not found"},
                        "code": {"type": "integer", "example": 404}
                    }
                }
            }
        }
    ]
)
async def download_package(_, name, version):
    if version == 'latest':
        package = Package \
            .select() \
            .where(Package.name == name) \
            .order_by(
                Package.major.desc(),
                Package.minor.desc(),
                Package.patch.desc()
            ) \
            .first()

        if not package:
            return json({"error": "Package not found"}, status=404)

        version = package.version

    package = Package.get_or_none((Package.name == name) & (Package.version == version))
    if not package:
        return json({"error": "Package not found"}, status=404)

    file_path = f'packages/{name}_{version}.tar.gz'
    if not os.path.exists(file_path):
        return json({"error": "Package file not found"}, status=404)

    if (not is_valid_version(version)) and version != 'latest':
        return json({"error": "Invalid version format"}, status=400)

    return await file_stream(file_path, mime_type='application/gzip', filename=f'{name}-{version}.tar.gz')


@blueprint.get("/info/<name>")
async def package_info(req, name):
    package_limit = req.args.get('limit', 5)

    packages = Package.select().where(Package.name == name).order_by(
        Package.major.desc(),
        Package.minor.desc(),
        Package.patch.desc()
    ).limit(package_limit)

    if not packages.exists():
        return json({"error": "Package not found"}, status=404)

    package_list = [
        {
            "name": pkg.name,
            "version": pkg.version,
            "description": pkg.description,
            "author": pkg.author.username
        }
        for pkg in packages
    ]

    return json(package_list, status=200)

