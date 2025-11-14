# Entorno local de PromptContent

Este directorio contiene archivos para configurar tu entorno de desarrollo local.

## Pasos rápidos
- Copia `local/.env.example` a `local/.env` y ajusta valores.
- Asegúrate de tener Postgres y (opcional) Mongo en marcha.
- Ejecuta el servidor: `node mcp-servers/promptcontent/src/server.js`

## Variables principales
- `PORT`: puerto HTTP (default `8080`).
- `API_KEY`: clave simple para endpoints MCP/HTTP.
- `MONGODB_URI`, `MONGODB_DB_NAME`: opcionales; si no se definen, el servidor usa almacenamiento local.
- `PC_IMAGES_COLLECTION`: nombre de la colección Mongo utilizada por `/images` (default `Images`).
- `PGVECTOR_DSN`, `PGVECTOR_TABLE`, `PGVECTOR_DIM`: conexión a Postgres+pgvector.
- `PC_DEFAULT_CHANNELS`, `PC_HASHTAG_COUNT`, `PC_MOODBOARD_MAX`, `PC_KEYWORD_MAX`, `PC_MESSAGE_TEMPLATES`: ajustes de contenido.
- `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`: credenciales para importar portadas desde Spotify.
- `PROMPTCONTENT_NO_LISTEN`: pon `1` para evitar que el server arranque durante pruebas.

## Cargar variables en Windows (PowerShell)
- Establece variables persistentes:
```
setx PORT 8080
setx API_KEY devlocal
setx PGVECTOR_DSN "postgres://postgres:postgres@localhost:5432/promptcontent"
setx PGVECTOR_TABLE "content_embeddings"
setx PGVECTOR_DIM "128"
setx MONGODB_URI "mongodb://localhost:27017/promptContent"
setx MONGODB_DB_NAME "promptContent"
setx PC_IMAGES_COLLECTION "Images"
setx SPOTIFY_CLIENT_ID "<tu-client-id>"
setx SPOTIFY_CLIENT_SECRET "<tu-client-secret>"
```
- Reinicia la terminal y ejecuta el servidor.

## Script de seed (≥100 imágenes + vectores)
- Con el servidor en ejecución (`node mcp-servers/promptcontent/src/server.js`), ejecuta:
```
node scripts/data-generation/seed-promptcontent.mjs
```
- El script detecta si pgvector está disponible mediante `/readyz`. Si no hay Postgres, insertará solo imágenes en Mongo.

## Importación desde Spotify
- Con credenciales válidas, puedes importar portadas:
```
curl -X POST http://localhost:8080/external/spotify/import \
  -H "Content-Type: application/json" \
  -d '{"q":"chill","limit":10}'
```
- Luego explora:
```
curl http://localhost:8080/images?limit=10
curl http://localhost:8080/vectors?limit=10
```
