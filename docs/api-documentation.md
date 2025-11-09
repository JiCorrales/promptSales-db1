# PromptContent MCP API

## Visión General
Servidor MCP que expone dos herramientas: `getContent` y `campaignDiary`. Ambas reciben entradas estructuradas y retornan contenido y metadatos listos para usar. El servidor soporta persistencia opcional en MongoDB y indexación vectorial en Postgres (pgvector).

## Herramienta: getContent
- Entrada mínima: `description` (string, >=10 chars)
- Parámetros opcionales: `campaignGoal`, `tone`, `keywords[]`, `channels[]`, `dominantColors[]`, `callToAction`, `aspectRatio`, `moodboardCount`.
- Salida:
  - `requestId` (string)
  - `ideas[]` con `id`, `title`, `prompt`, `hashtags[]`, `recommendedChannels[]`, `ratio`, `palette[]`
  - `images[]` con `id`, `title`, `url`, `hashtags[]`
  - `masterHashtags[]`
  - `validation` con `keywordCoverage` (0–1), `channelAlignment` (0–1), `embeddingSimilarity` (0–1 opcional)

### Ejemplo de uso
```json
{
  "name": "getContent",
  "arguments": {
    "description": "Nueva bebida hidratante con electrolitos vegetales y cero azúcar",
    "keywords": ["hidratante", "electrolitos", "vegetales"],
    "channels": ["instagram", "tiktok"],
    "aspectRatio": "4:5",
    "moodboardCount": 3
  }
}
```

## Herramienta: campaignDiary
- Entrada: `campaignName`, `campaignDescription`, `objective`, `keyOffer?`, `launchWindow?`, `tone?`, `callToAction?`, `targetAudiences[{ name, profile?, motivations[], pains[], preferredChannels[] }]`
- Salida:
  - `requestId`, `campaignName`
  - `diary[]` por audiencia con `messages[{ stage, copy, suggestedChannels[] }]`
  - `scheduleSuggestions[]` con `audience`, `stage`, `when` (ISO), `channels[]`
  - `tracking` con `trackingId`, `objective`, `audiences[]`

### Ejemplo de uso
```json
{
  "name": "campaignDiary",
  "arguments": {
    "campaignName": "Agua Nova",
    "campaignDescription": "Bebida premium enfocada en bienestar y energía limpia.",
    "objective": "awareness",
    "targetAudiences": [
      { "name": "Atletas urbanos", "preferredChannels": ["tiktok", "instagram"] },
      { "name": "Profesionales wellness", "preferredChannels": ["email", "linkedin"] }
    ]
  }
}
```

## Configuración
- Variables de entorno principales (ver `.vscode/mcp.json`):
  - `PC_DEFAULT_CHANNELS`, `PC_HASHTAG_COUNT`, `PC_MOODBOARD_MAX`, `PC_KEYWORD_MAX`, `PC_MESSAGE_TEMPLATES`.
  - MongoDB: `MONGODB_URI`, `MONGODB_DB_NAME`, `PC_CONTENT_REQUESTS_COLLECTION`, `PC_CAMPAIGN_LOGS_COLLECTION`.
  - pgvector: `PGVECTOR_DSN`, `PGVECTOR_TABLE`, `PGVECTOR_DIM`.

## Persistencia y Seguridad
- Inserciones en Mongo se realizan con el driver oficial; la entrada se valida con `zod`.
- pgvector almacena embeddings normalizados; se usa `CREATE EXTENSION IF NOT EXISTS vector` y tabla `content_embeddings`.

## Pruebas
- `npm run smoke`: verificación inicial de ambas herramientas.
- `npm run precision`: calcula `keywordCoverage` y alerta si es bajo.
- `npm run perf`: mide tiempos promedio de respuesta.
- `npm run load`: lanza solicitudes concurrentes para validar estabilidad.

## Notas
- Si Mongo o Postgres no están disponibles, el servidor continúa con almacenamiento local y sin similitudes de embeddings.
