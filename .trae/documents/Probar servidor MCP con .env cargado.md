## Reinicio y Carga de Entorno

* Cerrar cualquier Inspector anterior.

* Arrancar servidor en TS: `npm run server:dev`.

* Abrir Inspector: `npm run server:inspect` para usar las herramientas.

## Pruebas Funcionales en Inspector

* searchMusic:

  * Ejecutar con `query="pop"`, `limit=5`.

  * Validación: resultados con `url` de Spotify, `popularity` y sin `id` que empiece por `mock_`.

* getContent:

  * Ejecutar con una descripción (ej: “Atardecer en playa con palmeras y olas suaves…”).

  * Validación: lista de ≥3 imágenes con `url`, `alt`, `tags`; `hashtags` agregados.

  * Si Pinecone/OpenAI están configurados, verificar campo `score` (semántico) presente.

## Búsqueda Semántica (opcional)

* Si `PINECONE_API_KEY` está configurada:

  * Ejecutar `npm run db:embed` para crear índice (si falta) y subir embeddings.

  * Repetir `getContent` y confirmar `score` en resultados.

## Reporte

* Te devuelvo capturas y JSON de salida de ambas herramientas.

* Si aparece algún error de env o red, ajusto y vuelvo a correr hasta pasar validaciones.

