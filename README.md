# CI/CD Platform — DevOps End-to-End

Plataforma DevOps completa que integra control de versiones, pipeline CI/CD automatizado, orquestación de contenedores con Kubernetes y observabilidad con Prometheus y Grafana.

---

## Tabla de contenidos

- [Arquitectura del sistema](#arquitectura-del-sistema)
- [Tecnologías utilizadas](#tecnologías-utilizadas)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Requisitos previos](#requisitos-previos)
- [Instalación rápida](#instalación-rápida)
- [Instalación manual paso a paso](#instalación-manual-paso-a-paso)
- [Pipeline CI/CD](#pipeline-cicd)
- [Estrategias de despliegue](#estrategias-de-despliegue)
- [Monitoreo con Prometheus y Grafana](#monitoreo-con-prometheus-y-grafana)
- [Endpoints disponibles](#endpoints-disponibles)
- [Solución de problemas](#solución-de-problemas)

---

## Arquitectura del sistema

```
┌──────────────────────────────────────────────────────────────────────┐
│                            GitHub                                    │
│                                                                      │
│   ┌──────────┐   Pull Request   ┌──────────────────────────────────┐ │
│   │   main   │ ◄─────────────── │   develop  /  feature/*          │ │
│   └──────────┘                  └──────────────────────────────────┘ │
│                                              │ git push              │
│                                 ┌────────────▼───────────────────┐   │
│                                 │       GitHub Actions            │  │
│                                 │    (self-hosted runner)         │  │
│                                 └────────────┬───────────────────┘   │
└──────────────────────────────────────────────┼───────────────────────┘
                                               │
               ┌───────────────────────────────▼──────────────────────┐
               │              VM Ubuntu / VirtualBox                   │
               │                                                        │
               │   ┌──────────────────────────────────────────────┐   │
               │   │              Minikube (Kubernetes)            │   │
               │   │                                               │   │
               │   │  ┌──────────────────────────────────────┐     │   │
               │   │  │         Namespace: microapp           │    │   │
               │   │  │                                       │    │   │
               │   │  │   Ingress Controller (nginx)          │    │   │
               │   │  │       /          → frontend:5001      │    │   │
               │   │  │       /api/users → users-svc:5002     │    │   │
               │   │  │       /products  → products-svc:5003  │    │   │
               │   │  │       /api/orders→ orders-svc:5004    │    │   │
               │   │  │                                       │    │   │
               │   │  │   ┌─────────────────────────────┐     │    │   │
               │   │  │   │       Microservicios         │    │    │   │
               │   │  │   │  frontend     Flask :5001    │    │    │   │
               │   │  │   │  microUsers   Flask :5002 x2 │    │    │   │
               │   │  │   │  microProductos Flask:5003 x2│    │    │   │
               │   │  │   │  microOrders  Flask :5004 x2 │    │    │   │
               │   │  │   └─────────────────────────────┘    │    │   │
               │   │  │                                       │    │   │
               │   │  │   ┌─────────────────────────────┐    │    │   │
               │   │  │   │       Bases de datos         │    │    │   │
               │   │  │   │  db-users    MySQL 5.7       │    │    │   │
               │   │  │   │  db-products MySQL 5.7       │    │    │   │
               │   │  │   │  db-orders   MySQL 5.7       │    │    │   │
               │   │  │   └─────────────────────────────┘    │    │   │
               │   │  │                                       │    │   │
               │   │  │   Consul (service discovery :8500)    │    │   │
               │   │  └──────────────────────────────────────┘    │   │
               │   │                                               │   │
               │   │  ┌──────────────────────────────────────┐    │   │
               │   │  │        Namespace: monitoring          │    │   │
               │   │  │  Prometheus   :9090  (retención 7d)  │    │   │
               │   │  │  Grafana      :3000                   │    │   │
               │   │  │  Alertmanager :9093                   │    │   │
               │   │  │  MySQL Exporters x3                   │    │   │
               │   │  └──────────────────────────────────────┘    │   │
               │   └──────────────────────────────────────────────┘   │
               └───────────────────────────────────────────────────────┘
                                               │
               ┌───────────────────────────────▼──────────────────────┐
               │                     Docker Hub                        │
               │   xsonts/frontend:SHA                                 │
               │   xsonts/microusers:SHA                               │
               │   xsonts/microproductos:SHA                           │
               │   xsonts/microorders:SHA                              │
               └───────────────────────────────────────────────────────┘
```

### Flujo del pipeline

```
Developer hace push a develop
         │
         ▼
GitHub Actions detecta qué microservicio cambió
         │
    ┌────┴─────────────────────────────────┐
    │                                      │
    ▼                                      ▼
Solo el micro que cambió            Los demás no se tocan
    │
    ▼
Instalar dependencias del sistema
    │
    ▼
Correr pruebas automatizadas
    │ (si fallan, el pipeline se detiene aquí)
    ▼
docker build + docker push → Docker Hub (tag = SHA del commit)
    │
    ▼
kubectl apply → Kubernetes actualiza los pods
    │
    ├── Rolling Update (users, orders, frontend)
    └── Blue-Green Switch (products)
         │
         ▼
Prometheus recoge métricas → Grafana las visualiza
```

---

## Tecnologías utilizadas

| Categoría | Tecnología |
|---|---|
| Control de versiones | Git / GitHub |
| Pipeline CI/CD | GitHub Actions (self-hosted runner) |
| Contenedores | Docker / Docker Hub |
| Orquestación | Kubernetes (Minikube) |
| Empaquetado K8s | Helm (opcional) |
| Service Discovery | Consul 1.15.4 |
| Backend | Python / Flask |
| Base de datos | MySQL 5.7 |
| Métricas | Prometheus + prometheus-flask-exporter |
| Dashboards | Grafana |
| Alertas | Alertmanager |
| Ingress | Nginx Ingress Controller |

---

## Estructura del repositorio

```
CI-CD-/
├── .github/
│   └── workflows/
│       └── ci.yml                     # Pipeline CI/CD completo
│
├── Microservicios/
│   ├── frontend/                      # App Flask (interfaz web)
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── web/
│   ├── microUsers/                    # API REST de usuarios
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── users/
│   ├── microProductos/                # API REST de productos
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── products/
│   ├── microOrders/                   # API REST de órdenes
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── orders/
│   ├── db_users/init.sql
│   ├── db_products/init.sql
│   └── db_orders/init.sql
│
├── k8s/
│   ├── namespace/                     # Namespace microapp
│   ├── consul/                        # Deployment + Service de Consul
│   ├── databases/                     # MySQL deployments, PVCs, Secrets
│   ├── frontend/                      # Deployment frontend
│   ├── users/                         # Deployment users (rolling update)
│   ├── products/                      # Deployments blue + green + service
│   ├── orders/                        # Deployment orders (rolling update)
│   └── ingress.yaml                   # Reglas de Ingress
│
├── monitoring/
│   ├── namespace-monitoring.yaml
│   ├── ServiceAccount.yaml            # Permisos RBAC para Prometheus
│   ├── prometheus-config.yaml         # Scraping + reglas de alertas
│   ├── prometheus-deployment.yaml
│   ├── alertmanager-deployment.yaml
│   ├── grafana-deployment.yaml
│   ├── mysql-exporters.yaml
│   └── grafana/                       # Dashboards exportados como JSON
│
├── docker-compose.yml                 # Para desarrollo local sin K8s
├── setup.sh                           # Script de instalación automática
└── README.md
```

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Ubuntu / Debian | 20.04+ |
| Docker | 20.x |
| kubectl | 1.25+ |
| Minikube | 1.30+ |
| Git | 2.x |
| RAM disponible | 4 GB mínimo |
| CPU | 2 cores mínimo |

---

## Instalación rápida

La forma más rápida de poner en marcha todo el sistema es usando el script de instalación automática:

```bash
# 1. Clonar el repositorio
git clone https://github.com/xSonTs24/CI-CD-.git
cd CI-CD-

# 2. Dar permisos al script
chmod +x setup.sh

# 3. Ejecutar
./setup.sh
```

El script detecta automáticamente qué herramientas ya están instaladas y solo instala las que faltan. Al finalizar muestra un resumen con todas las URLs de acceso.

> Si el script indica que debes cerrar y reabrir la sesión (por los permisos de Docker), hazlo y vuelve a correr `./setup.sh`.

---

## Instalación manual paso a paso

Si prefieres instalar todo manualmente o el script falla en algún paso, sigue estos pasos:

### 1. Instalar Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Agregar tu usuario al grupo docker (evita usar sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verificar
docker --version
docker ps
```

### 2. Instalar kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Verificar
kubectl version --client
```

### 3. Instalar Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Verificar
minikube version
```

### 4. Instalar dependencias del sistema

```bash
sudo apt-get update
sudo apt-get install -y --fix-missing \
  pkg-config \
  default-libmysqlclient-dev \
  python3-dev \
  build-essential \
  git \
  curl
```

### 5. Iniciar Minikube

```bash
minikube start --driver=docker --memory=4096 --cpus=2
minikube addons enable ingress

# Esperar que el Ingress controller esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

# Obtener la IP del clúster
minikube ip
```

### 6. Clonar el repositorio

```bash
git clone https://github.com/xSonTs24/CI-CD-.git
cd CI-CD-
```

### 7. Desplegar la infraestructura base

```bash
# Namespace
kubectl apply -f k8s/namespace/

# Consul
kubectl apply -f k8s/consul/

# Bases de datos (esperar 2-3 minutos hasta que estén 1/1 Running)
kubectl apply -f k8s/databases/
kubectl get pods -n microapp -w
```

### 8. Desplegar los microservicios

```bash
# Reemplazar PLACEHOLDER_TAG por latest para el primer despliegue
find k8s/ \( -name "*.yaml" -o -name "*.yml" \) | \
  xargs grep -l "PLACEHOLDER_TAG" | \
  xargs sed -i 's/PLACEHOLDER_TAG/latest/g'

kubectl apply -f k8s/users/
kubectl apply -f k8s/products/
kubectl apply -f k8s/orders/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress.yaml

# Verificar
kubectl get pods -n microapp

# Restaurar PLACEHOLDER_TAG para el pipeline
git checkout -- k8s/
```

### 9. Desplegar el stack de monitoreo

```bash
kubectl apply -f monitoring/namespace-monitoring.yaml
kubectl apply -f monitoring/ServiceAccount.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/alertmanager-deployment.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/mysql-exporters.yaml

# Verificar
kubectl get pods -n monitoring
```

### 10. Exponer los servicios de monitoreo

```bash
kubectl port-forward -n monitoring svc/grafana-svc 3000:3000 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/prometheus-svc 9090:9090 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/alertmanager 9093:9093 --address=0.0.0.0 &
```

---

## Pipeline CI/CD

### Configurar secretos en GitHub

Antes de usar el pipeline, agrega estos secretos en tu repositorio:

```
Repositorio → Settings → Secrets and variables → Actions → New repository secret
```

| Secreto | Valor |
|---|---|
| `DOCKER_USERNAME` | Tu usuario de Docker Hub |
| `DOCKER_PASSWORD` | Token de acceso de Docker Hub (no la contraseña) |

Para generar el token de Docker Hub:
```
hub.docker.com → Account Settings → Security → New Access Token
```

### Instalar el self-hosted runner

El pipeline corre en la misma VM donde está Minikube:

```
Repositorio en GitHub → Settings → Actions → Runners → New self-hosted runner → Linux
```

Seguir las instrucciones que aparecen. Luego instalar como servicio permanente:

```bash
sudo ./svc.sh install
sudo ./svc.sh start

# Verificar que está activo
sudo systemctl status actions.runner.*
```

### Flujo de trabajo con Git

```bash
# 1. Crear rama feature desde develop
git checkout develop
git checkout -b feature/nombre-del-cambio

# 2. Hacer cambios en el código
# ... editar archivos ...

# 3. Commitear y pushear
git add .
git commit -m "feat: descripción del cambio"
git push origin feature/nombre-del-cambio

# 4. Crear Pull Request en GitHub: feature/* → develop
# Al hacer merge, el pipeline se activa automáticamente
```

### Cómo funciona la detección de cambios

El pipeline detecta qué microservicio cambió comparando los archivos modificados en el commit:

| Carpeta modificada | Job que se activa |
|---|---|
| `Microservicios/frontend/**` | deploy-frontend |
| `Microservicios/microUsers/**` | deploy-microusers |
| `Microservicios/microProductos/**` | deploy-microproductos |
| `Microservicios/microOrders/**` | deploy-microorders |

Si no cambió ningún microservicio (por ejemplo solo se modificó el README), ningún job de deploy se activa.

---

## Estrategias de despliegue

### Rolling Update (users, orders, frontend)

Kubernetes reemplaza los pods uno a uno sin interrumpir el servicio. Configurado con:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1   # máximo 1 pod caído a la vez
    maxSurge: 1         # puede crear 1 pod extra durante la transición
```

### Blue-Green (products)

Dos versiones corren en paralelo. El Service apunta a una sola. Al hacer deploy, el pipeline:

1. Detecta cuál versión está activa (blue o green)
2. Actualiza la versión inactiva con la nueva imagen
3. Espera que esté completamente lista
4. Cambia el Service para apuntar a la nueva versión

```bash
# El switch ocurre con este comando en el pipeline
kubectl patch service products-svc -n microapp \
  -p '{"spec":{"selector":{"version":"green"}}}'
```

Para demostrar el blue-green durante la sustentación, correr una prueba de carga mientras ocurre el switch:

```bash
# Instalar k6
sudo apt install k6

# Correr prueba de carga
k6 run --vus 10 --duration 60s - <<EOF
import http from 'k6/http';
export default function() {
  http.get('http://MINIKUBE_IP/products');
}
EOF
```

---

## Monitoreo con Prometheus y Grafana

### Acceder a Grafana

```
URL: http://MINIKUBE_IP:3000
Usuario: admin
Contraseña: admin123
```

### Configurar datasource

```
Connections → Data Sources → Add new → Prometheus
URL: http://prometheus-svc.monitoring.svc.cluster.local:9090
Save & Test
```

### Dashboards disponibles

Importar desde Grafana (Dashboards → New → Import → JSON): 
Se agrega el archivo "dashboard.json" el cual despliega 6 tableros de monitoreo


### Alertas configuradas

| Alerta | Condición | Severidad |
|---|---|---|
| ServicioCaido | `up == 0` por 1 min | Critical |
| CPUAlta | CPU > 80% por 2 min | Warning |
| MemoriaAlta | Memoria > 85% por 2 min | Warning |
| ErroresHTTPAltos | Tasa de errores 500 > 5% | Critical |
| BuildFallido | Más de 2 builds fallidos en 10 min | Critical |

### Generar tráfico para ver métricas

```bash
MINIKUBE_IP=$(minikube ip)

for i in $(seq 1 50); do
  curl -s http://$MINIKUBE_IP/api/users > /dev/null
  curl -s http://$MINIKUBE_IP/products > /dev/null
  curl -s http://$MINIKUBE_IP/api/orders > /dev/null
  echo "Request $i"
done
```

---

## Endpoints disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/` | Frontend de la aplicación |
| GET | `/api/users` | Listar todos los usuarios |
| GET | `/api/users/<id>` | Obtener usuario por ID |
| POST | `/api/users` | Crear usuario |
| PUT | `/api/users/<id>` | Actualizar usuario |
| DELETE | `/api/users/<id>` | Eliminar usuario |
| POST | `/api/login` | Autenticación |
| GET | `/products` | Listar productos |
| GET | `/api/orders` | Listar órdenes |
| GET | `/healthcheck` | Estado del servicio |
| GET | `/metrics` | Métricas para Prometheus |

---


```bash
~/port-forwards.sh
```



## Comandos de referencia rápida

```bash
# Ver todos los pods
kubectl get pods -n microapp
kubectl get pods -n monitoring

# Ver logs de un microservicio
kubectl logs -n microapp deployment/users-deployment --tail=50

# Reiniciar un deployment
kubectl rollout restart deployment/users-deployment -n microapp

# Ver el estado del Ingress
kubectl get ingress -n microapp

# Ver métricas en tiempo real
kubectl top pods -n microapp

# Acceder a la shell de un pod
kubectl exec -it -n microapp deployment/users-deployment -- /bin/bash
```
