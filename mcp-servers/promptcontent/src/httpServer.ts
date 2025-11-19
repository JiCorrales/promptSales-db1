import dotenv from "dotenv"
import http from "http"
import { MongoClient } from "mongodb"
import { Pinecone } from "@pinecone-database/pinecone"
import { searchTrack } from "./spotify"

dotenv.config()

let mongoClient: MongoClient | null = null
let mongoDbName = process.env.MONGODB_DB || "promptcontent"
function getDb() {
    const uri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017"
    if (!mongoClient) mongoClient = new MongoClient(uri)
    return mongoClient.connect().then(c => c.db(mongoDbName))
}

let pineconeClient: Pinecone | null = null
function getPinecone() {
    if (!pineconeClient) {
        const key = process.env.PINECONE_API_KEY
        if (!key) throw new Error("PINECONE_API_KEY no configurada")
        pineconeClient = new Pinecone({ apiKey: key })
    }
    return pineconeClient
}

function normalizeHashtag(t: string) {
    const cleaned = t.trim().replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "")
    return cleaned.startsWith("#") ? cleaned : `#${cleaned.toLowerCase()}`
}

function extractHashtags(text: string) {
    const lower = text.toLowerCase()
    const tokens = lower.split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean)
    const stop = new Set(["de","la","el","en","y","para","por","con","del","las","los","un","una","al","que","se"])
    const words = tokens.filter(t => !stop.has(t) && t.length > 2)
    const unique = Array.from(new Set(words))
    return unique.slice(0, 15).map(w => normalizeHashtag(w))
}

function sanitizeUrl(u: string) {
    return (u || "").replace(/^[\s`]+|[\s`]+$/g, "")
}

function hashCode(str: string) {
    let h = 0
    for (let i = 0; i < str.length; i++) h = (h << 5) - h + str.charCodeAt(i)
    return h | 0
}

function mockImages(seed: string) {
    const base = Math.abs(hashCode(seed))
    const arr: { url: string; alt?: string; tags?: string[] }[] = []
    for (let i = 0; i < 5; i++) {
        const s = base + i
        arr.push({ url: `https://picsum.photos/seed/${s}/800/600`, alt: `image-${s}` })
    }
    return arr
}

