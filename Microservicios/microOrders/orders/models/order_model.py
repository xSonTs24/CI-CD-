from db.db import db

class Order(db.Model):
    __tablename__ = "orders"

    id = db.Column(db.Integer, primary_key=True)
    user_name = db.Column(db.String(255))
    user_email = db.Column(db.String(255))
    total = db.Column(db.Float)