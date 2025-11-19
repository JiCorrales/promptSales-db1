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
import { MongoClient, Db } from "mongodb"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { Pinecone } from "@pinecone-database/pinecone"
import { searchTrack } from "./spotify"

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
 * Extrae hashtags a partir de un texto en español.
 *
 * - Convierte a minúsculas.
 * - Separa por caracteres no alfanuméricos.
 * - Elimina palabras vacías (stopwords) comunes en español.
 * - Filtra palabras de longitud mayor a 2.
 * - Genera hashtags normalizados.
 * - Limita a 15 hashtags.
 *
 * @param {string} text Texto de entrada.
 * @returns {string[]} Lista de hashtags sugeridos.
 */
function extractHashtags(text: string) {
    const lower = text.toLowerCase()
    const tokens = lower.split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean)
    const stop = new Set(["de", "la", "el", "en", "y", "para", "por", "con", "del", "las", "los", "un", "una", "al", "que", "se"])
    const words = tokens.filter(t => !stop.has(t) && t.length > 2)
    const unique = Array.from(new Set(words))
    return unique.slice(0, 15).map(w => normalizeHashtag(w))
}

/**
 * Calcula un hash entero a partir de una cadena (similar a Java).
 *
 * @param {string} str Cadena de entrada.
 * @returns {number} Hash entero con signo.
 */
function hashCode(str: string) {
    let h = 0
    for (let i = 0; i < str.length; i++) h = (h << 5) - h + str.charCodeAt(i)
    return h | 0
}

/**
 * @typedef {Object} ImageResult
 * @property {string} url URL de la imagen.
 * @property {string} [alt] Texto alternativo de la imagen.
 * @property {number} [score] Puntaje de relevancia (si aplica).
 * @property {string[]} [tags] Etiquetas asociadas a la imagen.
 */

/**
 * Genera un conjunto determinista de imágenes mock a partir de una semilla.
 *
 * Se usa como fallback cuando no hay acceso a Pinecone/Mongo/OpenAI.
 *
 * @param {string} seed Semilla para la generación determinista.
 * @returns {ImageResult[]} Arreglo de imágenes de prueba.
 */
