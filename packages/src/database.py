from peewee import SqliteDatabase
from dotenv import load_dotenv

import os

assert load_dotenv()

DATABASE_PATH = os.getenv('DATABASE_PATH', 'database.db')

db = SqliteDatabase(DATABASE_PATH)
