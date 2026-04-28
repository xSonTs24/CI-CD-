from flask import Flask
from db.db import db
from config import Config
from orders.controllers.order_controller import order_controller
from flask_consulate import Consul
from flask_cors import CORS

app = Flask(__name__)
app.config.from_object(Config)
CORS(app)

db.init_app(app)
app.register_blueprint(order_controller)

@app.route('/healthcheck')
def health():
    return '', 200

# ---- CONSUL ----
consul = Consul(app=app)

consul.register_service(
    name='orders-service',
    address='microorders',
    interval='10s',
    tags=['orders', 'flask'],
    port=5004,
    httpcheck='http://microorders:5004/healthcheck'
)

if __name__ == '__main__':
    app.run()