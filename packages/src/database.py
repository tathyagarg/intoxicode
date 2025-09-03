from peewee import SqliteDatabase
from dotenv import load_dotenv

import os

assert load_dotenv()

DATABASE_PATH = os.getenv('DATABASE_PATH', 'database.db')
SECRET_KEY = os.getenv('SECRET_KEY', 'supersecretkey')

db = SqliteDatabase(DATABASE_PATH)
