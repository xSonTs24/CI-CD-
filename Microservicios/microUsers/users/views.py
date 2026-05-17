from flask import Flask, render_template
from users.controllers.user_controller import user_controller
from db.db import db
from flask_cors import CORS
from flask_consulate import Consul
import os 
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
CORS(app)
app.config.from_object('config.Config')
db.init_app(app)

# Registrando el blueprint del controlador de usuarios
app.register_blueprint(user_controller)

metrics = PrometheusMetrics(app)
# -------- HEALTH CHECK --------
@app.route('/healthcheck')
def health_check():
    return '', 200

app.secret_key = "super_secret_key"


# -------- CONSUL --------
CONSUL_HOST = os.environ.get("CONSUL_HOST", "consul")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "users-service")
SERVICE_PORT = int(os.environ.get("SERVICE_PORT", 5002))
SERVICE_HOST = os.environ.get("SERVICE_HOST", "microusers")

consul = Consul(app=app, host=CONSUL_HOST)

consul.register_service(
    
    name=SERVICE_NAME,
    interval='10s',
    address=SERVICE_HOST,
    tags=['users', 'flask'],
    port=SERVICE_PORT,
    httpcheck=f'http://{SERVICE_HOST}:{SERVICE_PORT}/healthcheck'
)
if __name__ == '__main__':
    app.run()
