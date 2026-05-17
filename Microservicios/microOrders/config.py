import os

class Config:
    MYSQL_HOST = os.environ.get("MYSQL_HOST", "db_orders")
    MYSQL_USER = os.environ.get("MYSQL_USER", "root")
    MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD", "root")
    MYSQL_DB = os.environ.get("MYSQL_DB", "ordersdb")

    SQLALCHEMY_DATABASE_URI = f"mysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:3306/{MYSQL_DB}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    CONSUL_HOST = os.environ.get("CONSUL_HOST", "consul")