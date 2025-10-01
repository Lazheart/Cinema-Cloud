
# 🎬 Cinema Cloud – Meta Repo

Este repositorio actúa como **meta-repo** que centraliza el despliegue de los microservicios del proyecto **Cinema Cloud**.

Cada microservicio (usuarios, películas, reservas, teatros) se encuentra en su propio repositorio, y desde allí se generan las **imágenes de Docker** que se publican en Docker Hub bajo el espacio  de cada desarrollador `lazheart/*` , `LeoMontesinos/*` , & etc.

Este repo contiene únicamente los **archivos de orquestación** (`docker-compose`) y la configuración de **NGINX** para levantar todo el ecosistema en **instancias EC2** de AWS.

---

## 🛠️ Requisitos previos

1. Tener **Docker** y **Docker Compose** instalados en tus instancias EC2.
2. Contar con al menos **dos instancias EC2**:

   * **EC2-DB**: donde correrán las bases de datos.
   * **EC2-API**: donde correrán los microservicios y el API Gateway (NGINX).
3. Configurar correctamente la **IP elástica** de tu instancia EC2-DB para que los microservicios puedan conectarse.

---

## 📂 Estructura del repositorio

```
lazheart-cinema-cloud/
├── README.md
├── docker-compose.api.yml   # Orquestación de microservicios + NGINX
├── docker-compose.db.yml    # Orquestación de bases de datos (Mongo + MySQL)
└── nginx/
    └── nginx.conf           # Configuración del reverse proxy
```

---

## 🗄️ Paso 1 – Desplegar bases de datos (EC2-DB)

En tu instancia **EC2-DB**, levanta MongoDB y MySQL:

```bash
docker compose -f docker-compose.db.yml up -d
```

Esto levantará:

* **MongoDB (puerto 27017)** → usado por el **User Microservice**.
* **MySQL (puerto 3306)** → usado por el **Booking Microservice**.

Los datos se almacenan en volúmenes Docker (`mongo-data`, `mysql-data`) para que persistan tras reinicios.

---

## ⚙️ Paso 2 – Configurar variables de entorno (EC2-API)

En cada **EC2-API** (donde correrán las APIs), debes copiar un archivo `.env` con las credenciales y la IP correcta de tu instancia **EC2-DB**.

Ejemplo de `.env`:

```env
# Mongo
MONGO_HOST=<IP_ELASTICA_EC2_DB>

# MySQL
DB_HOST=<IP_ELASTICA_EC2_DB>
DB_USER=user
DB_PASSWORD=password
DB_NAME=bookingdb
```

---

## 🚀 Paso 3 – Desplegar microservicios + NGINX (EC2-API)

En tu instancia **EC2-API**, ejecuta:

```bash
docker compose -f docker-compose.api.yml up -d
```

Esto levantará los siguientes servicios:

* **User Microservice** → `http://<IP_API>/user/`
* **Theaters Microservice** → `http://<IP_API>/theaters/`
* **Booking Microservice** → `http://<IP_API>/booking/`
* **Movie Microservice** → `http://<IP_API>/movie/`
* **NGINX API Gateway (puerto 80)** → maneja las rutas y hace de reverse proxy para que el frontend pueda consumir fácilmente las APIs.

---

## 🌐 API Gateway con NGINX

El archivo [`nginx/nginx.conf`](nginx/nginx.conf) define el **reverse proxy** que enruta las peticiones entrantes hacia el microservicio correcto:

* `/user/` → User Microservice
* `/theaters/` → Theaters Microservice
* `/booking/` → Booking Microservice
* `/movie/` → Movie Microservice

De esta forma, el **frontend** solo necesita conectarse a la **IP pública de EC2-API** (puerto 80).

---

## 🔑 Resumen

1. **Levanta las bases de datos** en `EC2-DB`.
2. **Configura `.env`** en cada `EC2-API` con la IP del `EC2-DB`.
3. **Levanta los microservicios y NGINX** en cada `EC2-API`.
4. El frontend ya puede consumir las rutas expuestas en la IP pública de tu `EC2-API`.

---
