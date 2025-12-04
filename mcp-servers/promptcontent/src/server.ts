/**
 * @file MCP server para PromptContent.
 * @description Expone herramientas MCP para:
 *  - Búsqueda de imágenes (MongoDB + Pinecone/OpenAI o mock).
 *  - Búsqueda de música en Spotify.
 *  - Generación de campañas de marketing con segmentación, calendario y métricas.
 */

import dotenv from "dotenv"
import path from "path"
dotenv.config({ path: path.resolve(__dirname, "..", ".env") })

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { z } from "zod"
import { Int32, ObjectId } from "mongodb"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { semanticSearch } from "./pinecone"
import { searchTrack } from "./spotify"
import OpenAI from "openai"
import {
    aiDeriveFilters,
    fetchCampaignChannels,
    fetchCampaignRows,
    fetchCrmInsights,
    fetchPromptAdsSnapshots,
    fetchSalesSummaries,
    formatLargeNumber,
    formatPercent,
    getPostgresClient
} from "./campaignPerformance"
import { randomUUID } from "crypto"
import { getDb } from "./db"
import { logAiRequest, logAiResponse } from "./aiLogs"

const __stdioMode = process.env.RUN_AS_MCP_STDIO !== "0"
if (__stdioMode) {
    const toStr = (x: any) => {
        if (typeof x === "string") return x
        try { return JSON.stringify(x) } catch { return String(x) }
    }
    const logToErr = (...args: any[]) => {
        try { process.stderr.write(args.map(toStr).join(" ") + "\n") } catch {}
    }
    console.log = logToErr
    console.info = logToErr
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

type AiRequestMeta = {
    campaignRef?: string
    segmentKey?: string
}

async function getAudienceWithAI(descripcion: string){
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")
    const client = new OpenAI({ apiKey: key })
    const system = `Tarea general:
A partir únicamente del texto recibido en el campo description, analiza la campaña y deduce todas las audiencias (públicos meta) mencionadas o implícitas.

Instrucciones obligatorias:

1. Lee y analiza la descripción completa.
2. Interpreta todo exclusivamente desde ese texto.
3. Identifica y clasifica automáticamente los públicos meta.
4. Para cada audiencia detectada, deduce:

- Rango de edad (explícito o inferido)
- Género (si es posible)
- Intereses
- Ubicación (si existe)
- Estilo de vida o comportamientos relevantes
- Profesión u ocupación (si aplica)
- Necesidades o dolores asociados
- Objetivo de marketing que esta audiencia persigue o responde mejor
- Tono ideal para comunicar
- CTA más adecuado para esta audiencia

5. Si la descripción sugiere múltiples segmentos, divídelos correctamente.
6. No generes mensajes. Solo devuelve la descripción de cada audiencia y su metadata inferida.

El output debe ser estrictamente en formato JSON.

Formato exacto de salida:

{
  "targets": [
    {
      "audience": "Descripción detallada del público meta",
      "ageRange": "Rango inferido",
      "gender": "Género inferido o 'no determinado'",
      "interests": ["...", "..."],
      "location": "Ubicación inferida o 'no especificada'",
      "lifestyle": "Estilo de vida o comportamiento",
      "profession": "Profesión si se infiere",
      "needs": ["Necesidad 1", "Necesidad 2"],
      "objective": "Objetivo deducido",
      "tone": "Tono deducido",
      "cta": "CTA deducido"
    }
  ]
}

NO escribas nada fuera del JSON.
NO incluyas explicaciones.`
    const user = {
        descripcion
    }
  const tries = [1, 2, 3]

    for (const attempt of tries) {
        const aiRequestId = randomUUID()
        const attemptStart = new Date()
        const requestStartMs = attemptStart.getTime()
        const requestBody = {
            attempt,
            user,
            system
        }


}

async function generateMessagesWithAI(descripcion: string, auds: any[], meta: AiRequestMeta = {}) {
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")
    const client = new OpenAI({ apiKey: key })
    const system = `
Tarea general:
A partir únicamente del texto recibido en el campo description, analiza la campaña, deduce toda la información necesaria y genera tres mensajes publicitarios por cada público meta identificado.
Tarea general:
Recibe un objeto JSON con audiencias ya procesadas, cada una con: audience, objective, tone y cta.
A partir de esa información, genera exactamente tres mensajes de campaña publicitaria por cada segmento.

Instrucciones obligatorias:

1. Usa únicamente la información proporcionada dentro de cada audiencia.
2. Cada mensaje debe ser:
   - Claro y persuasivo
   - Alineado al tono indicado
   - Coherente con el objetivo deducido
   - Adaptado al perfil de la audiencia
   - Debe incluir explícitamente el CTA asignado
3. Los mensajes deben ser 100% originales.
4. No repitas frases entre mensajes ni entre audiencias.
5. NO infieras nuevos públicos meta.
6. NO cambies datos de las audiencias.
7. Devuelve exactamente tres mensajes por audiencia.

El output debe ser estrictamente en formato JSON.

Formato exacto de salida:

{
  "results": [
    {
      "audience": "Descripción del público meta",
      "messages": [
        "Mensaje 1",
        "Mensaje 2",
        "Mensaje 3"
      ]
    }
  ]
}

NO escribas nada fuera del JSON.
NO incluyas explicaciones.

DEVUELVE exactamente 3 mensajes de campaA?as de marketing por segmento.
`

    const user = {
        descripcion,
        audiencia: auds
    }

    const tries = [1, 2, 3]

    for (const attempt of tries) {
        const aiRequestId = randomUUID()
        const attemptStart = new Date()
        const requestStartMs = attemptStart.getTime()
        const requestBody = {
            attempt,
            user,
            system
        }

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
            const segments = parsed?.segmentos
            const hasSegments = Array.isArray(segments)
            const allGood = hasSegments && segments.every((seg: any) =>
                Array.isArray(seg.mensajes) &&
                seg.mensajes.length === 3 &&
                seg.mensajes.every((m: any) =>
                    typeof m.texto === "string" && typeof m.tipo === "string"
                )
            )
            const responseStatus: "ok" | "partial" = allGood ? "ok" : "partial"
            const latencyMs = Date.now() - requestStartMs
            const traceId = typeof completion.id === "string" ? completion.id : null
            const usage: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number } = completion.usage ?? {}
            const aiResponseId = await logAiResponse({
                aiRequestId,
                status: responseStatus,
                latencyMS: latencyMs,
                responseBody: { raw },
                usageInputTokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : null,
                usageOutputTokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : null,
                usageTotalTokens: typeof usage.total_tokens === "number" ? usage.total_tokens : null,
                traceId
            })
            await logAiRequest({
                aiRequestId,
                createdAt: attemptStart,
                completedAt: new Date(),
                status: responseStatus === "ok" ? "completed" : "failed",
                prompt: descripcion,
                modality: "text",
                modelProvider: "openai",
                modelName: "o4-mini",
                modelVersion: typeof completion.model === "string" ? completion.model : "o4-mini",
                paramMaxTokens: 500,
                requestBody,
                responseRef: aiResponseId,
                traceId,
                byProcess: "promptcontent:createCampaignMessages",
                campaignRef: meta.campaignRef ?? null,
                segmentKey: meta.segmentKey ?? null,
                context: {
                    audiences: auds,
                    attempt
                }
            })

            if (responseStatus === "ok" && hasSegments) {
                return segments
            }
        } catch (error: any) {
            const latencyMs = Date.now() - requestStartMs
            const traceId = typeof error?.response?.id === "string" ? error.response.id : null
            const aiResponseId = await logAiResponse({
                aiRequestId,
                status: "error",
                latencyMS: latencyMs,
                errorMessage: error?.message ?? "unknown",
                traceId
            })
            await logAiRequest({
                aiRequestId,
                createdAt: attemptStart,
                completedAt: new Date(),
                status: "failed",
                prompt: descripcion,
                modality: "text",
                modelProvider: "openai",
                modelName: "o4-mini",
                paramMaxTokens: 500,
                requestBody,
                responseRef: aiResponseId,
                traceId,
                byProcess: "promptcontent:createCampaignMessages",
                campaignRef: meta.campaignRef ?? null,
                segmentKey: meta.segmentKey ?? null,
                context: {
                    audiences: auds,
                    attempt
                }
            })
            if (error?.status === 429 || error?.code === "insufficient_quota") {
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
        name: "mcp-server",
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
                    const ids = idResults.map((r: any) => r.id).filter(Boolean) // Asegurarse de que el ID existe. Están como strings en Pinecone
                    console.log("[getContent] mongo.lookup.ids", ids)

                    const objIds = ids.map((s: string) => new ObjectId(s)) // Convertir a ObjectId, porque en Pinecone se guardan como strings
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
        "createCampaignMessages",
        {
            title: "Crear mensajes para campaña de marketing",
            description: "Crea tres mensajes para una campaña de mercadeo a partir de una descripción textual y un perfil de público meta. El tool debe almacenar la solicitud y generar una bitácora automática de tres mensajes adaptados al público objetivo, utilizando la información proporcionada sobre la campaña. Los mensajes deben ser coherentes con el propósito de la campaña, reflejar el tono adecuado para ese público meta y registrar en la bitácora cualquier decisión creativa tomada. El resultado debe incluir: ID de la campaña creada, la solicitud original, el público objetivo, los tres mensajes generados, la bitácora que describe el razonamiento, ajustes y consideraciones creativas.",
            inputSchema: {
                descripcion: z
                    .string()
                    .min(200)
                    .describe("Descripción detallada de la campaña de mercadeo (mínimo 200 caracteres)")
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
        async ({ descripcion }) => {
            const campaignId = `campaign_${Date.now()}`
            //TODO: Return the audience profiles with AI before generatingMessagesWithAI
            const audienceProfiles = Array.isArray(publico) ? publico : [publico]
            const generatedSegments: any[] = []

            for (const [audienceIndex, singleAudience] of audienceProfiles.entries()) {
                const aiSegments = await generateMessagesWithAI(descripcion, [singleAudience], {
                    campaignRef: campaignId,
                    segmentKey: `audience_${audienceIndex + 1}`
                })
                if (!Array.isArray(aiSegments) || aiSegments.length === 0) throw new Error("ai_failed")

                const selectedSegment = aiSegments[0]
                const campaignMessages = Array.isArray(selectedSegment.mensajes) ? selectedSegment.mensajes.slice(0, 3) : []
                if (campaignMessages.length !== 3) throw new Error("ai_failed_incomplete_messages")

                generatedSegments.push({
                    ...selectedSegment,
                    nombre: selectedSegment.nombre || `Audiencia ${audienceIndex + 1}`,
                    mensajes: campaignMessages,
                    audienceIndex
                })
            }

            const campaignSegments = generatedSegments
            const campaignCreatedAt = new Date()

            const campaignMessages = campaignSegments.flatMap((segment: any) =>
                segment.mensajes.map((message: any) => ({
                    ts: new Date(),
                    text: `[Audiencia ${segment.audienceIndex + 1} - ${segment.nombre}] ${message.tipo}: ${message.texto}`,
                    role: "assistant"
                }))
            )

            const totalMessageCount = campaignMessages.length
            const messageCountInt32 = new Int32(totalMessageCount)
            const lastMessageTimestamp = totalMessageCount ? campaignMessages[totalMessageCount - 1].ts : campaignCreatedAt

            let insertedMongoId: string | undefined

            const audienceDescription = audienceProfiles.map((audience: any, index: number) => {
                const ageRange = audience.edad ? `${audience.edad.min ?? ""}-${audience.edad.max ?? ""}` : ""
                const interestsList = Array.isArray(audience.intereses) ? audience.intereses.join(",") : ""
                const locationsList = Array.isArray(audience.ubicaciones) ? audience.ubicaciones.join(",") : ""
                return `#${index + 1}:${ageRange}|${interestsList}|${locationsList}|${audience.genero || ""}`.trim()
            }).join(" || ")

            try {
                const database = await getDb()
                const campaignLogInsert = await database.collection("CampaignLogs").insertOne({
                    logId: campaignId,
                    campaignRef: campaignId,
                    audience: audienceDescription,
                    messages: campaignMessages,
                    messageCount: messageCountInt32,
                    lastMessageTs: lastMessageTimestamp,
                    createdAt: campaignCreatedAt
                })
                insertedMongoId = campaignLogInsert?.insertedId ? String(campaignLogInsert.insertedId) : undefined

                await database.collection("AIRequests").insertOne({
                    aiRequestId: campaignId,
                    createdAt: campaignCreatedAt,
                    completedAt: new Date(),
                    status: "completed",
                    modality: "text",
                    prompt: descripcion,
                    context: {
                        type: "text",
                        language: "es",
                        campaignRef: campaignId
                    },
                    requestBody: { audiencias: audienceProfiles },
                    mcp: { serverKey: "mcp-server-promptcontent", tool: "generateCampaignMessages" }
                })
            } catch (persistError) {
                console.error("CampaignLogs/AIRequests persistence error", persistError)
            }

            const responsePayload = {
                _id: insertedMongoId,
                logId: campaignId,
                campaignRef: campaignId,
                audience: audienceProfiles.map((audience: any) => ({
                    edad: audience.edad || null,
                    intereses: audience.intereses || [],
                    ubicaciones: audience.ubicaciones || [],
                    genero: audience.genero || null,
                    nivelSocioeconomico: audience.nivelSocioeconomico || null
                })),
                messages: campaignMessages.map((message: { role: string; text: string; ts: Date }) => ({
                    role: message.role,
                    text: message.text,
                    ts: (message.ts as Date).toISOString()
                })),
                messageCount: totalMessageCount,
                lastMessageTs: lastMessageTimestamp.toISOString(),
                createdAt: campaignCreatedAt.toISOString()
            }

            return {
                content: [{ type: "text", text: JSON.stringify(responsePayload) }],
                structuredContent: responsePayload
            }
        }
    )

    // TOOL 4: queryCampaignPerformance
    server.registerTool(
        "queryCampaignPerformance",
        {
            title: "Consultar rendimiento de campañas",
            description:
               "Permite preguntar en lenguaje natural por el alcance, éxito, ventas, reacciones y canales usados en campañas consolidadas. El handler cruza datos de PromptAdsSnapshots, CampaignChannels, salesSummary, Campaigns, Interactions, Calculations y PromptCrmSnapshots para materializar el alcance real, tasas de conversión/engagement/ROI, ventas netas, desglose de reacciones, canales o mercados y el estado de los leads asociados. Retorna este conjunto de métricas principales, fuentes ads/CRM, tasas clave y detalles por campaña listos para que la IA los exponga o explique sin inventar cifras.",
            inputSchema: {
                question: z
                    .string()
                    .min(10)
                    .describe("Pregunta en lenguaje natural sobre una o varias campañas.")
            },
            outputSchema: {
                question: z.string(),
                summary: z.string(),
                campaigns: z.array(
                    z.object({
                        campaignId: z.number(),
                        campaignName: z.string().nullable(),
                        status: z.string().nullable(),
                        companyName: z.string().nullable(),
                        startDate: z.string().nullable(),
                        endDate: z.string().nullable(),
                        snapshotDate: z.string().nullable(),
                        budgetAmount: z.number().nullable(),
                        reach: z.number().nullable(),
                        impressions: z.number().nullable(),
                        clicks: z.number().nullable(),
                        interactions: z.number().nullable(),
                        hoursViewed: z.number().nullable(),
                        cost: z.number().nullable(),
                        revenue: z.number().nullable(),
                        conversionRate: z.number().nullable(),
                        engagementRate: z.number().nullable(),
                        roi: z.number().nullable(),
                        totalSpent: z.number().nullable(),
                        totalRevenue: z.number().nullable(),
                        orders: z.number().nullable(),
                        salesAmount: z.number().nullable(),
                        returnsAmount: z.number().nullable(),
                        adsRevenue: z.number().nullable(),
                        currencyId: z.number().nullable(),
                        usersReached: z.number().nullable(),
                        interactionsBreakdown: z.object({
                            clicks: z.number().nullable(),
                            likes: z.number().nullable(),
                            comments: z.number().nullable(),
                            reactions: z.number().nullable(),
                            shares: z.number().nullable()
                        }),
                        channels: z.array(z.string()),
                        targetMarkets: z.array(z.string()),
                        crm: z.object({
                            totalLeads: z.number(),
                            conversionEvents: z.number(),
                            leadStatusCounts: z.record(z.number()),
                            channelNames: z.array(z.string())
                        })
                    })
                )
            }
        },
        async ({ question }) => {
            const sanitizedQuestion = question.trim()
            try {
                const client = await getPostgresClient()
                const filters = await aiDeriveFilters(sanitizedQuestion)
                const safeLimit = 3
                const campaigns = await fetchCampaignRows(client, filters, safeLimit)
                if (campaigns.length === 0) {
                    const empty = {
                        question: sanitizedQuestion,
                        summary: `No se encontraron campañas para la consulta: "${sanitizedQuestion}".`,
                        campaigns: []
                    }
                    return {
                        content: [{ type: "text", text: JSON.stringify(empty) }],
                        structuredContent: empty
                    }
                }
                const campaignIds = campaigns.map(row => row.campaignId)
                const snapshots = await fetchPromptAdsSnapshots(client, campaignIds)
                const channelMap = await fetchCampaignChannels(client, campaignIds)
                const salesMap = await fetchSalesSummaries(client, campaignIds)
                const { summaryMap, statusMap } = await fetchCrmInsights(client, campaignIds)
                const finalCampaigns = campaigns.map(row => {
                    const snapshot = snapshots.get(row.campaignId)
                    const sales = salesMap.get(row.campaignId)
                    const channelCandidates = [
                        ...(snapshot?.snapshotChannels ?? []),
                        ...(channelMap.get(row.campaignId) ?? [])
                    ]
                    const combinedChannels = Array.from(new Set(channelCandidates.filter(Boolean)))
                    const targetMarkets = Array.from(new Set(snapshot?.snapshotMarkets ?? [])).filter(Boolean)
                    const crmSummary = summaryMap.get(row.campaignId)
                    const leadStatusCounts = statusMap.get(row.campaignId) ?? {}
                    return {
                        campaignId: row.campaignId,
                        campaignName: row.campaignName,
                        status: row.status,
                        companyName: snapshot?.companyName ?? row.companyName,
                        startDate: row.startDate,
                        endDate: row.endDate,
                        snapshotDate: snapshot?.snapshotDate ?? null,
                        budgetAmount: row.budgetAmount ?? snapshot?.campaignBudget ?? null,
                        reach: snapshot?.totalReach ?? null,
                        impressions: snapshot?.totalImpressions ?? null,
                        clicks: snapshot?.totalClicks ?? null,
                        interactions: snapshot?.totalInteractions ?? null,
                        hoursViewed: snapshot?.totalHoursViewed ?? null,
                        cost: snapshot?.totalCost ?? null,
                        revenue: snapshot?.totalRevenue ?? null,
                        conversionRate: row.conversionRate,
                        engagementRate: row.engagementRate,
                        roi: row.roi,
                        totalSpent: row.totalSpent,
                        totalRevenue: row.calcTotalRevenue,
                        orders: sales?.orders ?? null,
                        salesAmount: sales?.salesAmount ?? null,
                        returnsAmount: sales?.returnsAmount ?? null,
                        adsRevenue: sales?.adsRevenue ?? snapshot?.totalRevenue ?? null,
                        currencyId: sales?.currencyId ?? null,
                        usersReached: row.interactions.usersReached,
                        interactionsBreakdown: {
                            clicks: row.interactions.clicks,
                            likes: row.interactions.likes,
                            comments: row.interactions.comments,
                            reactions: row.interactions.reactions,
                            shares: row.interactions.shares
                        },
                        channels: combinedChannels,
                        targetMarkets,
                        crm: {
                            totalLeads: crmSummary?.totalLeads ?? 0,
                            conversionEvents: crmSummary?.conversionEvents ?? 0,
                            leadStatusCounts,
                            channelNames: crmSummary?.channelNames ?? []
                        }
                    }
                })
                const summaryParts = [
                    `Pregunta: "${sanitizedQuestion}".`,
                    `Se analizaron ${finalCampaigns.length} campaña(s) relevantes.`
                ]
                const highlighted = finalCampaigns[0]
                if (highlighted) {
                    summaryParts.push(
                        `La campaña ${highlighted.campaignName ?? highlighted.campaignId} reportó alcance ${formatLargeNumber(
                            highlighted.reach
                        )}, tasa de éxito ${formatPercent(highlighted.conversionRate)}, ventas estimadas ${formatLargeNumber(
                            highlighted.salesAmount
                        )}.`
                    )
                }
                const output = {
                    question: sanitizedQuestion,
                    summary: summaryParts.join(" "),
                    campaigns: finalCampaigns
                }
                return {
                    content: [{ type: "text", text: JSON.stringify(output) }],
                    structuredContent: output
                }
            } catch (error: any) {
                console.error("[queryCampaignPerformance] error", error)
                const failed = {
                    question: sanitizedQuestion,
                    summary: `No fue posible responder la consulta (${error?.message || "error desconocido"}).`,
                    campaigns: []
                }
                return {
                    content: [{ type: "text", text: JSON.stringify(failed) }],
                    structuredContent: failed
                }
            }
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
