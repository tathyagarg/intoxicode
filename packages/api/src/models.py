from peewee import ForeignKeyField, IntegerField, Model, CharField
from .database import db

class User(Model):
    username = CharField(unique=True)
    password_hash = CharField()

    class Meta:
        database = db

class Package(Model):
    name = CharField()
    version = CharField()

    major = IntegerField()
    minor = IntegerField()
    patch = IntegerField()

    description = CharField(null=True)

    author = ForeignKeyField(User, backref='packages')

    class Meta:
        database = db
        indexes = (
            (('name', 'version'), True),
        )
