# Aplicar validaciones `$jsonSchema` en MongoDB Compass

## Prerrequisitos
- Tener MongoDB en ejecución (local por defecto `mongodb://127.0.0.1:27017`).
- Tener instalado MongoDB Compass.
- Ubicación de los esquemas: `databases/mongodb/schemas/*.json`.

## Conectar a la base de datos
- Abre Compass y conéctate a `mongodb://127.0.0.1:27017`.
- Crea (o selecciona) la base `promptcontent_dev`.

## Crear colección con `$jsonSchema` (Compass)
Ejemplo con `AIRequests.json`:
- En la base `promptcontent_dev`, crea la colección `AIRequests`.
- Entra a la colección y abre la pestaña `Validation` (o `Schema Validation`).
- Selecciona modo `JSON` y pega el contenido completo de `databases/mongodb/schemas/AIRequests.json` como `validator`.
- Configura:
  - `Validation Level`: `moderate` (recomendado) o `strict`.
  - `Validation Action`: `error`.
- Guarda los cambios.

Repite el mismo proceso para `CampaignLogs` usando `databases/mongodb/schemas/CampaignLogs.json`.

## Modificar una colección existente (Compass)
- Abre la colección, entra a `Validation` y edita el JSON pegando el `$jsonSchema` correspondiente.
- Ajusta `Validation Level` y `Validation Action` y guarda.

## Alternativa por consola (referencia)
- Ejecuta en `mongosh` para aplicar validación a una colección ya creada:
```
db.runCommand({
  collMod: 'AIRequests',
  validator: JSON.parse(cat('databases/mongodb/schemas/AIRequests.json')),
  validationLevel: 'moderate',
  validationAction: 'error'
})
```
Repite para `CampaignLogs` cambiando nombre y ruta.

## Índices útiles (Compass)
- Colección `images`:
  - Tab `Indexes` → `Create Index` → `type: text` sobre `title`, `alt`, `tags`.
- Colección `hashtags`:
  - `Create Index` en campo `tag` con opción `unique`.
  - En `collation` usa `locale: en`, `strength: 2`.

## Verificación rápida
- Inserta un documento mínimo válido en `AIRequests` (tab `Documents` → `Insert`):
```
{
  "aiRequestId": "req_123",
  "createdAt": { "$date": "2025-01-01T00:00:00Z" },
  "status": "completed",
  "prompt": "Sample",
  "modality": "text"
}
```
- Inserta en `CampaignLogs`:
```
{
  "logId": "log_123",
  "campaignRef": "camp_123",
  "audience": "#1:18-35|fitness,travel|NYC|mixto",
  "messages": [
    { "ts": { "$date": "2025-01-01T00:00:00Z" }, "text": "Hello", "role": "assistant" }
  ],
  "createdAt": { "$date": "2025-01-01T00:00:00Z" }
}
```

## Consejos y problemas comunes
- Si la inserción falla, revisa campos `required` y tipos (`date`, `string`, `int`, etc.).
- Usa `moderate` si ya hay datos y quieres evitar rechazos al leer/actualizar.
- Los campos opcionales en los esquemas aceptan `null`; ajusta según necesidad.

