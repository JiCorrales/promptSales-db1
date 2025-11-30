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
import { MongoClient, Db, Int32, ObjectId } from "mongodb"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { semanticSearch } from "./pinecone"
import { searchTrack } from "./spotify"
import OpenAI from "openai"

let mongoClient: MongoClient | null = null
let mongoDb: Db | null = null

async function getDb() {
    if (mongoDb) return mongoDb
    const uri = process.env.MONGODB_URI
    const dbName = process.env.MONGODB_DB
    if (!uri || !dbName) throw new Error("MONGODB_ENV_MISSING")

    mongoClient = await new MongoClient(uri).connect()
    mongoDb = mongoClient.db(dbName)
    try {
        const imagesCol = mongoDb.collection("images")
        await imagesCol.createIndex({ alt: "text" }, { name: "images_text_alt" })
    } catch {}
    return mongoDb
}

function normalizeHashtag(t: string) {
    const cleaned = t.trim().replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "")
    return cleaned.startsWith("#") ? cleaned : `#${cleaned.toLowerCase()}`
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
    const words = tokens.filter(t => t.length > 2)
    const unique = Array.from(new Set(words))
    return unique.slice(0, 15).map(w => normalizeHashtag(w))
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

async function generateMessagesWithAI(descripcion: string, auds: any[]) {
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")
    const client = new OpenAI({ apiKey: key })
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
            if (e?.status === 429 || e?.code === "insufficient_quota") {
                return []
            }
        }
    }

    return []
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
//TODO: mejorar tipado de respuestas estructuradas
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
            description: "Busca imágenes relevantes (ES/EN) usando embeddings en Pinecone a partir de una descripción y devuelve URLs con metadatos más hashtags sugeridos",
            inputSchema: {
                descripcion: z.string().describe("Descripción textual para buscar imágenes")
            },
            outputSchema: {
                images: z.array(
                    z.object({
                        url: z.string(),
                        description: z.string().optional(),
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
            console.log("[getContent] start", { descripcion })
            let images: { url: string; description?: string; tags?: string[] }[] = [];
            try {
                // Buscar imágenes por descripción con embeddings
                const idResults: any[] = await semanticSearch(descripcion);
                console.log("[getContent] pinecone.matches", { count: Array.isArray(idResults) ? idResults.length : 0, sample: idResults?.[0] })
                // Usar los IDs encontrados para buscar en MongoDB
                if (Array.isArray(idResults) && idResults.length > 0) {
                    const db = await getDb()
                    const imagesCol = db.collection("images")
                    const ids = idResults.map((r: any) => r.id).filter(Boolean)
                    console.log("[getContent] mongo.lookup.ids", ids)
                    const objIds = ids.map((s: string) => new ObjectId(s))
                    const docs = await imagesCol.find({ _id: { $in: objIds } }).limit(5).toArray()
                    console.log("[getContent] mongo.docs", { count: docs.length })
                    images = docs.map((doc: any) => ({ url: doc.url, description: doc.alt, tags: doc.tags }))
                }
            } catch (e: any) {
                console.error("[getContent] error.semanticSearch", e)
                images = []
            }

            const hashtagsFromImages = images.flatMap(i => (i.tags || [])).map(normalizeHashtag)
            let hashtags = Array.from(new Set(hashtagsFromImages)).slice(0, 15)
            if (hashtags.length === 0) {
                console.log("[getContent] hashtags.fallback", { reason: "no-image-tags" })
                hashtags = extractHashtags(descripcion)
            }

            const output = { images, hashtags }
            console.log("[getContent] end", { imagesCount: images.length, hashtagsCount: hashtags.length })
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