async function semanticSearch(query: string) {
    try {
        const pc = getPinecone()
        const index = pc.index(process.env.PINECONE_INDEX || "promptcontent")
        let vector: number[]
        try {
            const { OpenAI } = await import("openai")
            const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
            const emb = await openai.embeddings.create({ model: "text-embedding-3-small", input: query })
            vector = emb.data[0].embedding as any
        } catch {
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

async function toolGetContent({ descripcion }: { descripcion: string }) {
    let images: { url: string; alt?: string; score?: number; tags?: string[] }[] = []
    try {
        const db = await getDb()
        const imagesCol = db.collection("images")
        try {
            const results = await imagesCol
                .find({ $text: { $search: descripcion } }, { projection: { score: { $meta: "textScore" } } })
                .sort({ score: { $meta: "textScore" } })
                .limit(8)
                .toArray()
            images = results.map((doc: any) => ({ url: doc.url, alt: doc.alt, score: doc.score, tags: doc.tags }))
        } catch {
            const regex = new RegExp(descripcion.split(/\s+/).join("|"), "i")
            const fallback = await imagesCol
                .find({ $or: [{ title: regex }, { alt: regex }, { tags: regex }] })
                .limit(8)
                .toArray()
            images = fallback.map((doc: any) => ({ url: doc.url, alt: doc.alt, score: undefined, tags: doc.tags }))
        }
        if (images.length === 0) images = await semanticSearch(descripcion)
    } catch {
        images = mockImages(descripcion)
    }
    if (images.length < 3) {
        const extras = mockImages(descripcion)
        const need = 3 - images.length
        images = [...images, ...extras.slice(0, need)]
    }
    images = images.map(i => ({ ...i, url: sanitizeUrl(i.url) }))
    const hashtagsBase = extractHashtags(descripcion)
    const hashtagsFromImages = images.flatMap(i => (i.tags || [])).map(t => normalizeHashtag(t))
    let hashtags = Array.from(new Set([...hashtagsBase, ...hashtagsFromImages])).slice(0, 15)
    if (hashtags.length === 0) hashtags = ["#marketing", "#contenido", "#campaña"]
    const output = { images, hashtags }
    return output
}

async function toolSearchMusic({ query, limit = 5 }: { query: string; limit?: number }) {
    const tracks = await searchTrack(query, limit)
    return { tracks }
}

async function toolCreateCampaign({ descripcion, publico, duracion = "1 mes", presupuesto = 5000 }: { descripcion: string; publico: any; duracion?: string; presupuesto?: number }) {
    const id = `campaign_${Date.now()}`
    const edadMin = publico.edad?.min || 18
    const edadMax = publico.edad?.max || 65
    const intereses = publico.intereses || ["tecnología", "moda", "viajes", "estilo de vida"]
    const ubicaciones = publico.ubicaciones || ["México", "Colombia", "Argentina", "España"]
    const bitacora = {
        resumen: `Campaña dirigida a público ${edadMin}-${edadMax} años con intereses en ${intereses.join(", ")}. Objetivo: ${descripcion.slice(0, 150)}...`,
        objetivos: ["Incrementar el reconocimiento de marca en un 25%","Generar engagement significativo con el público objetivo","Convertir al menos el 3% de la audiencia en clientes potenciales","Establecer presencia en mercados clave de Latinoamérica y España"],
        estrategia: "Utilizar una combinación de contenido visual atractivo, mensajes personalizados por segmento y distribución estratégica en plataformas digitales para maximizar el impacto y alcance de la campaña."
    }
    const segmentos = [
        { nombre: "Jóvenes Profesionales", descripcion: `Adultos jóvenes de ${edadMin}-30 años, profesionales activos con poder adquisitivo medio-alto`, tamañoEstimado: Math.floor(presupuesto * 0.35), mensajes: [ { tipo: "awareness", texto: `¿Buscas ${descripcion.slice(0, 60)}...? Descubre cómo puede transformar tu día a día como joven profesional.`, tono: "moderno y aspiracional", llamadaAccion: "Descubre más", duracion: "7 días" }, { tipo: "consideration", texto: `Miles de jóvenes profesionales ya están beneficiándose de ${descripcion.slice(0, 50)}... Únete a la comunidad.`, tono: "social proof", llamadaAccion: "Únete ahora", duracion: "14 días" }, { tipo: "conversion", texto: `Aprovecha beneficios exclusivos de ${descripcion.slice(0, 45)}... durante esta semana.`, tono: "urgente", llamadaAccion: "Activa tu beneficio", duracion: "7 días" } ] },
        { nombre: "Familias Activas", descripcion: `Adultos de 30-45 años con familias, interesados en productos que mejoren su calidad de vida`, tamañoEstimado: Math.floor(presupuesto * 0.40), mensajes: [ { tipo: "awareness", texto: `Para ti que valoras tu tiempo con familia: ${descripcion.slice(0, 70)}... diseñado para hacer tu vida más fácil.`, tono: "cálido y confiable", llamadaAccion: "Conoce los beneficios", duracion: "10 días" }, { tipo: "consideration", texto: `Historias reales muestran cómo ${descripcion.slice(0, 55)}... mejora la rutina familiar.`, tono: "emocional", llamadaAccion: "Lee testimonios", duracion: "10 días" }, { tipo: "conversion", texto: `Mejora la calidad de vida de tu familia. ${descripcion.slice(0, 40)}... está aquí para ti.`, tono: "urgencia positiva", llamadaAccion: "Compra ahora", duracion: "5 días" } ] },
        { nombre: "Adultos Maduros", descripcion: `Adultos de 45-${edadMax} años con experiencia, buscando productos de calidad y confianza`, tamañoEstimado: Math.floor(presupuesto * 0.25), mensajes: [ { tipo: "awareness", texto: `La experiencia nos enseña que la calidad importa. ${descripcion.slice(0, 60)}... respaldado por años de excelencia.`, tono: "respetuoso y profesional", llamadaAccion: "Solicita información", duracion: "14 días" }, { tipo: "consideration", texto: `Comparativas muestran la superioridad de ${descripcion.slice(0, 50)}... frente a alternativas.`, tono: "informativo", llamadaAccion: "Ver comparativa", duracion: "10 días" }, { tipo: "conversion", texto: `Accede a condiciones preferenciales en ${descripcion.slice(0, 45)}... por tiempo limitado.`, tono: "premium", llamadaAccion: "Solicita oferta", duracion: "6 días" } ] }
    ]
    const semanas = duracion === "1 semana" ? 1 : duracion === "2 semanas" ? 2 : duracion === "1 mes" ? 4 : 12
    const calendario: { semana: number; dia: string; hora: string; plataforma: string; tipoContenido: string; objetivo: string }[] = []
    const plataformas = ["Instagram", "Facebook", "TikTok", "LinkedIn", "Twitter"]
    const horarios = ["09:00", "12:00", "15:00", "18:00", "21:00"]
    const tiposContenido = ["imagen", "video", "carrusel", "historia", "reel"]
    for (let semana = 1; semana <= semanas; semana++) {
        const dias = ["Lunes", "Miércoles", "Viernes"]
        dias.forEach((dia, idx) => {
            calendario.push({ semana, dia, hora: horarios[idx + 1] || "15:00", plataforma: plataformas[idx] || "Instagram", tipoContenido: tiposContenido[idx] || "imagen", objetivo: semana <= 2 ? "conciencia" : semana <= 3 ? "consideración" : "conversión" })
        })
    }
    const baseAlcance = presupuesto * 2.5
    const engagementRate = 0.03 + (intereses.length * 0.005)
    const conversionRate = 0.01 + (ubicaciones.length * 0.002)
    const metricas = { alcanceEstimado: Math.floor(baseAlcance), engagementEstimado: Math.floor(baseAlcance * engagementRate), conversionEstimada: Math.floor(baseAlcance * engagementRate * conversionRate), inversionRecomendada: presupuesto, retornoInversionEstimado: Math.floor(presupuesto * 2.2) }
    const recomendaciones = ["Ajusta el presupuesto semanalmente según el rendimiento de cada segmento","Monitorea los días y horarios con mayor engagement para optimizar la distribución","Crea variaciones de los mensajes para evitar el cansancio del público","Utiliza parámetros UTM para rastrear conversiones por plataforma","Implementa remarketing para usuarios que interactuaron pero no convirtieron","Realiza A/B testing con diferentes creatividades y copys","Mantén consistencia visual entre plataformas para reconocimiento de marca"]
    try {
        const db = await getDb()
        const messages = segmentos.flatMap(seg => seg.mensajes.map(m => ({ ts: new Date(), text: `[${seg.nombre}] ${m.tipo}: ${m.texto}`, role: "assistant" })))
        await db.collection("CampaignLogs").insertOne({ logId: id, campaignRef: id, audience: `${(publico.edad?.min||"")}-${(publico.edad?.max||"")} ${(publico.intereses||[]).join(", ")} ${(publico.ubicaciones||[]).join(", ")}`.trim(), messages, messageCount: messages.length, lastMessageTs: messages.length ? messages[messages.length-1].ts : new Date(), metaJson: JSON.stringify({ bitacora, segmentos, calendario, metricas, recomendaciones }), createdAt: new Date() })
        await db.collection("AIRequests").insertOne({ aiRequestId: id, createdAt: new Date(), completedAt: new Date(), status: "completed", prompt: descripcion, context: { type: "text", language: "es", campaignRef: id }, requestBody: publico, mcp: { serverKey: "mcp-server-promptcontent", tool: "generateCampaignMessages" } })
    } catch {}
    const output = { id, bitacora, segmentos, calendario, metricas, recomendaciones: recomendaciones.slice(0, 5) }
    return output
}

const port = Number(process.env.TOOLS_PORT || 8081)
const srv = http.createServer((req, res) => {
    if (req.method === "GET" && req.url === "/healthz") {
        res.writeHead(200, { "Content-Type": "application/json" })
        res.end(JSON.stringify({ status: "ok" }))
        return
    }
    if (req.method === "GET" && req.url === "/readyz") {
        res.writeHead(200, { "Content-Type": "text/plain" })
        res.end("ok")
        return
    }
    if (req.method === "POST" && (req.url === "/tools" || req.url === "/api/promptcontent")) {
        let body = ""
        req.on("data", chunk => { body += chunk })
        req.on("end", async () => {
            try {
                const parsed = body ? JSON.parse(body) : {}
                const tool = parsed.tool
                const input = parsed.input || {}
                if (tool === "getContent") {
                    const r = await toolGetContent(input)
                    res.writeHead(200, { "Content-Type": "application/json" })
                    res.end(JSON.stringify(r))
                    return
                }
                if (tool === "searchMusic") {
                    const r = await toolSearchMusic(input)
                    res.writeHead(200, { "Content-Type": "application/json" })
                    res.end(JSON.stringify(r))
                    return
                }
                if (tool === "createCampaign") {
                    const r = await toolCreateCampaign(input)
                    res.writeHead(200, { "Content-Type": "application/json" })
                    res.end(JSON.stringify(r))
                    return
                }
                res.writeHead(400, { "Content-Type": "application/json" })
                res.end(JSON.stringify({ error: "Tool no soportado", supportedTools: ["getContent","searchMusic","createCampaign"] }))
            } catch (err: any) {
                res.writeHead(500, { "Content-Type": "application/json" })
                res.end(JSON.stringify({ error: err?.message || "Error" }))
            }
        })
        return
    }
    res.writeHead(404)
    res.end()
})

srv.listen(port)
