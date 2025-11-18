## Qué es Pinecone
- Base de datos vectorial gestionada para búsquedas semánticas.
- Con `text-embedding-3-small` la dimensión del índice debe ser `1536` y métrica `cosine`.

## Obtener API Key
- Regístrate en https://app.pinecone.io/.
- Crea una organización/proyecto si es la primera vez.
- En el Panel → `API Keys` → `Create API Key`.
- Elige `Serverless` y región (ej. `aws` / `us-east-1`). Guarda la `API Key` y toma nota de región.

## Crear Índice
- En `Indexes` → `Create Index`.
- Nombre: `promptcontent` (o el que prefieras).
- Dimensión: `1536`.
- Métrica: `cosine`.
- Tipo: `serverless` (misma nube/región que elegiste).
- Alternativa: el script `db:embed` crea el índice automáticamente si no existe.

## Configurar en el Proyecto
- En `mcp-servers/promptcontent/scripts/.env` agrega:
  - `PINECONE_API_KEY=<tu_api_key>`
  - `PINECONE_INDEX=promptcontent`
- Asegúrate de no compartir/commitear esta clave.

## Verificar Instalación (sin ejecutar todavía)
- Librería instalada: está declarada en `package.json` (`@pinecone-database/pinecone`).
- Prueba manual cuando lo autorices:
  - `npm ls @pinecone-database/pinecone` para confirmar instalación local.
  - `npm run db:embed` para generar embeddings y upsert; debería mostrar "Índice creado" si no existe y "✅ Embeddings y upsert completados" al finalizar.

## Próximo paso propuesto
- Ingresas la `PINECONE_API_KEY` y creas el índice en el panel.
- Luego, con tu confirmación, ejecuto `npm run db:embed` para validar conectividad y cargar embeddings, y te comparto el resultado.