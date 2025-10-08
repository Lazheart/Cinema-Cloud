# 🎬 Cinema Cloud – Meta Repo

Este repositorio actúa como **meta-repo** que centraliza el despliegue de los microservicios del proyecto **Cinema Cloud**.

Cada microservicio (usuarios, películas, reservas, teatros) se encuentra en su propio repositorio, y desde allí se generan las **imágenes de Docker** que se publican en Docker Hub bajo el espacio de cada desarrollador (`lazheart/*`, `LeoMontesinos/*`, etc.).

Este repo contiene únicamente los **archivos de orquestación** (`docker-compose`) y la configuración de **NGINX** para levantar todo el ecosistema en **instancias EC2** de AWS.

---

## 🛠️ Requisitos previos

1. Tener **Docker** y **Docker Compose** instalados en tus instancias EC2.
2. Contar con al menos **tres instancias EC2**:
   - **EC2-DB** → donde correrán las bases de datos.
   - **EC2-API (x2 o más)** → donde correrán los microservicios y NGINX.
   - (Opcional) **Load Balancer (LB)** → que apunte a las EC2-API.
3. Configurar correctamente la **IP privada** de tu EC2-DB para que los microservicios puedan conectarse desde las EC2-API.

---

## 📂 Estructura del repositorio

```

lazheart-cinema-cloud/
├── README.md
├── docker-compose.api.yml   # Orquestación de microservicios + NGINX
├── docker-compose.db.yml    # Orquestación de bases de datos (Mongo + MySQL)
└── nginx/
└── nginx.conf           # Configuración del reverse proxy

````

---

## 🗄️ Paso 1 – Desplegar bases de datos (EC2-DB)

En tu instancia **EC2-DB**, levanta MongoDB y MySQL:

```bash
docker compose -f docker-compose.db.yml up -d
````

Esto levantará:

* **MongoDB (puerto 27017)** → usado por el **User Microservice**.
* **MySQL (puerto 3306)** → usado por el **Booking Microservice**.

Los datos se almacenan en volúmenes Docker (`mongo-data`, `mysql-data`) para que persistan tras reinicios.

---

## ⚙️ Paso 2 – Configurar variables de entorno (EC2-API)

En cada **EC2-API**, copia un archivo `.env` con las credenciales y la IP **privada o elástica** de tu instancia **EC2-DB**:

```env
# Mongo
MONGO_HOST=<IP_PRIVADA_EC2_DB>

# MySQL
DB_HOST=<IP_PRIVADA_EC2_DB>
DB_USER=user
DB_PASSWORD=password
DB_NAME=bookingdb
```

> ⚠️ **Importante:** Asegúrate de abrir los puertos **27017 (Mongo)** y **3306 (MySQL)** en el Security Group de la EC2-DB, permitiendo tráfico solo desde tus EC2-API.

---

## 🚀 Paso 3 – Desplegar microservicios + NGINX (EC2-API)

En cada instancia **EC2-API**, ejecuta:

```bash
docker compose -f docker-compose.api.yml up -d
```

Esto levantará:

* **User Microservice** → `http://<EC2_PRIVATE_IP>:5000/`
* **Theaters Microservice** → `http://<EC2_PRIVATE_IP>:8001/`
* **Booking Microservice** → `http://<EC2_PRIVATE_IP>:3000/`
* **Movie Microservice** → `http://<EC2_PRIVATE_IP>:8080/`
* **NGINX API Gateway (puerto 80 interno / 8000 externo)** → Reverse proxy interno

---

## 🌍 Despliegue con Load Balancer (LB)

El **Load Balancer (LB)** actúa como punto único de acceso para el **frontend**.
Todas las peticiones se envían al DNS fijo del LB, por ejemplo:

```
http://cinema-lb-123456789.us-east-1.elb.amazonaws.com
```

El LB distribuye el tráfico entre las EC2-API registradas en su **grupo de destino** (Target Group), cada una escuchando en el **puerto 8000** (mapeado al 80 interno de NGINX).

Flujo de peticiones:

```
Frontend → Load Balancer → EC2-API (NGINX) → Microservicios
```

Ventajas:

* Alta disponibilidad (si una EC2 falla, el LB redirige el tráfico).
* Escalabilidad horizontal (puedes agregar más EC2-API).
* IP fija (DNS del LB) para el frontend.

---

## 🌐 API Gateway con NGINX

El archivo [`nginx/nginx.conf`](nginx/nginx.conf) define el **reverse proxy** interno que enruta las peticiones entrantes hacia el microservicio correcto:

* `/user/` → User Microservice
* `/theaters/` → Theaters Microservice
* `/booking/` → Booking Microservice
* `/movie/` → Movie Microservice

De esta forma, el frontend solo necesita conectarse al **DNS del Load Balancer**, y NGINX se encarga del enrutamiento interno.

---

## 🔑 Resumen

1. **Levanta las bases de datos** en `EC2-DB`.
2. **Configura `.env`** en cada `EC2-API` con la IP de `EC2-DB`.
3. **Despliega las APIs + NGINX** en cada EC2-API.
4. **Registra tus EC2-API** en el **Load Balancer** (puerto 8000).
5. El **frontend** apunta únicamente al **DNS público del Load Balancer**.

---

## 🧠 Tips

* Si algún contenedor no se levanta, revisa los logs con:

  ```bash
  docker compose logs -f <nombre_servicio>
  ```
* Si tarda en conectarse a las bases de datos, asegúrate de que los **puertos estén abiertos en el Security Group** o ajusta el script de despliegue (`deploy_db.sh`) para detectar y avisar automáticamente.
