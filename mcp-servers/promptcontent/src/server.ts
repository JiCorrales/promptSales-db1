/**
 * @file MCP server para PromptContent.
 * @description Expone herramientas MCP para:
 *  - Búsqueda de imágenes (MongoDB + Pinecone/OpenAI o mock).
 *  - Búsqueda de música en Spotify.
 *  - Generación de campañas de marketing con segmentación, calendario y métricas.
 */

import dotenv from "dotenv"
dotenv.config()

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { z } from "zod"
import { MongoClient, Db, Int32 } from "mongodb"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { Pinecone } from "@pinecone-database/pinecone"
import { searchTrack } from "./spotify"
import OpenAI from "openai"

/**
 * Cliente global de MongoDB reutilizable.
 * @type {MongoClient | null}
 */
let mongoClient: MongoClient | null = null

/**
 * Instancia global de base de datos MongoDB reutilizable.
 * @type {Db | null}
 */
let mongoDb: Db | null = null

/**
 * Cliente global de Pinecone reutilizable.
 * @type {Pinecone | null}
 */
let pineconeClient: Pinecone | null = null

/**
 * Obtiene (y cachea) la instancia de base de datos MongoDB.
 *
 * Usa las variables de entorno:
 * - `MONGODB_URI` (opcional, por defecto `mongodb://127.0.0.1:27017`)
 * - `MONGODB_DB` (opcional, por defecto `promptcontent`)
 *
 * @async
 * @returns {Promise<Db>} Instancia de la base de datos de MongoDB.
 */
async function getDb() {
    if (mongoDb) return mongoDb
    const uri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017"
    mongoClient = await new MongoClient(uri).connect()
    mongoDb = mongoClient.db(process.env.MONGODB_DB || "promptcontent")
    return mongoDb
}

/**
 * Obtiene (y cachea) el cliente de Pinecone.
 *
 * Requiere la variable de entorno:
 * - `PINECONE_API_KEY`
 *
 * @throws {Error} Si `PINECONE_API_KEY` no está configurada.
 * @returns {Pinecone} Cliente de Pinecone inicializado.
 */
function getPinecone() {
    if (!pineconeClient) {
        const key = process.env.PINECONE_API_KEY
        if (!key) throw new Error("PINECONE_API_KEY no configurada")
        pineconeClient = new Pinecone({ apiKey: key })
    }
    return pineconeClient
}

/**
 * Normaliza una cadena para convertirla en hashtag.
 *
 * - Elimina espacios al inicio/fin.
 * - Reemplaza espacios internos por guiones bajos.
 * - Elimina caracteres no alfanuméricos (excepto `_`).
 * - Convierte a minúsculas.
 * - Asegura que comience con `#`.
 *
 * @param {string} t Texto a normalizar.
 * @returns {string} Hashtag normalizado (ej: `#contenido_marketing`).
 */
function normalizeHashtag(t: string) {
    const cleaned = t.trim().replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "")
    return cleaned.startsWith("#") ? cleaned : `#${cleaned.toLowerCase()}`
}

