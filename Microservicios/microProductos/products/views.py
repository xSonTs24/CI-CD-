from flask import Flask, render_template
from products.controllers.product_controller import product_controller
from db.db import db
from flask_cors import CORS
from flask_consulate import Consul
import os

app = Flask(__name__)
CORS(app)
app.config.from_object('config.Config')
db.init_app(app)

# Registrando el blueprint del controlador de productos
app.register_blueprint(product_controller)

# -------- HEALTH CHECK --------
@app.route('/healthcheck')
def health_check():
    return '', 200


CONSUL_HOST = os.environ.get("CONSUL_HOST", "consul")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "products-service")
SERVICE_PORT = int(os.environ.get("SERVICE_PORT", 5003))
SERVICE_HOST = os.environ.get("SERVICE_HOST", "microproductos")

consul = Consul(app=app, host=CONSUL_HOST)

consul.register_service(
    name=SERVICE_NAME,
    address=SERVICE_HOST,
    interval='10s',
    tags=['products', 'flask'],
    port=SERVICE_PORT,
    httpcheck=f'http://{SERVICE_HOST}:{SERVICE_PORT}/healthcheck'
)

if __name__ == '__main__':
    app.run()
