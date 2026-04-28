from db.db import db

class Product(db.Model):
    __tablename__ = 'productos'

    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(50), nullable=True)
    unidades = db.Column(db.Integer, nullable=True)
    precio = db.Column(db.Float, nullable=True)

    def __init__(self, nombre, unidades, precio):
        self.nombre = nombre
        self.unidades = unidades
        self.precio = precio

