# 🎬 Cinema Cloud – Meta Repo

Este repositorio actúa como **meta-repositorio** para el despliegue completo del ecosistema **Cinema Cloud**, que se compone de múltiples **microservicios independientes** (usuarios, películas, reservas y teatros).

Cada microservicio tiene su propio repositorio y genera su imagen Docker publicada en Docker Hub bajo los espacios de cada desarrollador (`lazheart/*`, `luciajcm/*`, `joemir123/*`, etc.).  
Desde este meta-repo se orquesta **todo el sistema** mediante **Docker Compose**, **NGINX** y **scripts automatizados de despliegue** en instancias **AWS EC2**.

---

## 🧱 Estructura del Repositorio

```

lazheart-cinema-cloud/
├── README.md                  # Documentación general
├── deploy.sh                  # Script automatizado de despliegue
├── docker-compose.api.yml     # Microservicios + NGINX (EC2-API)
├── docker-compose.db.yml      # Bases de datos (EC2-DB)
└── nginx/
└── nginx.conf             # Configuración del reverse proxy (API Gateway)

````

---

## 🛠️ Requisitos Previos

1. **Docker** y **Docker Compose** instalados en todas tus instancias EC2.
2. Contar con al menos **tres instancias EC2**:
   - 🗄️ **EC2-DB** → almacena MongoDB y MySQL.
   - ⚙️ **EC2-API (x2 o más)** → ejecutan los microservicios y NGINX.
   - 🌐 *(Opcional)* **Load Balancer (LB)** → distribuye tráfico al grupo de EC2-API.
3. Configurar las **IP privadas** y los **grupos de seguridad** correctamente:
   - EC2-DB debe permitir acceso a los puertos `27017 (Mongo)`, `3306 (MySQL)` y `2049 (NFS)` solo desde las EC2-API.
   - EC2-API debe permitir el puerto `8000` (para el tráfico del Load Balancer).

---

## ⚙️ Paso 1 – Desplegar Bases de Datos (EC2-DB)

Conéctate a tu instancia **EC2-DB** y ejecuta:

```bash
chmod +x deploy.sh
./deploy.sh db
````

Este modo realiza automáticamente lo siguiente:

* Instala y configura **NFS Server** para compartir datos de los teatros.
* Levanta los contenedores de **MongoDB** y **MySQL** usando `docker-compose.db.yml`.
* Crea el directorio `/srv/theaters` y lo comparte vía NFS con la red interna.

Puertos expuestos:

| Servicio | Puerto | Uso                         |
| -------- | ------ | --------------------------- |
| MongoDB  | 27017  | User y Booking Microservice |
| MySQL    | 3306   | Booking Microservice        |
| NFS      | 2049   | Theaters Microservice       |

Verifica que el NFS esté activo:

```bash
showmount -e localhost
```

---

## ⚙️ Paso 2 – Configurar Variables de Entorno (EC2-API)

En cada instancia **EC2-API**, crea un archivo `.env` con la IP privada de tu EC2-DB y credenciales:

```env
# Dirección privada de la EC2-DB
DB_PRIVATE_IP=172.31.x.x

# Mongo
MONGO_HOST=${DB_PRIVATE_IP}

# MySQL
MYSQL_HOST=${DB_PRIVATE_IP}
DB_USER=user
DB_PASSWORD=password
DB_NAME=bookingdb

# Postgres (si aplica para Movie Microservice)
POSTGRES_HOST=${DB_PRIVATE_IP}
```

---

## ⚙️ Paso 3 – Desplegar Microservicios + NGINX (EC2-API)

En cada **EC2-API**, ejecuta:

```bash
chmod +x deploy.sh
./deploy.sh api
```

Este modo realiza automáticamente lo siguiente:

1. **Monta el volumen NFS** desde la EC2-DB en `/mnt/theaters`.
2. **Verifica conectividad** con los puertos `27017`, `3306`, `2049`, y `15432` (si aplica).
3. **Levanta los microservicios y NGINX** usando `docker-compose.api.yml`.

Servicios desplegados:

| Servicio              | Puerto Interno | Puerto Externo | Imagen Docker                       |
| --------------------- | -------------- | -------------- | ----------------------------------- |
| User Microservice     | 5000           | 5000           | `luciajcm/user-microservice`        |
| Theaters Microservice | 8001           | 8001           | `joemir123/theaters-api`            |
| Booking Microservice  | 3000           | 3000           | `lazheart/booking-microservice:1.0` |
| Movie Microservice    | 8080           | 8080           | `lucianayc/movie-microservice`      |
| NGINX API Gateway     | 80             | 8000           | `nginx:latest`                      |

---

## 🌐 Paso 4 – Configurar el Load Balancer (LB)

1. Crea un **Load Balancer** en AWS (tipo Application Load Balancer).
2. Crea un **Target Group** que apunte a tus instancias EC2-API en el **puerto 8000**.
3. Asigna el **DNS público del LB** como punto de entrada del frontend:

```
http://cinema-lb-123456789.us-east-1.elb.amazonaws.com
```

Flujo del tráfico:

```
Frontend → Load Balancer → EC2-API (NGINX) → Microservicios
```

Ventajas:

* Escalabilidad horizontal (puedes agregar más EC2-API).
* Alta disponibilidad.
* DNS fijo para el frontend.

---

## 🧩 Enrutamiento (NGINX API Gateway)

El archivo [`nginx/nginx.conf`](nginx/nginx.conf) define las rutas internas:

| Path         | Servicio              | Contenedor destino           |
| ------------ | --------------------- | ---------------------------- |
| `/users/`    | User Microservice     | `users-microservice:5000`    |
| `/theaters/` | Theaters Microservice | `theaters-microservice:8001` |
| `/booking/`  | Booking Microservice  | `booking-microservice:3000`  |
| `/movie/`    | Movie Microservice    | `movie-microservice:8080`    |

De esta manera, el frontend solo necesita conectarse al **DNS del Load Balancer** y NGINX se encarga de enrutar las peticiones.

---

## 🧠 Comandos Útiles

Ver logs de un servicio:

```bash
docker compose logs -f <nombre_servicio>
```

Ver contenedores activos:

```bash
docker ps
```

Reiniciar un servicio:

```bash
docker compose restart <nombre_servicio>
```

Detener todo:

```bash
docker compose down
```

---

## 🔑 Resumen Final

| Paso | Instancia | Acción                                            |
| ---- | --------- | ------------------------------------------------- |
| 1️⃣  | EC2-DB    | Ejecutar `./deploy.sh db`                         |
| 2️⃣  | EC2-API   | Crear `.env` con IP privada del DB                |
| 3️⃣  | EC2-API   | Ejecutar `./deploy.sh api`                        |
| 4️⃣  | AWS       | Configurar Load Balancer apuntando al puerto 8000 |
| ✅    | Frontend  | Conectarse al DNS público del LB                  |

---
