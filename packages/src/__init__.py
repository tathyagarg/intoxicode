from sanic import Sanic
from sanic.response import text
from sanic_ext import CountedRequest

from .models import Package, User
from .database import db

app = Sanic("IntoxicodePackages", request_class=CountedRequest)
app.config.OAS_UI_DEFAULT = "swagger"
app.config.OAS_UI_REDOC = False
app.config.HEALTH = True
app.config.HEALTH_ENDPOINT = True

@app.before_server_start
async def setup_db(app, _):
    with db:
        db.create_tables([User, Package], safe=True)
    app.ctx.db = db

@app.on_request
async def connect_db(_):
    app.ctx.db.connect()

@app.on_response
async def close_db(*_):
    if not app.ctx.db.is_closed():
        app.ctx.db.close()

@app.get("/")
async def index(request):
    return text("Welcome to Intoxicode Packages!")

__all__ = ['db', 'app']

