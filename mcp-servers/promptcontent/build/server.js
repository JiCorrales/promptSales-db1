"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
const http_1 = __importDefault(require("http"));
dotenv_1.default.config();
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const zod_1 = require("zod");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const mongodb_1 = require("mongodb");
const pinecone_1 = require("@pinecone-database/pinecone");
const spotify_1 = require("./spotify");
let mongoClient = null;
let mongoDb = null;
let pineconeClient = null;
async function getDb() {
    if (mongoDb)
        return mongoDb;
    const uri = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017";
    mongoClient = await new mongodb_1.MongoClient(uri).connect();
    mongoDb = mongoClient.db(process.env.MONGODB_DB || "promptcontent");
    return mongoDb;
}
function getPinecone() {
    if (!pineconeClient) {
        const key = process.env.PINECONE_API_KEY;
        if (!key)
            throw new Error("PINECONE_API_KEY no configurada");
        pineconeClient = new pinecone_1.Pinecone({ apiKey: key });
    }
    return pineconeClient;
}
const server = new mcp_js_1.McpServer({
    name: "mcp-server-promptcontent",
    version: "1.0.0",
    capabilities: { tools: {} }
});
server.registerTool("getContent", {
    title: "Buscar imágenes por descripción",
    description: "recibe una descripción textual y retorna imágenes que coinciden y sus hashtags",
    inputSchema: {
        descripcion: zod_1.z.string().describe("Descripción textual para buscar imágenes")
    },
    outputSchema: {
        images: zod_1.z.array(zod_1.z.object({
            url: zod_1.z.string(),
            alt: zod_1.z.string().optional(),
            score: zod_1.z.number().optional(),
            tags: zod_1.z.array(zod_1.z.string()).optional()
        })),
        hashtags: zod_1.z.array(zod_1.z.string())
    }
}, async ({ descripcion }) => {
    let images = [];
    try {
        const db = await getDb();
        const imagesCol = db.collection("images");
        try {
            const results = await imagesCol
                .find({ $text: { $search: descripcion } }, { projection: { score: { $meta: "textScore" } } })
                .sort({ score: { $meta: "textScore" } })
                .limit(8)
                .toArray();
            images = results.map((doc) => ({ url: doc.url, alt: doc.alt, score: doc.score, tags: doc.tags }));
        }
        catch {
            const regex = new RegExp(descripcion.split(/\s+/).join("|"), "i");
            const fallback = await imagesCol
                .find({ $or: [{ title: regex }, { alt: regex }, { tags: regex }] })
                .limit(8)
                .toArray();
            images = fallback.map((doc) => ({ url: doc.url, alt: doc.alt, score: undefined, tags: doc.tags }));
        }
        if (images.length === 0) {
            images = await semanticSearch(descripcion);
        }
    }
    catch {
        images = mockImages(descripcion);
    }
    if (images.length < 3) {
        const extras = mockImages(descripcion);
        const need = 3 - images.length;
        images = [...images, ...extras.slice(0, need)];
    }
    images = images.map(i => ({ ...i, url: sanitizeUrl(i.url) }));
    const hashtagsBase = extractHashtags(descripcion);
    const hashtagsFromImages = images.flatMap(i => (i.tags || [])).map(t => normalizeHashtag(t));
    let hashtags = Array.from(new Set([...hashtagsBase, ...hashtagsFromImages])).slice(0, 15);
    if (hashtags.length === 0) {
        hashtags = ["#marketing", "#contenido", "#campaña"];
    }
    const output = { images, hashtags };
    return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output };
});
server.registerTool("searchMusic", {
    title: "Buscar música para campaña",
    description: "busca pistas en Spotify por palabras clave y retorna datos útiles",
    inputSchema: {
        query: zod_1.z.string().describe("Palabras clave para buscar música"),
        limit: zod_1.z.number().int().min(1).max(10).optional()
    },
    outputSchema: {
        tracks: zod_1.z.array(zod_1.z.object({
            id: zod_1.z.string(),
            name: zod_1.z.string(),
            artist: zod_1.z.string(),
            album: zod_1.z.string(),
            preview: zod_1.z.string().nullable(),
            popularity: zod_1.z.number(),
            url: zod_1.z.string()
        }))
    }
}, async ({ query, limit = 5 }) => {
    const tracks = await (0, spotify_1.searchTrack)(query, limit);
    const output = { tracks };
    return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output };
});
server.registerTool("createCampaign", {
    title: "Crear campaña de marketing",
    description: "genera una bitácora completa con mensajes personalizados, segmentos demográficos, distribución temporal y métricas estimadas",
    inputSchema: {
        descripcion: zod_1.z.string().min(200).describe("Descripción detallada de la campaña (mínimo 200 caracteres)"),
        publico: zod_1.z.object({
            edad: zod_1.z.object({ min: zod_1.z.number().int().min(13), max: zod_1.z.number().int().max(100) }).optional(),
            intereses: zod_1.z.array(zod_1.z.string()).optional(),
            ubicaciones: zod_1.z.array(zod_1.z.string()).optional(),
            genero: zod_1.z.enum(["masculino", "femenino", "mixto"]).optional(),
            nivelSocioeconomico: zod_1.z.enum(["bajo", "medio", "alto", "mixto"]).optional()
        }).describe("Definición del público objetivo"),
        duracion: zod_1.z.enum(["1 semana", "2 semanas", "1 mes", "3 meses"]).optional(),
        presupuesto: zod_1.z.number().int().min(100).optional()
    },
    outputSchema: {
        id: zod_1.z.string(),
        bitacora: zod_1.z.object({
            resumen: zod_1.z.string(),
            objetivos: zod_1.z.array(zod_1.z.string()),
            estrategia: zod_1.z.string()
        }),
        segmentos: zod_1.z.array(zod_1.z.object({
            nombre: zod_1.z.string(),
            descripcion: zod_1.z.string(),
            tamañoEstimado: zod_1.z.number(),
            mensajes: zod_1.z.array(zod_1.z.object({
                tipo: zod_1.z.string(),
                texto: zod_1.z.string(),
                tono: zod_1.z.string(),
                llamadaAccion: zod_1.z.string(),
                duracion: zod_1.z.string()
            }))
        })),
        calendario: zod_1.z.array(zod_1.z.object({
            semana: zod_1.z.number(),
            dia: zod_1.z.string(),
            hora: zod_1.z.string(),
            plataforma: zod_1.z.string(),
            tipoContenido: zod_1.z.string(),
            objetivo: zod_1.z.string()
        })),
        metricas: zod_1.z.object({
            alcanceEstimado: zod_1.z.number(),
            engagementEstimado: zod_1.z.number(),
            conversionEstimada: zod_1.z.number(),
            inversionRecomendada: zod_1.z.number(),
            retornoInversionEstimado: zod_1.z.number()
        }),
        recomendaciones: zod_1.z.array(zod_1.z.string())
    }
}, async ({ descripcion, publico, duracion = "1 mes", presupuesto = 5000 }) => {
    const id = `campaign_${Date.now()}`;
    const edadMin = publico.edad?.min || 18;
    const edadMax = publico.edad?.max || 65;
    const intereses = publico.intereses || ["tecnología", "moda", "viajes", "estilo de vida"];
    const ubicaciones = publico.ubicaciones || ["México", "Colombia", "Argentina", "España"];
    const bitacora = {
        resumen: `Campaña dirigida a público ${edadMin}-${edadMax} años con intereses en ${intereses.join(", ")}. Objetivo: ${descripcion.slice(0, 150)}...`,
        objetivos: [
            "Incrementar el reconocimiento de marca en un 25%",
            "Generar engagement significativo con el público objetivo",
            "Convertir al menos el 3% de la audiencia en clientes potenciales",
            "Establecer presencia en mercados clave de Latinoamérica y España"
        ],
        estrategia: "Utilizar una combinación de contenido visual atractivo, mensajes personalizados por segmento y distribución estratégica en plataformas digitales para maximizar el impacto y alcance de la campaña."
    };
    const segmentos = [
        {
            nombre: "Jóvenes Profesionales",
            descripcion: `Adultos jóvenes de ${edadMin}-30 años, profesionales activos con poder adquisitivo medio-alto`,
            tamañoEstimado: Math.floor(presupuesto * 0.35),
            mensajes: [
                {
                    tipo: "awareness",
                    texto: `¿Buscas ${descripcion.slice(0, 60)}...? Descubre cómo puede transformar tu día a día como joven profesional.`,
                    tono: "moderno y aspiracional",
                    llamadaAccion: "Descubre más",
                    duracion: "7 días"
                },
                {
                    tipo: "consideration",
                    texto: `Miles de jóvenes profesionales ya están beneficiándose de ${descripcion.slice(0, 50)}... Únete a la comunidad.`,
                    tono: "social proof",
                    llamadaAccion: "Únete ahora",
                    duracion: "14 días"
                },
                {
                    tipo: "conversion",
                    texto: `Aprovecha beneficios exclusivos de ${descripcion.slice(0, 45)}... durante esta semana.`,
                    tono: "urgente",
                    llamadaAccion: "Activa tu beneficio",
                    duracion: "7 días"
                }
            ]
        },
        {
            nombre: "Familias Activas",
            descripcion: `Adultos de 30-45 años con familias, interesados en productos que mejoren su calidad de vida`,
            tamañoEstimado: Math.floor(presupuesto * 0.40),
            mensajes: [
                {
                    tipo: "awareness",
                    texto: `Para ti que valoras tu tiempo con familia: ${descripcion.slice(0, 70)}... diseñado para hacer tu vida más fácil.`,
                    tono: "cálido y confiable",
                    llamadaAccion: "Conoce los beneficios",
                    duracion: "10 días"
                },
                {
                    tipo: "consideration",
                    texto: `Historias reales muestran cómo ${descripcion.slice(0, 55)}... mejora la rutina familiar.`,
                    tono: "emocional",
                    llamadaAccion: "Lee testimonios",
                    duracion: "10 días"
                },
                {
                    tipo: "conversion",
                    texto: `Mejora la calidad de vida de tu familia. ${descripcion.slice(0, 40)}... está aquí para ti.`,
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
                    texto: `La experiencia nos enseña que la calidad importa. ${descripcion.slice(0, 60)}... respaldado por años de excelencia.`,
                    tono: "respetuoso y profesional",
                    llamadaAccion: "Solicita información",
                    duracion: "14 días"
                },
                {
                    tipo: "consideration",
                    texto: `Comparativas muestran la superioridad de ${descripcion.slice(0, 50)}... frente a alternativas.`,
                    tono: "informativo",
                    llamadaAccion: "Ver comparativa",
                    duracion: "10 días"
                },
                {
                    tipo: "conversion",
                    texto: `Accede a condiciones preferenciales en ${descripcion.slice(0, 45)}... por tiempo limitado.`,
                    tono: "premium",
                    llamadaAccion: "Solicita oferta",
                    duracion: "6 días"
                }
            ]
        }
    ];
    // Persist in CampaignLogs schema
    const semanas = duracion === "1 semana" ? 1 : duracion === "2 semanas" ? 2 : duracion === "1 mes" ? 4 : 12;
    const calendario = [];
    const plataformas = ["Instagram", "Facebook", "TikTok", "LinkedIn", "Twitter"];
    const horarios = ["09:00", "12:00", "15:00", "18:00", "21:00"];
    const tiposContenido = ["imagen", "video", "carrusel", "historia", "reel"];
    for (let semana = 1; semana <= semanas; semana++) {
        const dias = ["Lunes", "Miércoles", "Viernes"];
        dias.forEach((dia, idx) => {
            calendario.push({
                semana,
                dia,
                hora: horarios[idx + 1] || "15:00",
                plataforma: plataformas[idx] || "Instagram",
                tipoContenido: tiposContenido[idx] || "imagen",
                objetivo: semana <= 2 ? "conciencia" : semana <= 3 ? "consideración" : "conversión"
            });
        });
    }
    const baseAlcance = presupuesto * 2.5;
    const engagementRate = 0.03 + (intereses.length * 0.005);
    const conversionRate = 0.01 + (ubicaciones.length * 0.002);
    const metricas = {
        alcanceEstimado: Math.floor(baseAlcance),
        engagementEstimado: Math.floor(baseAlcance * engagementRate),
        conversionEstimada: Math.floor(baseAlcance * engagementRate * conversionRate),
        inversionRecomendada: presupuesto,
        retornoInversionEstimado: Math.floor(presupuesto * 2.2)
    };
    const recomendaciones = [
        "Ajusta el presupuesto semanalmente según el rendimiento de cada segmento",
        "Monitorea los días y horarios con mayor engagement para optimizar la distribución",
        "Crea variaciones de los mensajes para evitar el cansancio del público",
        "Utiliza parámetros UTM para rastrear conversiones por plataforma",
        "Implementa remarketing para usuarios que interactuaron pero no convirtieron",
        "Realiza A/B testing con diferentes creatividades y copys",
        "Mantén consistencia visual entre plataformas para reconocimiento de marca"
    ];
    // Persist after all data is ready (align with CampaignLogs schema)
    try {
        const db = await getDb();
        const messages = segmentos.flatMap(seg => seg.mensajes.map(m => ({ ts: new Date(), text: `[${seg.nombre}] ${m.tipo}: ${m.texto}`, role: "assistant" })));
        await db.collection("CampaignLogs").insertOne({
            logId: id,
            campaignRef: id,
            audience: `${(publico.edad?.min || "")}-${(publico.edad?.max || "")} ${(publico.intereses || []).join(", ")} ${(publico.ubicaciones || []).join(", ")}`.trim(),
            messages,
            messageCount: messages.length,
            lastMessageTs: messages.length ? messages[messages.length - 1].ts : new Date(),
            metaJson: JSON.stringify({ bitacora, segmentos, calendario, metricas, recomendaciones }),
            createdAt: new Date()
        });
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
        });
    }
    catch { }
    const output = {
        id,
        bitacora,
        segmentos,
        calendario,
        metricas,
        recomendaciones: recomendaciones.slice(0, 5)
    };
    return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }], structuredContent: output };
});
function normalizeHashtag(t) {
    const cleaned = t.trim().replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "");
    return cleaned.startsWith("#") ? cleaned : `#${cleaned.toLowerCase()}`;
}
function sanitizeUrl(u) {
    return (u || "").replace(/^[\s`]+|[\s`]+$/g, "");
}
function extractHashtags(text) {
    const lower = text.toLowerCase();
    const tokens = lower.split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean);
    const stop = new Set(["de", "la", "el", "en", "y", "para", "por", "con", "del", "las", "los", "un", "una", "al", "que", "se"]);
    const words = tokens.filter(t => !stop.has(t) && t.length > 2);
    const unique = Array.from(new Set(words));
    return unique.slice(0, 15).map(w => normalizeHashtag(w));
}
function mockImages(seed) {
    const base = Math.abs(hashCode(seed));
    const arr = [];
    for (let i = 0; i < 5; i++) {
        const s = base + i;
        arr.push({ url: `https://picsum.photos/seed/${s}/800/600`, alt: `image-${s}` });
    }
    return arr;
}
function hashCode(str) {
    let h = 0;
    for (let i = 0; i < str.length; i++)
        h = (h << 5) - h + str.charCodeAt(i);
    return h | 0;
}
async function semanticSearch(query) {
    try {
        const pc = getPinecone();
        const index = pc.index(process.env.PINECONE_INDEX || "promptcontent");
        let vector;
        try {
            const { OpenAI } = await import("openai");
            const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
            const emb = await openai.embeddings.create({ model: "text-embedding-3-small", input: query });
            vector = emb.data[0].embedding;
        }
        catch {
            function pseudoEmbedding(text, dim = 1536) {
                let h = 2166136261;
                for (let i = 0; i < text.length; i++)
                    h = (h ^ text.charCodeAt(i)) * 16777619;
                const out = new Array(dim);
                let x = h >>> 0;
                for (let i = 0; i < dim; i++) {
                    x ^= x << 13;
                    x ^= x >>> 17;
                    x ^= x << 5;
                    out[i] = (x % 1000) / 1000;
                }
                return out;
            }
            vector = pseudoEmbedding(query);
        }
        const res = await index.query({ vector, topK: 5, includeMetadata: true });
        return (res.matches || []).map(m => ({
            url: m.metadata.url,
            alt: m.metadata.alt,
            tags: m.metadata.tags || [],
            score: typeof m.score === "number" ? m.score : undefined
        }));
    }
    catch {
        return mockImages(query);
    }
}
async function main() {
    const transport = new stdio_js_1.StdioServerTransport();
    await server.connect(transport);
}
main();
const port = Number(process.env.PORT || 8080);
if (process.env.PROMPTCONTENT_NO_LISTEN !== "1") {
    const srv = http_1.default.createServer((req, res) => {
        if (req.url === "/readyz") {
            res.writeHead(200, { "Content-Type": "text/plain" });
            res.end("ok");
            return;
        }
        if (req.url === "/healthz") {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ status: "ok" }));
            return;
        }
        res.writeHead(404);
        res.end();
    });
    srv.listen(port);
}
