from flask import Blueprint, request, jsonify
from products.models.product_model import Product
from db.db import db

product_controller = Blueprint('product_controller', __name__)

@product_controller.route('/products', methods=['GET'])
def get_products():
    products = Product.query.all()
    result = []

    for p in products:
        result.append({
            'id': p.id,
            'nombre': p.nombre,
            'unidades': p.unidades,
            'precio': p.precio
        })

    return jsonify(result)

@product_controller.route('/products/<int:id>', methods=['GET'])
def get_product(id):
    product = Product.query.get(id)

    if not product:
        return jsonify({
            "message": "Producto no encontrado"
        }), 404

    return jsonify({
        'id': product.id,
        'nombre': product.nombre,
        'unidades': product.unidades,
        'precio': product.precio
    }), 200


@product_controller.route('/products', methods=['POST'])
def create_product():
    data = request.json

    product = Product(
        data['nombre'],
        data['unidades'],
        data['precio']
    )

    db.session.add(product)
    db.session.commit()

    return jsonify({'message': 'Producto creado correctamente'}), 201


@product_controller.route('/products/<int:id>', methods=['PUT'])
def update_product(id):
    data=request.json

    product= Product.query.get(id)

    if not product:
        return jsonify({'message': 'Producto no encontrado'}), 404


    product.nombre = data['nombre']
    product.unidades = data['unidades']
    product.precio = data['precio']

    db.session.commit()

    return jsonify({'message': 'Producto actualizado correctamente'})


@product_controller.route('/products/<int:id>', methods=['DELETE'])
def delete_product(id):
    product = Product.query.get(id)

    if not product:
        return jsonify({'message': 'Producto no encontrado'}), 404

    db.session.delete(product)
    db.session.commit()

    return jsonify({'message': 'Producto eliminado correctamente'})

