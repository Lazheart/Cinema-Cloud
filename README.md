
# 🚀 Instrucciones simples

1. En el **EC2-DB**:

   ```bash
   docker compose -f docker-compose.db.yml up -d
   ```

2. En cada **EC2-API**:

   * Copiar `.env` y poner los valores correctos (IP privada del EC2-DB, usuario y password).
   * Luego ejecutar:

     ```bash
     docker compose --env-file .env -f docker-compose.api.yml up -d
     ```

