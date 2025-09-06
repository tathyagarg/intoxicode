from sanic import HTTPResponse, Sanic, json
from sanic.response import text
from sanic_ext import CountedRequest

import jwt

from .models import Package, User
from .database import db, SECRET_KEY

from .auth import blueprint as auth_blueprint
from .packages import blueprint as packages_blueprint

import time

app = Sanic("IntoxicodePackages", request_class=CountedRequest)
app.config.OAS_UI_DEFAULT = "swagger"
app.config.OAS_UI_REDOC = False
app.config.HEALTH = True
app.config.HEALTH_ENDPOINT = True
app.ext.openapi.add_security_scheme("api_key", "apiKey")

app.blueprint(auth_blueprint)
app.blueprint(packages_blueprint)

EXPIRY_TIME = 60 * 60 * 24

@app.before_server_start
async def setup_db(app, _):
    with db:
        db.create_tables([User, Package], safe=True)
    app.ctx.db = db

@app.on_request
async def connect_db(req):
    app.ctx.db.connect()
    if req.token:
        try:
            message = jwt.decode(req.token, SECRET_KEY, algorithms=['HS256'])
        except jwt.InvalidSignatureError:
            return json({"error": "Invalid token"}, status=401)

        iat = message.get('iat')

        if not iat or (time.time() - iat) > EXPIRY_TIME:
            return json({"error": "Token has expired"}, status=401)

        req.ctx.user = User.get_or_none(User.username == message['sub'])

@app.on_response
async def close_db(*_):
    if not app.ctx.db.is_closed():
        app.ctx.db.close()


@app.get("/")
async def index(request):
    return text("Welcome to Intoxicode Packages!")


__all__ = ['app']

