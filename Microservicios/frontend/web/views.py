from flask import Flask, render_template
from flask_cors import CORS
from flask_consulate import Consul
import os 

app = Flask(__name__)
CORS(app)
app.config.from_object('config.Config')

# Ruta para renderizar el template index.html
@app.route('/')
def index():
    return render_template('index.html')

# Ruta para renderizar el template users.html
@app.route('/users')
def users():
    return render_template('users.html')

@app.route('/editUser/<string:id>')
def edit_user(id):
    print("id recibido",id)
    return render_template('editUser.html', id=id)

@app.route('/editProduct/<int:id>')
def edit_product(id):
    return render_template('editProduct.html', id=id)

@app.route('/products')
def products():
    return render_template('index.html')

@app.route('/orders')
def orders():
    return render_template('orders.html')

@app.route('/ordenes')
def ordenes():
    return render_template('ordenes.html')

# -------- HEALTH CHECK --------
@app.route('/healthcheck')
def health_check():
    return '', 200


# -------- CONSUL --------
CONSUL_HOST = os.environ.get("CONSUL_HOST", "consul")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "front-service")
SERVICE_PORT = int(os.environ.get("SERVICE_PORT", 5001))
SERVICE_HOST = os.environ.get("SERVICE_HOST", "frontend")

consul = Consul(app=app, host=CONSUL_HOST)

consul.register_service(
    name=SERVICE_NAME,
    interval='10s',
    tags=['front', 'flask'],
    port=SERVICE_PORT,
    httpcheck=f'http://{SERVICE_HOST}:{SERVICE_PORT}/healthcheck'
)

if __name__ == '__main__':
    app.run()
