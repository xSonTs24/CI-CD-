from flask import Blueprint, jsonify, request, session
from orders.models.order_model import Order
from db.db import db
import requests
import os

order_controller = Blueprint('order_controller', __name__)

CONSUL_HOST = os.environ.get("CONSUL_HOST", "consul")

def discover_service(service_name):
    response = requests.get(
        f"http://{CONSUL_HOST}:8500/v1/catalog/service/{service_name}"
    )

    services = response.json()

    if not services:
        return None

    service = services[0]

    address = service['ServiceAddress'] or service['Address']
    port = service['ServicePort']

    return f"http://{address}:{port}"

@order_controller.route('/api/orders', methods=['GET'])
def get_all_orders():
    orders = Order.query.all()

    result = []
    for order in orders:
        result.append({
            "id": order.id,
            "user_name": order.user_name,
            "user_email": order.user_email,
            "total": order.total
        })

    return jsonify(result), 200

@order_controller.route('/api/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    order = Order.query.get(order_id)

    if not order:
        return jsonify({"message": "Orden no encontrada"}), 404

    return jsonify({
        "id": order.id,
        "user_name": order.user_name,
        "user_email": order.user_email,
        "total": order.total
    }), 200

@order_controller.route('/api/orders', methods=['POST'])
def create_order():

    data = request.get_json()

    username = data.get('username')
    products = data.get('products')

    if not username:
        return jsonify({'message': 'Usuario requerido'}), 400

    if not products or not isinstance(products, list):
        return jsonify({'message': 'Falta o es inválida la información de los productos'}), 400

    users_service = discover_service("users-service")

    if not users_service:
        return jsonify({'message': 'Servicio de usuarios no disponible'}), 503

    # Buscar usuario por username
    user_response = requests.get(f"{users_service}/api/users")

    if user_response.status_code != 200:
        return jsonify({'message': 'Error consultando usuarios'}), 500

    users = user_response.json()
    user = next((u for u in users if u['username'] == username), None)

    if not user:
        return jsonify({'message': 'Usuario no encontrado'}), 404

    user_email = user['email']

    products_service = discover_service("products-service")
    

    if not products_service:
        return jsonify({'message': 'Servicio de productos no disponible'}), 503

    total = 0

    for item in products:

        product_id = item.get("id")
        quantity = item.get("quantity")

        if not product_id or not quantity:
            return jsonify({'message': 'Datos de producto inválidos'}), 400

        response = requests.get(f"{products_service}/products/{product_id}")

        if response.status_code == 404:
            return jsonify({'message': f'Producto {product_id} no existe'}), 404

        product_data = response.json()

        if product_data['unidades'] < quantity:
            return jsonify({'message': f'Inventario insuficiente para {product_data["nombre"]}'}), 409
        
        #Multiplicar la cantidad por el precio
        total += product_data['precio'] * quantity

        # Actualizar inventario
        update_response = requests.put(
            f"{products_service}/products/{product_id}",
            json={
                "nombre": product_data["nombre"],
                "unidades": product_data["unidades"] - quantity,
                "precio": product_data["precio"]
            }
        )

        if update_response.status_code != 200:
            return jsonify({'message': 'Error actualizando inventario'}), 500

    new_order = Order(
        user_name=username,
        user_email=user_email,
        total=total
    )

    db.session.add(new_order)
    db.session.commit()

    return jsonify({
        'message': 'Orden creada exitosamente',
        'total': total
    }), 201