function mockImages(seed: string) {
    const base = Math.abs(hashCode(seed))
    const arr: { url: string; alt?: string; tags?: string[] }[] = []
    for (let i = 0; i < 5; i++) {
        const s = base + i
        arr.push({ url: `https://picsum.photos/seed/${s}/800/600`, alt: `image-${s}` })
    }
    return arr
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
async function semanticSearch(query: string) {
    try {
        const pc = getPinecone()
        const index = pc.index(process.env.PINECONE_INDEX || "promptcontent")
        let vector: number[]

        // Intento normal con OpenAI
        try {
            const { OpenAI } = await import("openai")
            const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
            const emb = await openai.embeddings.create({ model: "text-embedding-3-small", input: query })
            vector = emb.data[0].embedding as any
        } catch {
            // Fallback determinista si no hay OpenAI
            /**
             * Genera un vector numérico pseudoaleatorio a partir de un texto.
             *
             * @param {string} text Texto de entrada.
             * @param {number} [dim=1536] Dimensión del embedding simulado.
             * @returns {number[]} Vector de números en [0, 1).
             */
            function pseudoEmbedding(text: string, dim = 1536) {
                let h = 2166136261
                for (let i = 0; i < text.length; i++) h = (h ^ text.charCodeAt(i)) * 16777619
                const out = new Array(dim)
                let x = h >>> 0
                for (let i = 0; i < dim; i++) {
                    x ^= x << 13
                    x ^= x >>> 17
                    x ^= x << 5
                    out[i] = (x % 1000) / 1000
                }
                return out
            }
            vector = pseudoEmbedding(query)
        }

        const res = await index.query({ vector, topK: 5, includeMetadata: true })
        return (res.matches || []).map(m => ({
            url: (m.metadata as any).url,
            alt: (m.metadata as any).alt,
            tags: (m.metadata as any).tags || [],
            score: typeof (m as any).score === "number" ? (m as any).score : undefined
        }))
    } catch {
        return mockImages(query)
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
         * 3. Si no hay resultados, usa `semanticSearch`.
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
            let images: { url: string; alt?: string; score?: number; tags?: string[] }[] = []

            try {
                const db = await getDb()
                const imagesCol = db.collection("images")

                try {
                    const results = await imagesCol
                        .find(
                            { $text: { $search: descripcion } },
                            { projection: { score: { $meta: "textScore" } } }
                        )
                        .sort({ score: { $meta: "textScore" } })
                        .limit(8)
                        .toArray()

                    images = results.map((doc: any) => ({
                        url: doc.url,
                        alt: doc.alt,
                        score: doc.score,
                        tags: doc.tags
                    }))
                } catch {
                    const regex = new RegExp(descripcion.split(/\s+/).join("|"), "i")
                    const fallback = await imagesCol
                        .find({ $or: [{ title: regex }, { alt: regex }, { tags: regex }] })
                        .limit(8)
                        .toArray()
                    images = fallback.map((doc: any) => ({
                        url: doc.url,
                        alt: doc.alt,
                        score: undefined,
                        tags: doc.tags
                    }))
                }

                if (images.length === 0) {
                    images = await semanticSearch(descripcion)
                }
            } catch {
                images = mockImages(descripcion)
            }

            if (images.length < 3) {
                const extras = mockImages(descripcion)
                const need = 3 - images.length
                images = [...images, ...extras.slice(0, need)]
            }

            // Sanear URLs por si vienen con espacios/backticks
            images = images.map(i => ({ ...i, url: sanitizeUrl(i.url) }))

            const hashtagsBase = extractHashtags(descripcion)
            const hashtagsFromImages = images.flatMap(i => (i.tags || [])).map(t => normalizeHashtag(t))
            let hashtags = Array.from(new Set([...hashtagsBase, ...hashtagsFromImages])).slice(0, 15)
            if (hashtags.length === 0) {
                hashtags = ["#marketing", "#contenido", "#campaña"]
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
        "createCampaign",
        {
            title: "Crear campaña de marketing",
            description: "genera una bitácora completa con mensajes personalizados, segmentos demográficos, distribución temporal y métricas estimadas",
            inputSchema: {
                descripcion: z
                    .string()
                    .min(200)
                    .describe("Descripción detallada de la campaña (mínimo 200 caracteres)"),
                publico: z
                    .object({
                        edad: z
                            .object({ min: z.number().int().min(13), max: z.number().int().max(100) })
                            .optional(),
                        intereses: z.array(z.string()).optional(),
                        ubicaciones: z.array(z.string()).optional(),
                        genero: z.enum(["masculino", "femenino", "mixto"]).optional(),
                        nivelSocioeconomico: z.enum(["bajo", "medio", "alto", "mixto"]).optional()
                    })
                    .describe("Definición del público objetivo"),
                duracion: z.enum(["1 semana", "2 semanas", "1 mes", "3 meses"]).optional(),
                presupuesto: z.number().int().min(100).optional()
            },
            outputSchema: {
                id: z.string(),
                bitacora: z.object({
                    resumen: z.string(),
                    objetivos: z.array(z.string()),
                    estrategia: z.string()
                }),
                segmentos: z.array(
                    z.object({
                        nombre: z.string(),
                        descripcion: z.string(),
                        tamañoEstimado: z.number(),
                        mensajes: z.array(
                            z.object({
                                tipo: z.string(),
                                texto: z.string(),
                                tono: z.string(),
                                llamadaAccion: z.string(),
                                duracion: z.string()
                            })
                        )
                    })
                ),
                calendario: z.array(
                    z.object({
                        semana: z.number(),
                        dia: z.string(),
                        hora: z.string(),
                        plataforma: z.string(),
                        tipoContenido: z.string(),
                        objetivo: z.string()
                    })
                ),
                metricas: z.object({
                    alcanceEstimado: z.number(),
                    engagementEstimado: z.number(),
                    conversionEstimada: z.number(),
                    inversionRecomendada: z.number(),
                    retornoInversionEstimado: z.number()
                }),
                recomendaciones: z.array(z.string())
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
         *   publico: {
         *     edad?: { min: number; max: number };
         *     intereses?: string[];
         *     ubicaciones?: string[];
         *     genero?: "masculino" | "femenino" | "mixto";
         *     nivelSocioeconomico?: "bajo" | "medio" | "alto" | "mixto";
         *   };
         *   duracion?: "1 semana" | "2 semanas" | "1 mes" | "3 meses";
         *   presupuesto?: number;
         * }} params Parámetros de entrada para la generación de campaña.
         * @returns {Promise<{ content: { type: string; text: string }[]; structuredContent: any }>}
         *          Respuesta MCP con la campaña generada.
         */
        async ({ descripcion, publico, duracion = "1 mes", presupuesto = 5000 }) => {
            const id = `campaign_${Date.now()}`

            const edadMin = publico.edad?.min || 18
            const edadMax = publico.edad?.max || 65
            const intereses = publico.intereses || ["tecnología", "moda", "viajes", "estilo de vida"]
            const ubicaciones = publico.ubicaciones || ["México", "Colombia", "Argentina", "España"]

            const bitacora = {
                resumen: `Campaña dirigida a público ${edadMin}-${edadMax} años con intereses en ${intereses.join(
                    ", "
                )}. Objetivo: ${descripcion.slice(0, 150)}...`,
                objetivos: [
                    "Incrementar el reconocimiento de marca en un 25%",
                    "Generar engagement significativo con el público objetivo",
                    "Convertir al menos el 3% de la audiencia en clientes potenciales",
                    "Establecer presencia en mercados clave de Latinoamérica y España"
                ],
                estrategia:
                    "Utilizar una combinación de contenido visual atractivo, mensajes personalizados por segmento y distribución estratégica en plataformas digitales para maximizar el impacto y alcance de la campaña."
            }

            const segmentos = [
                {
                    nombre: "Jóvenes Profesionales",
                    descripcion: `Adultos jóvenes de ${edadMin}-30 años, profesionales activos con poder adquisitivo medio-alto`,
                    tamañoEstimado: Math.floor(presupuesto * 0.35),
                    mensajes: [
                        {
                            tipo: "awareness",
                            texto: `¿Buscas ${descripcion.slice(
                                0,
                                60
                            )}...? Descubre cómo puede transformar tu día a día como joven profesional.`,
                            tono: "moderno y aspiracional",
                            llamadaAccion: "Descubre más",
                            duracion: "7 días"
                        },
                        {
                            tipo: "consideration",
                            texto: `Miles de jóvenes profesionales ya están beneficiándose de ${descripcion.slice(
                                0,
                                50
                            )}... Únete a la comunidad.`,
                            tono: "social proof",
                            llamadaAccion: "Únete ahora",
                            duracion: "14 días"
                        },
                        {
                            tipo: "conversion",
                            texto: `Aprovecha beneficios exclusivos de ${descripcion.slice(
                                0,
                                45
                            )}... durante esta semana.`,
                            tono: "urgente",
                            llamadaAccion: "Activa tu beneficio",
                            duracion: "7 días"
                        }
                    ]
                },
                {
                    nombre: "Familias Activas",
                    descripcion:
                        "Adultos de 30-45 años con familias, interesados en productos que mejoren su calidad de vida",
                    tamañoEstimado: Math.floor(presupuesto * 0.4),
                    mensajes: [
                        {
                            tipo: "awareness",
                            texto: `Para ti que valoras tu tiempo con familia: ${descripcion.slice(
                                0,
                                70
                            )}... diseñado para hacer tu vida más fácil.`,
                            tono: "cálido y confiable",
                            llamadaAccion: "Conoce los beneficios",
                            duracion: "10 días"
                        },
                        {
                            tipo: "consideration",
                            texto: `Historias reales muestran cómo ${descripcion.slice(
                                0,
                                55
                            )}... mejora la rutina familiar.`,
                            tono: "emocional",
                            llamadaAccion: "Lee testimonios",
                            duracion: "10 días"
                        },
                        {
                            tipo: "conversion",
                            texto: `Mejora la calidad de vida de tu familia. ${descripcion.slice(
                                0,
                                40
                            )}... está aquí para ti.`,
                            tono: "urgencia positiva",
                            llamadaAccion: "Compra ahora",
                            duracion: "5 días"
                        }
                    ]
                },
                {
                    nombre: "Adultos Maduros",
                    descripcion: `Adultos de 45-${edadMax} años con experiencia, buscando productos de calidad y confianza`,
                    tamañoEstimado: Math.floor(presupuesto * 0.25),
                    mensajes: [
                        {
                            tipo: "awareness",
                            texto: `La experiencia nos enseña que la calidad importa. ${descripcion.slice(
                                0,
                                60
                            )}... respaldado por años de excelencia.`,
                            tono: "respetuoso y profesional",
                            llamadaAccion: "Solicita información",
                            duracion: "14 días"
                        },
                        {
                            tipo: "consideration",
                            texto: `Comparativas muestran la superioridad de ${descripcion.slice(
                                0,
                                50
                            )}... frente a alternativas.`,
                            tono: "informativo",
                            llamadaAccion: "Ver comparativa",
                            duracion: "10 días"
                        },
                        {
                            tipo: "conversion",
                            texto: `Accede a condiciones preferenciales en ${descripcion.slice(
                                0,
                                45
                            )}... por tiempo limitado.`,
                            tono: "premium",
                            llamadaAccion: "Solicita oferta",
                            duracion: "6 días"
                        }
                    ]
                }
            ]

            const semanas = duracion === "1 semana" ? 1 : duracion === "2 semanas" ? 2 : duracion === "1 mes" ? 4 : 12
            const calendario: {
                semana: number
                dia: string
                hora: string
                plataforma: string
                tipoContenido: string
                objetivo: string
            }[] = []
            const plataformas = ["Instagram", "Facebook", "TikTok", "LinkedIn", "Twitter"]
            const horarios = ["09:00", "12:00", "15:00", "18:00", "21:00"]
            const tiposContenido = ["imagen", "video", "carrusel", "historia", "reel"]

            for (let semana = 1; semana <= semanas; semana++) {
                const dias = ["Lunes", "Miércoles", "Viernes"]
                dias.forEach((dia, idx) => {
                    calendario.push({
                        semana,
                        dia,
                        hora: horarios[idx + 1] || "15:00",
                        plataforma: plataformas[idx] || "Instagram",
                        tipoContenido: tiposContenido[idx] || "imagen",
                        objetivo: semana <= 2 ? "conciencia" : semana <= 3 ? "consideración" : "conversión"
                    })
                })
            }

            const baseAlcance = presupuesto * 2.5
            const engagementRate = 0.03 + intereses.length * 0.005
            const conversionRate = 0.01 + ubicaciones.length * 0.002
            const metricas = {
                alcanceEstimado: Math.floor(baseAlcance),
                engagementEstimado: Math.floor(baseAlcance * engagementRate),
                conversionEstimada: Math.floor(baseAlcance * engagementRate * conversionRate),
                inversionRecomendada: presupuesto,
                retornoInversionEstimado: Math.floor(presupuesto * 2.2)
            }

            const recomendaciones = [
                "Ajusta el presupuesto semanalmente según el rendimiento de cada segmento",
                "Monitorea los días y horarios con mayor engagement para optimizar la distribución",
                "Crea variaciones de los mensajes para evitar el cansancio del público",
                "Utiliza parámetros UTM para rastrear conversiones por plataforma",
                "Implementa remarketing para usuarios que interactuaron pero no convirtieron",
                "Realiza A/B testing con diferentes creatividades y copys",
                "Mantén consistencia visual entre plataformas para reconocimiento de marca"
            ]

            // Persistencia en Mongo (CampaignLogs + AIRequests) sin romper la respuesta si falla
            try {
                const db = await getDb()
                const messages = segmentos.flatMap(seg =>
                    seg.mensajes.map(m => ({
                        ts: new Date(),
                        text: `[${seg.nombre}] ${m.tipo}: ${m.texto}`,
                        role: "assistant"
                    }))
                )

                await db.collection("CampaignLogs").insertOne({
                    logId: id,
                    campaignRef: id,
                    audience: `${(publico.edad?.min || "")}-${(publico.edad?.max || "")} ${(publico.intereses || []).join(
                        ", "
                    )} ${(publico.ubicaciones || []).join(", ")}`.trim(),
                    messages,
                    messageCount: messages.length,
                    lastMessageTs: messages.length ? messages[messages.length - 1].ts : new Date(),
                    metaJson: JSON.stringify({ bitacora, segmentos, calendario, metricas, recomendaciones }),
                    createdAt: new Date()
                })

                await db.collection("AIRequests").insertOne({
                    aiRequestId: id,
                    createdAt: new Date(),
                    completedAt: new Date(),
                    status: "completed",
                    prompt: descripcion,
                    context: {
                        type: "text",
                        language: "es",
                        campaignRef: id
                    },
                    requestBody: publico,
                    mcp: { serverKey: "mcp-server-promptcontent", tool: "generateCampaignMessages" }
                })
            } catch {
                // si falla el log en Mongo, no rompemos la respuesta MCP
            }

            const output = {
                id,
                bitacora,
                segmentos,
                calendario,
                metricas,
                recomendaciones: recomendaciones.slice(0, 5)
            }
            return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }], structuredContent: output }
        }
    )

    return server
}

;(async () => {
    if (process.env.RUN_AS_MCP_STDIO !== "0") {
        const server = createPromptContentServer()
        const transport = new StdioServerTransport()
        await server.connect(transport)
    }
})()