function toTagToken(t: string) {
    return t.replace(/^#/, "").toLowerCase()
}

function stripAccents(s: string) {
    return (s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
}

function toEnglishToken(t: string) {
    const lower = t.replace(/^#/, "").trim().toLowerCase().replace(/_/g, " ")
    const base = stripAccents(lower)
    const dict: Record<string, string> = {
        "contenido": "content",
        "marketing": "marketing",
        "campana": "campaign",
        "campañas": "campaigns",
        "campanas": "campaigns",
        "producto": "product",
        "productos": "products",
        "servicio": "service",
        "servicios": "services",
        "marca": "brand",
        "marcas": "brands",
        "ventas": "sales",
        "promocion": "promotion",
        "promoción": "promotion",
        "promociones": "promotions",
        "publicidad": "advertising",
        "oferta": "offer",
        "ofertas": "offers",
        "cliente": "customer",
        "clientes": "customers",
        "usuario": "user",
        "usuarios": "users",
        "precio": "price",
        "negocio": "business",
        "tecnologia": "technology",
        "tecnología": "technology",
        "moda": "fashion",
        "viajes": "travel",
        "estilo": "style",
        "vida": "life",
        "familia": "family",
        "profesional": "professional",
        "profesionales": "professionals",
        "jóvenes": "young",
        "jovenes": "young",
        "adultos": "adults",
        "conciencia": "awareness",
        "consideracion": "consideration",
        "consideración": "consideration",
        "conversion": "conversion",
        "estrategia": "strategy",
        "objetivo": "goal",
        "objetivos": "goals",
        "calendario": "schedule",
        "plataforma": "platform",
        "imagen": "image",
        "imagenes": "images",
        "imágenes": "images",
        "video": "video",
        "carrusel": "carousel",
        "historia": "story",
        "reel": "reel",
        "alcance": "reach",
        "engagement": "engagement",
        "audiencia": "audience",
        "creatividad": "creativity",
        "calidad": "quality",
        "excelencia": "excellence",
        "comparativa": "comparison",
        "beneficios": "benefits",
        "beneficio": "benefit",
        "comunidad": "community",
        "urgencia": "urgency",
        "moderno": "modern",
        "aspiracional": "aspirational",
        "cálido": "warm",
        "calido": "warm",
        "confiable": "reliable",
        "emocional": "emotional",
        "premium": "premium",
        "estilo de vida": "lifestyle"
    }
    const direct = dict[base]
    if (direct) return direct
    let guess = base
    if (guess.endsWith("ción")) guess = guess.slice(0, -4) + "tion"
    if (guess.endsWith("cion")) guess = guess.slice(0, -4) + "tion"
    if (guess.endsWith("ciones")) guess = guess.slice(0, -6) + "tions"
    if (guess.endsWith("ización")) guess = guess.slice(0, -8) + "ization"
    if (guess.endsWith("izacion")) guess = guess.slice(0, -8) + "ization"
    if (guess.endsWith("idad")) guess = guess.slice(0, -4) + "ity"
    if (guess.endsWith("ico")) guess = guess.slice(0, -3) + "ic"
    return guess
}

function toEnglishHashtag(t: string) {
    const token = toEnglishToken(t)
    const normalized = token.replace(/\s+/g, "_")
    return normalizeHashtag(normalized)
}

/**
 * Elimina espacios y backticks al inicio y al final de una URL.
 *
 * @param {string} u URL potencialmente "sucia".
 * @returns {string} URL saneada.
 */
function sanitizeUrl(u: string) {
    return (u || "").replace(/^[\s`]+|[\s`]+$/g, "")
}

/**
 * The function `themedImageUrl` generates a themed image URL using input tokens and an index number.
 * @param {string[]} tokens - An array of strings containing keywords or tags for the image search.
 * @param {number} i - The `i` parameter in the `themedImageUrl` function is used as a unique
 * identifier to generate a random query parameter in the URL. This helps in ensuring that each
 * generated URL is unique, even if the same set of tokens is used.
 * @returns The function `themedImageUrl` returns a URL string that includes the tokens passed as
 * arguments, encoded and formatted as query parameters. The URL is constructed using the
 * `loremflickr.com` API to generate a themed image with the specified tokens and a random query
 * parameter. If the query string is empty, an empty string is returned.
 */
function themedImageUrl(tokens: string[], i: number) {
    const toks = tokens.filter(Boolean).map(t => toEnglishToken(toTagToken(t)))
    const pool = Array.from(new Set(toks))
    const priority = new Set(["sunrise", "sunset", "sun"])
    const sorted = [...pool].sort((a, b) => (priority.has(b) ? 1 : 0) - (priority.has(a) ? 1 : 0))
    const pick = sorted.slice(0, Math.min(3, sorted.length))
    const q = pick.map(t => encodeURIComponent(t)).join(",")
    return q ? `https://loremflickr.com/800/600/${q}?random=${i}` : ""
}

/**
 * The function `extractHashtags` takes a string of text, extracts words excluding common stop words,
 * filters out short words, and returns up to 15 unique hashtags in lowercase format.
 * @param {string} text - The function `extractHashtags` takes a string `text` as input and extracts
 * hashtags from it. It first converts the text to lowercase, splits it into tokens based on
 * non-alphanumeric characters, filters out common stop words, and keeps words longer than 2
 * characters. It then removes duplicates and
 * @returns The function `extractHashtags` takes a string of text as input, extracts words from the
 * text, filters out common stop words, and returns an array of unique hashtags (words longer than 2
 * characters) with a maximum of 15 hashtags. Each hashtag is normalized using the `normalizeHashtag`
 * function before being returned.
 */
function extractHashtags(text: string) {
    const lower = text.toLowerCase()
    const tokens = lower.split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean)
    const stop = new Set(["de", "la", "el", "en", "y", "para", "por", "con", "del", "las", "los", "un", "una", "al", "que", "se", "the", "a", "an", "and", "or", "to", "for", "with", "of", "in", "on", "by", "at", "is", "are"])
    const words = tokens.filter(t => !stop.has(t) && t.length > 2)
    const unique = Array.from(new Set(words))
    return unique.slice(0, 15).map(w => normalizeHashtag(w))
}


async function translateToEnglish(text: string) {
    // Sin OpenAI: devolvemos texto normalizado sin acentos
    return stripAccents(text)
}

function isSpanish(text: string) {
    const accents = /[áéíóúñ]/i.test(text)
    const sw = /(\bde\b|\bla\b|\bel\b|\ben\b|\by\b|\bpara\b|\bpor\b|\bcon\b|\bdel\b|\blas\b|\blos\b|\bun\b|\buna\b|\bal\b|\bque\b|\bse\b)/i.test(text)
    return accents || sw
}
function parseSegmentsPayload(raw: string) {
    const fenced = (raw || "").trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim()
    const start = fenced.indexOf("{")
    const end = fenced.lastIndexOf("}")
    const candidates = [fenced]
    if (start !== -1 && end !== -1 && end > start) {
        candidates.push(fenced.slice(start, end + 1))
    }
    for (const c of candidates) {
        try {
            return JSON.parse(c)
        } catch {
            continue
        }
    }
    return null
}

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
async function generateMessagesWithAI(descripcion: string, auds: any[]) {
    const system = `
Eres un generador de campañas de marketing.
Devuelve SOLO un JSON válido, con esta forma exacta:

{
  "segmentos": [
    {
      "nombre": "Awareness",
      "mensajes": [
        { "tipo": "awareness", "texto": "…"},
        { "tipo": "consideration", "texto": "…"},
        { "tipo": "conversion", "texto": "…"}
      ]
    }
  ]
}

NO escribas nada fuera del JSON.
NO incluyas explicaciones.
DEVUELVE exactamente 3 mensajes de campañas de marketing por segmento.
`

    const user = {
        descripcion,
        audiencia: auds
    }

    const tries = [1, 2, 3]

    for (const attempt of tries) {
        try {
            const completion = await client.responses.create({
                model: "o4-mini",
                reasoning: { effort: "low" },
                input: [
                    { role: "system", content: system },
                    { role: "user", content: JSON.stringify(user) }
                ],
                max_output_tokens: 500
            })
            const raw = completion.output_text
            const parsed = parseSegmentsPayload(raw)
            if (!parsed) continue
            if (!parsed.segmentos) continue
            if (!Array.isArray(parsed.segmentos)) continue

            const allGood = parsed.segmentos.every((seg: any) =>
                Array.isArray(seg.mensajes) &&
                seg.mensajes.length === 3 &&
                seg.mensajes.every((m: any) =>
                    typeof m.texto === "string" && typeof m.tipo === "string"
                )
            )

            if (allGood) return parsed.segmentos
        } catch (e: any) {
            console.error(`Error intento ${attempt}:`, e)
            if (e?.status === 429 || e?.code === "insufficient_quota") {
                return []
            }
        }
    }

    return []
}


/**
 * Realiza una búsqueda semántica de imágenes usando Pinecone.
 *
 * Flujo:
 * 1. Intenta crear un embedding con OpenAI (modelo `text-embedding-3-small`).
 * 2. Si falla, usa un "pseudo-embedding" determinista como fallback.
 * 3. Consulta el índice Pinecone definido en `PINECONE_INDEX` (o `promptcontent` por defecto).
 * 4. Retorna hasta 5 coincidencias con metadatos.
 * 5. Si todo falla (error general), retorna imágenes mock.
 *
 * @async
 * @param {string} query Texto de búsqueda semántica.
 * @returns {Promise<ImageResult[]>} Lista de imágenes similares a la consulta.
 */
function pseudoEmbedding(query: string, dim = 1536) {
    // Genera un embedding determinista sin OpenAI
    const v = new Float32Array(dim)
    const seed = query || "empty"
    for (let i = 0; i < seed.length; i++) {
        const code = seed.charCodeAt(i)
        const idx = i % dim
        v[idx] = (v[idx] + (code % 31)) % 1
    }
    return Array.from(v)
}

async function semanticSearch(query: string, tagsFilter?: string[]) {
    try {
        const pc = getPinecone()
        const index = pc.index(process.env.PINECONE_INDEX || "promptcontent")
        const dim = Number(process.env.EMBED_DIM || 1536)
        const vector = pseudoEmbedding(query, dim)

        const q: any = { vector, topK: 5, includeMetadata: true }
        if (tagsFilter && tagsFilter.length > 0) {
            q.filter = { tags: { $in: tagsFilter } }
        }
        const res = await index.query(q)
        return (res.matches || []).map(m => ({
            url: (m.metadata as any).url,
            alt: (m.metadata as any).alt,
            tags: (m.metadata as any).tags || [],
            score: typeof (m as any).score === "number" ? (m as any).score : undefined
        }))
    } catch {
        return []
    }
}

/**
 * Crea y configura una instancia de `McpServer` con todas las tools
 * disponibles para PromptContent.
 *
 * Tools registradas:
 *
 * 1. **getContent**
 *    - Busca imágenes relacionadas con una descripción textual.
 *    - Usa MongoDB (búsqueda full-text / regex) y, si es necesario, `semanticSearch`.
 *    - Retorna imágenes + hashtags sugeridos.
 *
 * 2. **searchMusic**
 *    - Busca pistas en Spotify según un `query`.
 *    - Usa la función `searchTrack` importada.
 *
 * 3. **createCampaign**
 *    - Genera una campaña de marketing a partir de una descripción detallada.
 *    - Construye bitácora, segmentos, calendario, métricas y recomendaciones.
 *    - Intenta persistir logs en MongoDB (`CampaignLogs` y `AIRequests`).
 *
 * @returns {McpServer} Servidor MCP listo para conectarse a un transporte.
 */
export function createPromptContentServer() {
    const server = new McpServer({
        name: "mcp-server-promptcontent",
        version: "1.0.0",
        capabilities: { tools: {} }
    })

    // TOOL 1: getContent
    server.registerTool(
        "getContent",
        {
            title: "Buscar imágenes por descripción",
            description: "recibe una descripción textual y retorna imágenes que coinciden y sus hashtags",
            inputSchema: {
                descripcion: z.string().describe("Descripción textual para buscar imágenes")
            },
            outputSchema: {
                images: z.array(
                    z.object({
                        url: z.string(),
                        alt: z.string().optional(),
                        score: z.number().optional(),
                        tags: z.array(z.string()).optional()
                    })
                ),
                hashtags: z.array(z.string())
            }
        },
        /**
         * Handler de la tool `getContent`.
         *
         * Flujo:
         * 1. Intenta buscar en MongoDB usando índice de texto.
         * 2. Si falla, hace fallback a búsqueda por regex.
         * 3. Si no hay resultados, usa `semanticSearch` con embedding determinista (sin OpenAI).
         * 4. Si aún hay pocos resultados, completa con `mockImages`.
         * 5. Sanea URLs y construye hashtags a partir de descripción e imágenes.
         *
         * @async
         * @param {{ descripcion: string }} params Objeto de parámetros de entrada.
         * @param {string} params.descripcion Descripción textual para buscar imágenes.
         * @returns {Promise<{ content: { type: string; text: string }[]; structuredContent: { images: ImageResult[]; hashtags: string[] } }>}
         *          Respuesta MCP con contenido serializado y estructurado.
         */
        async ({ descripcion }) => {
            let images: { url: string; alt?: string; score?: number; tags?: string[] }[] = [];
            const originalText = descripcion
            let searchText = originalText
            let didTranslate = false
            if (isSpanish(originalText)) {
                searchText = await translateToEnglish(originalText)
                didTranslate = true
                try {
                    const db = await getDb()
                    await db.collection("AIRequests").insertOne({
                        aiRequestId: `translation_${Date.now()}`,
                        createdAt: new Date(),
                        completedAt: new Date(),
                        status: "completed",
                        type: "translation",
                        prompt: originalText,
                        output: searchText
                    })
                } catch {}
            }

            const explicitHashtags = (originalText.match(/#[\p{L}\p{N}_]+/gu) || []).map(h => h.toLowerCase());
            const explicitTokens = explicitHashtags.map(toTagToken);
            const explicitTokensEn = explicitTokens.map(toEnglishToken)

            try {
                const db = await getDb()
                const imagesCol = db.collection("images")
                // Query: búsqueda por texto y filtro opcional por hashtags
                const results = await imagesCol
                    .find(
                        { $and: [{ $text: { $search: searchText } }, ...(explicitTokensEn.length > 0 ? [{ tags: { $in: explicitTokensEn } }] : [])] },
                        { projection: { score: { $meta: "textScore" } } }
                    )
                    .sort({ score: { $meta: "textScore" } })
                    .limit(4)
                    .toArray()

                images = results.map((doc: any) => ({
                    url: doc.url,
                    alt: doc.alt,
                    score: doc.score,
                    tags: doc.tags
                }))

                if (images.length === 0) {
                    const enhancedQuery = searchText + (explicitTokensEn.length > 0 ? " hashtags: " + explicitTokensEn.join(", ") : "");
                    images = await semanticSearch(enhancedQuery, explicitTokensEn);
                }
                // No mock fallback: keep empty if semantic search returns none
                // Filtro post-búsqueda para priorizar coincidencias con hashtags
                images = images.filter(img => {
                    if (explicitTokensEn.length === 0) return true;
                    const imgTokens = (img.tags || []).map(t => t.toLowerCase());
                    return explicitTokensEn.some(tok => imgTokens.includes(tok));
                });
            } catch {
                images = []
            }

            // Reescribir URL para imágenes temáticas cuando hay hashtags explícitos
            if (explicitTokensEn.length > 0) {
                images = images.map((img, idx) => {
                    const themed = themedImageUrl(explicitTokensEn, idx)
                    return { ...img, url: themed || img.url }
                })
            }
            // Sanear URLs por si vienen con espacios/backticks
            images = images.map(i => ({ ...i, url: sanitizeUrl(i.url) }))

            const hashtagsBase = extractHashtags(searchText).map(toEnglishHashtag)
            const hashtagsExplicit = explicitHashtags.map(toEnglishHashtag)
            const hashtagsFromImages = images.flatMap(i => (i.tags || [])).map(toEnglishHashtag)
            let hashtags = Array.from(new Set([...hashtagsBase, ...hashtagsExplicit, ...hashtagsFromImages])).slice(0, 15)
            if (hashtags.some(h => /[áéíóúñ]/i.test(h))) {
                hashtags = hashtags.map(toEnglishHashtag)
            }
            if (hashtags.length === 0) {
                hashtags = ["#marketing", "#content", "#campaign"]
            }

            const output = { images, hashtags }
            return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output }
        }
    )

    // TOOL 2: searchMusic
    server.registerTool(
        "searchMusic",
        {
            title: "Buscar música para campaña",
            description: "busca pistas en Spotify por palabras clave y retorna datos útiles",
            inputSchema: {
                query: z.string().describe("Palabras clave para buscar música"),
                limit: z.number().int().min(1).max(10).optional()
            },
            outputSchema: {
                tracks: z.array(
                    z.object({
                        id: z.string(),
                        name: z.string(),
                        artist: z.string(),
                        album: z.string(),
                        preview: z.string().nullable(),
                        popularity: z.number(),
                        url: z.string()
                    })
                )
            }
        },
        /**
         * Handler de la tool `searchMusic`.
         *
         * Llama a `searchTrack` para obtener pistas desde Spotify
         * y retorna la lista formateada para MCP.
         *
         * @async
         * @param {{ query: string; limit?: number }} params Parámetros de entrada.
         * @param {string} params.query Palabras clave para la búsqueda.
         * @param {number} [params.limit=5] Máximo de pistas a retornar (1–10).
         * @returns {Promise<{ content: { type: string; text: string }[]; structuredContent: { tracks: any[] } }>}
         *          Respuesta MCP con pistas encontradas.
         */
        async ({ query, limit = 5 }) => {
            const tracks = await searchTrack(query, limit)
            const output = { tracks }
            return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output }
        }
    )

    // TOOL 3: createCampaign
    server.registerTool(
        "createMarketingCampaign",
        {
            title: "Crear campaña de marketing",
            description: "Crea una nueva campaña de mercadeo a partir de una descripción textual y un perfil de público meta. El tool debe almacenar la solicitud y generar una bitácora automática de tres mensajes adaptados al público objetivo, utilizando la información proporcionada sobre la campaña. Los mensajes deben ser coherentes con el propósito de la campaña, reflejar el tono adecuado para ese público meta y registrar en la bitácora cualquier decisión creativa tomada. El resultado debe incluir: ID de la campaña creada, la solicitud original, el público objetivo, los tres mensajes generados, la bitácora que describe el razonamiento, ajustes y consideraciones creativas.",
            inputSchema: {
                descripcion: z
                    .string()
                    .min(200)
                    .describe("Descripción detallada de la campaña de mercadeo (mínimo 200 caracteres)"),
                publico: z.array(
                    z.object({
                        edad: z
                            .object({ min: z.number().int().min(13), max: z.number().int().max(100) })
                            .optional(),
                        intereses: z.array(z.string()).optional(),
                        ubicaciones: z.array(z.string()).optional(),
                        genero: z.enum(["masculino", "femenino", "mixto"]).optional()

                    })
                    .describe("Definición del público objetivo")),
                duracion: z.enum(["1 semana", "2 semanas", "1 mes", "3 meses"]).optional(),
                presupuesto: z.number().int().min(100).optional()
            },
            outputSchema: {

                _id: z.string().optional(),
                logId: z.string(),
                campaignRef: z.string(),
                audience: z.array(
                    z.object({
                        edad: z.object({ min: z.number().int().min(13), max: z.number().int().max(100) }).nullable().optional(),
                        intereses: z.array(z.string()),
                        ubicaciones: z.array(z.string()),
                        genero: z.enum(["masculino", "femenino", "mixto"]).nullable().optional(),
                        nivelSocioeconomico: z.enum(["bajo", "medio", "alto", "mixto"]).nullable().optional()

                    })
                ),
                messages: z.array(
                    z.object({
                        role: z.string(),
                        text: z.string(),
                        ts: z.string()
                    })
                ),
                messageCount: z.number().int(),
                lastMessageTs: z.string(),
                createdAt: z.string()
            }
        },
        /**
         * Handler de la tool `createCampaign`.
         *
         * A partir de la descripción de la campaña y los datos de público:
         * - Genera un ID de campaña.
         * - Construye una bitácora con resumen, objetivos y estrategia.
         * - Define segmentos con mensajes personalizados (awareness / consideration / conversion).
         * - Crea un calendario semanal de publicaciones por plataforma y objetivo.
         * - Estima métricas de alcance, engagement, conversión y ROI.
         * - Intenta persistir logs en colecciones `CampaignLogs` y `AIRequests` de MongoDB (sin romper la respuesta en caso de error).
         *
         * @async
         * @param {{
         *   descripcion: string;
         *   publico: z.array(
         *     z.object({
         *       edad: z
         *         .object({ min: z.number().int().min(13), max: z.number().int().max(100) })
         *         .optional(),
         *       intereses: z.array(z.string()).optional(),
         *       ubicaciones: z.array(z.string()).optional(),
         *       genero: z.enum(["masculino", "femenino", "mixto"]).optional()
         *     })
         *   );
         *   duracion?: "1 semana" | "2 semanas" | "1 mes" | "3 meses";
         *   presupuesto?: number;
         * }} params Parámetros de entrada para la generación de campaña.
         * @returns {Promise<{ content: { type: string; text: string }[]; structuredContent: any }>}
         *          Respuesta MCP con la campaña generada.
         */
        async ({ descripcion, publico, duracion, presupuesto }) => {
            const id = `campaign_${Date.now()}`
            const auds = Array.isArray(publico) ? publico : [publico]
            const segmentsAll: any[] = []
            for (const [idx, aud] of auds.entries()) {
                const segs = await generateMessagesWithAI(descripcion, [aud])
                if (!Array.isArray(segs) || segs.length === 0) throw new Error("ai_failed")
                const chosen = segs[0]
                const msgs = Array.isArray(chosen.mensajes) ? chosen.mensajes.slice(0, 3) : []
                if (msgs.length !== 3) throw new Error("ai_failed_incomplete_messages")
                segmentsAll.push({
                    ...chosen,
                    nombre: chosen.nombre || `Audiencia ${idx + 1}`,
                    mensajes: msgs,
                    audienceIndex: idx
                })
            }
            const segmentos = segmentsAll
            const createdAt = new Date()
            const messages = segmentos.flatMap((seg: any) =>
                (seg.mensajes).map((m: any) => ({
                    ts: new Date(),
                    text: `[Audiencia ${seg.audienceIndex + 1} - ${seg.nombre}] ${m.tipo}: ${m.texto}`,
                    role: "assistant"
                }))
            )
            const messageCountNum = messages.length
            const messageCount = new Int32(messageCountNum)
            const lastMessageTs = messageCountNum ? messages[messageCountNum - 1].ts : createdAt
            let insertedIdStr: string | undefined
            const audienceStr = auds.map((a: any, i: number) => {
                const age = a.edad ? `${a.edad.min ?? ""}-${a.edad.max ?? ""}` : ""
                const ints = Array.isArray(a.intereses) ? a.intereses.join(",") : ""
                const locs = Array.isArray(a.ubicaciones) ? a.ubicaciones.join(",") : ""
                return `#${i + 1}:${age}|${ints}|${locs}|${a.genero || ""}`.trim()
            }).join(" || ")

            try {
                const db = await getDb()
                const ins = await db.collection("CampaignLogs").insertOne({
                    logId: id,
                    campaignRef: id,
                    audience: audienceStr,
                    messages,
                    messageCount,
                    lastMessageTs,
                    createdAt
                })
                insertedIdStr = ins?.insertedId ? String(ins.insertedId) : undefined

                await db.collection("AIRequests").insertOne({
                    aiRequestId: id,
                    createdAt,
                    completedAt: new Date(),
                    status: "completed",
                    modality: "text",
                    prompt: descripcion,
                    context: {
                        type: "text",
                        language: "es",
                        campaignRef: id
                    },
                    requestBody: { audiencias: auds },
                    mcp: { serverKey: "mcp-server-promptcontent", tool: "generateCampaignMessages" }
                })
            } catch (e) {
                console.error("CampaignLogs/AIRequests persistence error", e)
            }

            const output = {
                _id: insertedIdStr,
                logId: id,
                campaignRef: id,
                audience: auds.map((a: any) => ({
                    edad: a.edad || null,
                    intereses: a.intereses || [],
                    ubicaciones: a.ubicaciones || [],
                    genero: a.genero || null,
                    nivelSocioeconomico: a.nivelSocioeconomico || null
                })),
                messages: messages.map((m: { role: string; text: string; ts: Date }) => ({ role: m.role, text: m.text, ts: (m.ts as Date).toISOString() })),
                messageCount: messageCountNum,
                lastMessageTs: lastMessageTs.toISOString(),
                createdAt: createdAt.toISOString()
            }
            return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output }
        }
    )

    return server
}

; (async () => {
    if (process.env.RUN_AS_MCP_STDIO !== "0") {
        const server = createPromptContentServer()
        const transport = new StdioServerTransport()
        await server.connect(transport)
    }
})()
