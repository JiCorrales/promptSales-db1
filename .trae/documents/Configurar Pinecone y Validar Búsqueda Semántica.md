## Qué es Pinecone y por qué lo usamos
- Servicio de base de datos vectorial administrado para búsqueda semántica.
- Guardamos embeddings (vectores) de descripciones y consultamos por similitud.

## Conseguir la API Key
- Crea una cuenta en https://www.pinecone.io/ y accede al Dashboard.
- En el menú, ve a “API Keys” → “Create API Key”.
- Copia la clave generada; es la que usarás como `PINECONE_API_KEY` en `.env`.
- No compartas esta clave; guárdala solo en `.env` y evita subirla a control de versiones.

## Configurar variables de entorno
- En `mcp-servers/promptcontent/scripts/.env` (o `.env` en ese directorio) define:
  - `PINECONE_API_KEY=tu_clave`
  - `PINECONE_INDEX=promptcontent` (puedes cambiar el nombre si quieres)
  - Requisitos relacionados: `OPENAI_API_KEY` para generar embeddings.

## Crear índice y subir embeddings
- Ejecuta siembra: `npm run db:seed`.
- Ejecuta embeddings y upsert: `npm run db:embed`.
- El script:
  - Asegura índice serverless con dimensión `1536` (compatible con `text-embedding-3-small`).
  - Procesa documentos en batch (100) y los upserta con metadata útil.
  - Marca `lastEmbeddedAt` para política de actualización periódica.

## Verificar que funciona
- En la consola de Pinecone, revisa que el índice exista y que el “Vector count” crezca tras `db:embed`.
- En el Inspector MCP (`npm run server:inspect`), usa `getContent` con una descripción; deberías ver imágenes con `score` cuando Pinecone está activo.
- Si falta `PINECONE_API_KEY` u `OPENAI_API_KEY`, verás mensajes de aviso y el sistema caerá a búsqueda textual y/o mock.

## Referencias en el código
- Creación de índice y upsert: `mcp-servers/promptcontent/scripts/embedAndUpsert.ts:22–35, 54–69`.
- Uso en tiempo de consulta: `mcp-servers/promptcontent/src/server.ts:409–420`.
- Validaciones y errores:
  - Falta de claves: `mcp-servers/promptcontent/scripts/embedAndUpsert.ts:14–17`.
  - Comprobación de API key al usar Pinecone: `mcp-servers/promptcontent/src/server.ts:22–24`.

## Opcional (mejora de configuración)
- Si quieres parametrizar la región del índice, puedo adaptar el script para leer `PINECONE_REGION` (en lugar de fijar `aws/us-east-1`).
- También puedo añadir un comando `server:start` y `clean` para separar producción (JS compilado) de desarrollo (TS). ¿Te gustaría que lo aplique?