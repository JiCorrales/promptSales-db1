## Preparación del Entorno
- Copia `scripts/.env.example` a `.env` en `mcp-servers/promptcontent` y completa claves.
- Variables mínimas para funciones avanzadas:
  - `PINECONE_API_KEY`, `PINECONE_INDEX`.
  - `OPENAI_API_KEY`.
  - `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`.
- Opcionales: si no configuras Pinecone/OpenAI/Spotify, el sistema usa búsqueda textual y fallbacks; las herramientas siguen funcionando.
- Asegura MongoDB local en `mongodb://127.0.0.1:27017` (por defecto `MONGODB_DB=promptcontent`).

## Sembrado y Embeddings
- Sembrar 100 imágenes diversas y hashtags:
  - `npm run db:seed`.
  - Referencia: `scripts/seedImages.ts:71–77` índices; `scripts/seedImages.ts:81–93` documentos.
- Generar embeddings y cargar en Pinecone:
  - `npm run db:embed`.
  - Crea índice si no existe y upserta en batch; renueva `lastEmbeddedAt` para política de actualización: `scripts/embedAndUpsert.ts:22–35`, `scripts/embedAndUpsert.ts:54–69`.

## Arranque del Servidor MCP
- Desarrollo:
  - `npm run server:dev`.
- Inspección interactiva (Inspector MCP):
  - `npm run server:inspect`.
- Referencias de herramientas:
  - `getContent`: `src/server.ts:35–92`.
  - `createCampaign`: `src/server.ts:148–376`.
  - Búsqueda semántica: `src/server.ts:409–420`.
  - Spotify: `src/spotify.ts:13–30`, `src/spotify.ts:39–79`.

## Pruebas con Inspector MCP
- Abre Inspector, selecciona herramienta y completa el formulario.
- Ejemplo `getContent`:
  - Input `descripcion`: "Atardecer en playa con palmeras y olas suaves; tonos cálidos, composición equilibrada".
  - Espera:
    - Lista de ≥3 imágenes con `url`, `alt`, `score` cuando aplica y `tags`.
    - `hashtags` agregados y normalizados.
- Ejemplo `createCampaign`:
  - Input `descripcion` (≥200 caracteres) y `publico`:
```
{
  "descripcion": "Campaña para lanzamiento de producto eco-amigable con enfoque en bienestar y tecnología útil...",
  "publico": {
    "edad": { "min": 22, "max": 55 },
    "intereses": ["tecnología", "salud", "viajes"],
    "ubicaciones": ["México", "Colombia"],
    "genero": "mixto",
    "nivelSocioeconomico": "medio"
  },
  "duracion": "1 mes",
  "presupuesto": 8000
}
```
  - Espera:
    - `bitacora` con resumen, objetivos y estrategia.
    - `segmentos` con 3 mensajes por segmento (awareness/consideration/conversion).
    - `calendario` por semanas, días, horas y plataforma.
    - `metricas` de alcance/engagement/conversión y ROI; `recomendaciones`.

## Verificación de Funcionamiento
- `db:seed` finaliza con "✅ Seed completado".
- `db:embed` finaliza con "✅ Embeddings y upsert completados".
- `server:dev` muestra conexión del servidor MCP.
- En Inspector:
  - `getContent` devuelve resultados con `score` si Pinecone/OpenAI están configurados; si no, usa búsqueda textual y fallback (mock si Mongo falla).
  - `searchMusic` devuelve pistas reales si Spotify está configurado; si no, tracks mock.
  - `createCampaign` retorna estructura completa y almacena entrada en `campaigns`.

## Problemas Comunes y Soluciones
- Pinecone/OpenAI faltan: la búsqueda semántica cae a Mongo/regex; configura claves en `.env`.
- Errores de red Spotify: se aplican reintentos y caché; verifica `CLIENT_ID/SECRET`.
- Mongo no accesible: ajusta `MONGODB_URI` en `.env` o variable de entorno.
- Compilación TS: ejecuta `npm install` y `npm run server:build` si deseas compilar `src/`.

## Próximos pasos
- Si confirmas, puedo:
  - Ejecutar `db:seed` y `db:embed` para preparar datos.
  - Levantar `server:dev` y abrir Inspector para probar en tu entorno.
  - Registrar resultados y capturas de las respuestas de cada herramienta para tu validación.