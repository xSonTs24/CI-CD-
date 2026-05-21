#!/bin/bash

# ============================================================
#  setup.sh — Instalación y despliegue automático
#  CI/CD Platform con Kubernetes y Prometheus
# ============================================================

set -e

# ── Colores ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# ============================================================
#  PASO 1 — Verificar sistema operativo
# ============================================================
section "Verificando sistema operativo"

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  error "Este script requiere Linux (Ubuntu/Debian)"
fi

if ! command -v apt-get &> /dev/null; then
  error "Este script requiere apt-get (Ubuntu/Debian)"
fi

log "Sistema operativo compatible"

# ============================================================
#  PASO 2 — Instalar Docker
# ============================================================
section "Instalando Docker"

if command -v docker &> /dev/null; then
  log "Docker ya está instalado: $(docker --version)"
else
  warn "Instalando Docker..."
  sudo apt-get update -qq
  sudo apt-get install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker $USER
  log "Docker instalado"
  warn "Cierra y vuelve a abrir la sesión para aplicar permisos de Docker, luego corre el script de nuevo"
  exit 0
fi

if ! docker ps &> /dev/null; then
  exec newgrp docker "$0" "$@"
fi

log "Docker funcionando correctamente"

# ============================================================
#  PASO 3 — Instalar kubectl
# ============================================================
section "Instalando kubectl"

if command -v kubectl &> /dev/null; then
  log "kubectl ya instalado: $(kubectl version --client --short 2>/dev/null || echo 'ok')"
else
  warn "Instalando kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  log "kubectl instalado"
fi

# ============================================================
#  PASO 4 — Instalar Minikube
# ============================================================
section "Instalando Minikube"

if command -v minikube &> /dev/null; then
  log "Minikube ya instalado: $(minikube version --short)"
else
  warn "Instalando Minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
  log "Minikube instalado"
fi

# ============================================================
#  PASO 5 — Instalar dependencias del sistema para Python
# ============================================================
section "Instalando dependencias del sistema"

warn "Instalando pkg-config y libmysqlclient..."
sudo apt-get update -qq
sudo apt-get install -y --fix-missing \
  pkg-config \
  default-libmysqlclient-dev \
  python3-dev \
  build-essential \
  git \
  curl

log "Dependencias instaladas"

# ============================================================
#  PASO 6 — Iniciar Minikube
# ============================================================
section "Iniciando Minikube"

MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

if [[ "$MINIKUBE_STATUS" == "Running" ]]; then
  log "Minikube ya está corriendo"
else
  warn "Iniciando Minikube (4GB RAM, 2 CPUs)..."
  minikube start --driver=docker --memory=4096 --cpus=2
  log "Minikube iniciado"
fi

warn "Habilitando addon Ingress..."
minikube addons enable ingress

warn "Esperando Ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s 2>/dev/null || warn "Ingress tardando, continuando..."

MINIKUBE_IP=$(minikube ip)
log "Minikube corriendo en: $MINIKUBE_IP"

# ============================================================
#  PASO 7 — Crear namespaces
# ============================================================
section "Creando namespaces"

kubectl apply -f k8s/namespace/
kubectl apply -f monitoring/namespace-monitoring.yaml
log "Namespaces creados"

# ============================================================
#  PASO 8 — Desplegar Consul
# ============================================================
section "Desplegando Consul"

kubectl apply -f k8s/consul/

warn "Esperando que Consul esté listo..."
kubectl wait --for=condition=available deployment/consul \
  -n microapp --timeout=60s || warn "Consul tardando, continuando..."

log "Consul desplegado"

# ============================================================
#  PASO 9 — Desplegar bases de datos
# ============================================================
section "Desplegando bases de datos"

kubectl apply -f k8s/databases/

warn "Esperando que las bases de datos inicialicen (2-3 minutos)..."
for db in db-users db-products db-orders; do
  warn "Esperando $db..."
  kubectl wait --for=condition=available deployment/$db \
    -n microapp --timeout=180s || warn "$db tardando, continuando..."
done

log "Bases de datos listas"

# ============================================================
#  PASO 10 — Desplegar microservicios
# ============================================================
section "Desplegando microservicios"

