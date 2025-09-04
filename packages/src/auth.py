from sanic import json, Blueprint
from sanic_ext import openapi

import jwt
import bcrypt

from .database import SECRET_KEY
from .models import User
from .utils import make_jwt_message, verify_username

blueprint = Blueprint('Authentication', url_prefix='/auth')

@blueprint.post("/signup")
@openapi.definition(
    body={
        "application/json": {
            "type": "object",
            "properties": {
                "username": {"type": "string"},
                "password": {"type": "string"}
            },
            "required": ["username", "password"]
        }
    },
    description="User signup endpoint",
    summary="Create a new user",
    response=[
        {
            "status": 201,
            "description": "User created successfully",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "message": {"type": "string", "example": "User created successfully"},
                        "jwt": {"type": "string", "example": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
                    }
                }
            }
        },
        {
            "status": 400,
            "description": "Bad request - missing fields or invalid username",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Username and password are required"},
                        "code": {"type": "integer", "example": 400}
                    }
                }
            }
        },
        {
            "status": 409,
            "description": "Conflict - username already exists",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Username already exists"},
                        "code": {"type": "integer", "example": 409}
                    }
                }
            }
        }
    ],
)
async def signup(request):
    data = request.json
    if not data or 'username' not in data or 'password' not in data:
        return json({
            "error": "Username and password are required",
            "code": 400
        }, status=400)

    username = data['username'].lower()

    if (verif := verify_username(username))[0] is False:
        return json({
            "error": verif[1],
            "code": 400
        }, status=400)

    password = data['password']

    if User.select().where(User.username == username).exists():
        return json({
            "error": "Username already exists",
            "code": 409
        }, status=409)

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    user = User.create(username=username, password_hash=hashed_password)
    message = make_jwt_message(user.username)

    jwt_token = jwt.encode(message, SECRET_KEY, algorithm='HS256')

    return json({
        "message": "User created successfully",
        "jwt": jwt_token
    }, status=201)


@blueprint.post("/login")
@openapi.definition(
    body={
        "application/json": {
            "type": "object",
            "properties": {
                "username": {"type": "string"},
                "password": {"type": "string"}
            },
            "required": ["username", "password"]
        }
    },
    description="User login endpoint",
    summary="Login a user",
    response=[
        {
            "status": 200,
            "description": "Login successful",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "message": {"type": "string", "example": "Login successful"},
                        "jwt": {"type": "string", "example": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
                    }
                }
            }
        },
        {
            "status": 400,
            "description": "Bad request - missing fields",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Username and password are required"},
                        "code": {"type": "integer", "example": 400}
                    }
                }
            }
        },
        {
            "status": 401,
            "description": "Unauthorized - invalid credentials",
            "content": {
                "application/json": {
                    "type": "object",
                    "properties": {
                        "error": {"type": "string", "example": "Invalid username or password"},
                        "code": {"type": "integer", "example": 401}
                    }
                }
            }
        }
    ],
)
async def login(request):
    data = request.json
    if not data or 'username' not in data or 'password' not in data:
        return json({
            "error": "Username and password are required",
            "code": 400
        }, status=400)

    username = data['username'].lower()
    password = data['password']

    user = User.get_or_none(User.username == username)
    if not user or not bcrypt.checkpw(password.encode('utf-8'), user.password_hash.encode('utf-8')):
        return json({
            "error": "Invalid username or password",
            "code": 401
        }, status=401)

    message = make_jwt_message(user.username)
    jwt_token = jwt.encode(message, SECRET_KEY, algorithm='HS256')

    return json({
        "message": "Login successful",
        "jwt": jwt_token
    }, status=200)
