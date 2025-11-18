## Objetivo

Configurar y probar un MCP server para PromptContent integrado con MongoDB, con dos herramientas:

* `getContent`: recibe una descripción textual, busca imágenes que coincidan en la BD y retorna dichas imágenes y sus hashtags.

* `getHashtags`: recibe una descripción textual y retorna hashtags sugeridos (usando BD + heurística).

## Dependencias y configuración

* Node.js ≥ 22.

* Paquetes: `@modelcontextprotocol/sdk`, `typescript`, `tsx`, `zod`, `mongodb`.

* Variables de entorno: `MONGODB_URI`, `MONGODB_DB=promptcontent`.

* Scripts: `server:dev` (tsx), `server:build` (tsc), `server:inspect` (inspector con auth habilitado).

## Esquema de colecciones MongoDB

* `images`

  * Campos: `url` (string), `alt` (string opcional), `tags` (string\[]), `title` (string opcional), `score` (number opcional), `createdAt` (date).

  * Índices: texto en `title`, `alt`, `tags` (compound text), más índice en `createdAt`.

* `hashtags`

  * Campos: `tag` (string), `popularity` (number opcional), `aliases` (string\[] opcional).

  * Índices: único en `tag` (case-insensitive collation).

* (Opcional) `prompts`

  * Campos: `descripcion` (string), `suggestedHashtags` (string\[]), `suggestedImageIds` (ObjectId\[]), `createdAt` (date).

## Implementación del MCP server

1. Server base (`src/server.ts`):

   * Crear `McpServer` y conectar por `StdioServerTransport`.

   * Inicializar cliente Mongo (singleton) y obtener `db`.
2. Tool `getContent`:

   * `title`: "Buscar imágenes por descripción".

   * `description`: "recibe una descripción textual y retorna imágenes que coinciden y sus hashtags".

   * `inputSchema` (Zod): `{ descripcion: z.string() }`.

   * `outputSchema` (Zod): `{ images: z.array(z.object({ url: z.string(), alt: z.string().optional(), score: z.number().optional(), tags: z.array(z.string()).optional() })), hashtags: z.array(z.string()) }`.

   * Lógica:

     * Normalizar `descripcion`.

     * Consulta primaria: `$text: { $search: descripcion }` sobre `images` con `score: { $meta: "textScore" }` y orden por score.

     * Si no hay resultados, fallback: regex/fuzzy en `tags`/`alt`/`title`.

     * Construir `hashtags` como unión de `tags` de resultados + extracción heurística desde `descripcion` (tokenización, stopwords, top-k, `#` prefijo).

     * Retornar top N (p. ej., 5–10) imágenes + hashtags únicos.
3. Tool `getHashtags`:

   * `title`: "Generar hashtags".

   * `description`: "recibe una descripción textual y retorna hashtags sugeridos".

   * `inputSchema` (Zod): `{ descripcion: z.string() }`.

   * `outputSchema` (Zod): `{ hashtags: z.array(z.string()) }`.

   * Lógica:

     * Heurística de extracción (tokenización, stopwords, stemming simple opcional).

     * Enriquecer consultando `hashtags` (match por regex o búsqueda de alias) y mezclar con heurística.

     * Limitar a 10–20 únicos, ordenados por relevancia/popularidad.

## Inicialización de datos (seed)

* Antes borra el contenido de las colecciones de mongo. No las colecciones si no la data aka tablas.

- Crear un pequeño script (no en MCP) para insertar 20–50 documentos en `images` y 100 hashtags comunes de marketing.

- Asegurar índices de texto creados después del seed.

## Pruebas con MCP Inspector

* Compilar (`tsc`) o ejecutar en dev (`tsx`).

* Abrir `npx @modelcontextprotocol/inspector`.

* Conectar en modo STDIO con `npx tsx src/server.ts`.

* Probar:

  * `getContent` con `descripcion = "campaña de verano playa atardecer tropical"` y verificar URLs y hashtags.

  * `getHashtags` con textos variados y evaluar relevancia.

## Seguridad y robustez

* Mantener auth del Inspector; no usar `DANGEROUSLY_OMIT_AUTH`.

* Manejo de errores: timeouts de Mongo, validación con Zod, límites de tamaño de respuesta.

* Sanitización: evitar regex costosas, usar límites y paginación.

## Evolución

* Internacionalización (`lang` en input, stopwords por idioma).

* Relevancia: añadir campos `embedding` y búsqueda vectorial (Atlas Search/Redis opcional).

* Integración con proveedores de imágenes (Unsplash/Pexels) para enriquecer `images`.