warn "Configurando imágenes con tag latest para el primer despliegue..."
find k8s/ \( -name "*.yaml" -o -name "*.yml" \) | \
  xargs grep -l "PLACEHOLDER_TAG" 2>/dev/null | \
  xargs sed -i 's/PLACEHOLDER_TAG/latest/g' 2>/dev/null || true

kubectl apply -f k8s/users/
kubectl apply -f k8s/products/
kubectl apply -f k8s/orders/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress.yaml

warn "Esperando que los microservicios estén listos..."
for deployment in users-deployment orders-deployment frontend; do
  kubectl wait --for=condition=available deployment/$deployment \
    -n microapp --timeout=120s || warn "$deployment tardando, continuando..."
done

warn "Restaurando PLACEHOLDER_TAG para el pipeline CI/CD..."
git checkout -- k8s/ 2>/dev/null || true

log "Microservicios desplegados"

# ============================================================
#  PASO 11 — Desplegar monitoreo
# ============================================================
section "Desplegando stack de monitoreo"

kubectl apply -f monitoring/ServiceAccount.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/alertmanager-deployment.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/mysql-exporters.yaml

warn "Esperando Prometheus y Grafana..."
for deployment in prometheus grafana alertmanager; do
  kubectl wait --for=condition=available deployment/$deployment \
    -n monitoring --timeout=120s || warn "$deployment tardando, continuando..."
done

log "Stack de monitoreo desplegado"

# ============================================================
#  PASO 12 — Crear script de port-forwards
# ============================================================
section "Configurando port-forwards"

cat > ~/port-forwards.sh << 'PFEOF'
#!/bin/bash
pkill -f "kubectl port-forward" 2>/dev/null
sleep 2
MKIP=$(minikube ip)
kubectl port-forward -n monitoring svc/grafana-svc 3000:3000 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/prometheus-svc 9090:9090 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/alertmanager 9093:9093 --address=0.0.0.0 &
sleep 2
echo "Port-forwards activos:"
echo "  Grafana      → http://$MKIP:3000"
echo "  Prometheus   → http://$MKIP:9090"
echo "  Alertmanager → http://$MKIP:9093"
PFEOF

chmod +x ~/port-forwards.sh
~/port-forwards.sh

log "Port-forwards configurados"

# ============================================================
#  PASO 13 — Verificación final
# ============================================================
section "Verificación final"

MINIKUBE_IP=$(minikube ip)
sleep 5

echo ""
log "Estado de los pods en microapp:"
kubectl get pods -n microapp
echo ""
log "Estado de los pods en monitoring:"
kubectl get pods -n monitoring
echo ""

# Probar endpoints
if curl -s --max-time 5 "http://$MINIKUBE_IP/api/users" | grep -q "id" 2>/dev/null; then
  log "API Users respondiendo"
else
  warn "API Users aún no responde (puede necesitar más tiempo)"
fi

if curl -s --max-time 5 "http://$MINIKUBE_IP/products" | grep -q "id" 2>/dev/null; then
  log "API Products respondiendo"
else
  warn "API Products aún no responde (puede necesitar más tiempo)"
fi

# ============================================================
#  RESUMEN
# ============================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓  Instalación completada${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  IP del clúster: ${BLUE}$MINIKUBE_IP${NC}"
echo ""
echo -e "  ${YELLOW}Aplicación:${NC}"
echo -e "    Frontend     →  http://$MINIKUBE_IP/"
echo -e "    API Users    →  http://$MINIKUBE_IP/api/users"
echo -e "    API Products →  http://$MINIKUBE_IP/products"
echo -e "    API Orders   →  http://$MINIKUBE_IP/api/orders"
echo ""
echo -e "  ${YELLOW}Monitoreo:${NC}"
echo -e "    Grafana      →  http://$MINIKUBE_IP:3000  ${BLUE}(admin / admin123)${NC}"
echo -e "    Prometheus   →  http://$MINIKUBE_IP:9090"
echo -e "    Alertmanager →  http://$MINIKUBE_IP:9093"
echo ""
echo -e "  ${YELLOW}Comandos útiles:${NC}"
echo -e "    Ver pods:            kubectl get pods -n microapp"
echo -e "    Ver monitoreo:       kubectl get pods -n monitoring"
echo -e "    Regenerar forwards:  ~/port-forwards.sh"
echo ""
