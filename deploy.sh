#!/bin/bash
set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Cinema Cloud Deployment Script ===${NC}"

if [ "$#" -ne 1 ]; then
  echo "Uso: ./deploy.sh [db|api]"
  exit 1
fi

MODE=$1

# Cargar variables de entorno
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo -e "${YELLOW}Advertencia: No se encontró .env, usando valores por defecto.${NC}"
fi

# -----------------------------
# 🧠 Función para esperar puerto
# -----------------------------
wait_for_port() {
  local host=$1
  local port=$2
  local timeout=$3
  local start_time=$(date +%s)

  echo -ne "${YELLOW}Esperando conexión a ${host}:${port} ...${NC}"

  while true; do
    if nc -z -w3 $host $port 2>/dev/null; then
      echo -e " ${GREEN}✔ Disponible${NC}"
      return 0
    fi

    local now=$(date +%s)
    local elapsed=$((now - start_time))

    if [ "$elapsed" -ge "$timeout" ]; then
      echo -e "\n${RED}❌ No se pudo conectar a ${host}:${port} tras ${timeout}s.${NC}"
      return 1
    fi

    echo -ne "."
    sleep 3
  done
}

# Variables de estado para el resumen
declare -A STATUS
STATUS=()

# -----------------------------
# 🚀 Modo EC2-DB
# -----------------------------
if [ "$MODE" = "db" ]; then
  echo -e "${GREEN}=== Configurando servidor de bases de datos (EC2-DB) ===${NC}"

  echo -e "${YELLOW}Instalando NFS Server...${NC}"
  sudo apt-get update -y
  sudo apt-get install -y nfs-kernel-server

  echo -e "${YELLOW}Creando carpeta /srv/theaters...${NC}"
  sudo mkdir -p /srv/theaters
  sudo chown -R nobody:nogroup /srv/theaters
  sudo chmod 777 /srv/theaters

  echo -e "${YELLOW}Configurando exportación NFS...${NC}"
  sudo bash -c "echo '/srv/theaters 172.31.0.0/16(rw,sync,no_subtree_check)' >> /etc/exports"
  sudo exportfs -ra
  sudo systemctl enable nfs-kernel-server
  sudo systemctl restart nfs-kernel-server

  sudo chown -R 1000:1000 /srv/theaters
  sudo chmod -R 777 /srv/theaters

  echo -e "${YELLOW}Verificando puerto NFS (2049)...${NC}"
  if sudo ss -lntp | grep -q 2049; then
    STATUS["NFS"]="✔"
  else
    STATUS["NFS"]="❌"
    echo -e "${RED}⚠️ NFS no está escuchando en 2049${NC}"
  fi

  echo -e "${YELLOW}Levantando contenedores de bases de datos...${NC}"
  docker compose -f docker-compose.db.yml up -d mongo && STATUS["MongoDB"]="✔" || STATUS["MongoDB"]="❌"
  docker compose -f docker-compose.db.yml up -d mysql && STATUS["MySQL"]="✔" || STATUS["MySQL"]="❌"
  docker compose -f docker-compose.db.yml up -d postgres && STATUS["Postgres"]="✔" || STATUS["Postgres"]="❌"

  echo -e "${GREEN}✔ Bases de datos y NFS configurados correctamente (con posibles advertencias).${NC}"
  echo -e "${YELLOW}Usa 'showmount -e localhost' para verificar la exportación.${NC}"

# -----------------------------
# 🚀 Modo EC2-API
# -----------------------------
elif [ "$MODE" = "api" ]; then
  echo -e "${GREEN}=== Desplegando microservicios + NGINX (EC2-API) ===${NC}"

  if [ -z "$DB_PRIVATE_IP" ]; then
    echo -e "${RED}ERROR: Debes definir DB_PRIVATE_IP en tu archivo .env${NC}"
    exit 1
  fi

  # Verificar e instalar NFS client
  echo -e "${YELLOW}Verificando instalación de cliente NFS...${NC}"
  if ! command -v mount.nfs &>/dev/null; then
    echo -e "${YELLOW}Instalando paquete nfs-common...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y nfs-common
  else
    echo -e "${GREEN}✔ Cliente NFS ya instalado.${NC}"
  fi

  echo -e "${YELLOW}Montando volumen NFS desde ${DB_PRIVATE_IP}...${NC}"
  sudo mkdir -p /mnt/theaters
  if sudo mount -t nfs ${DB_PRIVATE_IP}:/srv/theaters /mnt/theaters; then
    STATUS["NFS"]="✔"
    echo -e "${GREEN}✔ Volumen NFS montado correctamente.${NC}"
  else
    STATUS["NFS"]="❌"
    echo -e "${RED}❌ No se pudo montar NFS.${NC}"
  fi

  # Verificar conectividad a bases de datos
  echo -e "${YELLOW}Verificando conectividad a las bases de datos...${NC}"

  declare -A ports_to_check=(
    ["MongoDB"]=27017
    ["MySQL"]=3306
    ["Postgres"]=15432
    ["NFS"]=2049
  )

  for service in "${!ports_to_check[@]}"; do
    port="${ports_to_check[$service]}"
    if wait_for_port "$DB_PRIVATE_IP" "$port" 30; then
      STATUS["$service"]="✔"
    else
      STATUS["$service"]="❌"
    fi
  done

  echo -e "${YELLOW}Levantando microservicios y NGINX...${NC}"
  if docker compose -f docker-compose.api.yml up -d; then
    STATUS["Microservicios"]="✔"
  else
    STATUS["Microservicios"]="❌"
  fi

  echo -e "${GREEN}✔ APIs y NGINX desplegados correctamente (con posibles advertencias).${NC}"

else
  echo -e "${RED}Modo inválido. Usa 'db' o 'api'.${NC}"
  exit 1
fi

# -----------------------------
# 📊 Resumen final
# -----------------------------
echo -e "\n${YELLOW}=== RESUMEN DEL DESPLIEGUE ===${NC}"
for key in "${!STATUS[@]}"; do
  printf "%-15s %b\n" "$key" "${STATUS[$key]}"
done
echo -e "${YELLOW}==============================${NC}"
echo -e "${GREEN}✔ Despliegue completado.${NC}"
