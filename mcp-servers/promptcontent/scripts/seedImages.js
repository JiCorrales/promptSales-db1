"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const mongodb_1 = require("mongodb");
const crypto_1 = require("crypto");
const URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017";
const DB = process.env.MONGODB_DB || "promptcontent";
const THEMES = [
    "verano", "playa", "atardecer", "tropical", "montaña", "bosque", "ciudad", "nocturno", "aurora", "desierto",
    "oceano", "cascada", "arquitectura", "minimalista", "vintage", "futurista", "abstracto", "macro", "retrato", "neon",
    "deporte", "fitness", "salud", "comida", "café", "helado", "pizza", "ensalada", "fruta", "panadería",
    "tecnología", "startup", "oficina", "remoto", "cowork", "ordenador", "smartphone", "drone", "impresora", "código",
    "moda", "ropa", "accesorios", "zapatos", "bolso", "gafas", "reloj", "joyería", "tendencia", "estilo",
    "viaje", "avión", "tren", "hotel", "mochila", "mapa", "pasaporte", "maleta", "playa", "montaña",
    "arte", "pintura", "escultura", "galería", "museo", "paleta", "pincel", "lienzo", "color", "textura",
    "música", "concierto", "guitarra", "piano", "auriculares", "vinilo", "festival", "bailar", "ritmo", "melodía",
    "naturaleza", "flor", "hoja", "río", "lago", "nube", "cielo", "estrella", "luna", "sol",
    "negocio", "emprendimiento", "marketing", "ventas", "cliente", "reunión", "presentación", "gráfico", "estrategia", "crecimiento"
];
function randomPick(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}
function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}
function generateDescription(theme) {
    const adj = ["impresionante", "vibrante", "serena", "dinámica", "minimalista", "detallada", "colorida", "nostálgica", "futurista", "orgánica"];
    const contexts = {
        playa: ["al amanecer", "al atardecer", "con olas suaves", "con palmeras", "con barcos", "con silencio absoluto"],
        montaña: ["con nieve en la cima", "con niebla matutina", "con senderos", "con flora autóctona", "con luz dorada", "con neblina"],
        ciudad: ["desde un rascacielos", "con luces de neón", "con tráfico nocturno", "con arquitectura moderna", "con calles empedradas", "con rascacielos"],
        comida: ["recién preparada", "con ingredientes frescos", "con texturas crujientes", "con colores vibrantes", "con presentación elegante", "con aroma tentador"],
        tecnología: ["en un ambiente moderno", "con iluminación LED", "con diseño minimalista", "con pantallas táctiles", "con cables ordenados", "con estética futurista"],
        moda: ["en un estudio profesional", "con iluminación natural", "con fondo neutro", "con texturas suaves", "con accesorios elegantes", "con estilo urbano"],
        arte: ["con pinceladas expresivas", "con colores contrastantes", "con texturas visibles", "con detalles intrincados", "con movimiento capturado", "con emociones intensas"],
        música: ["en un escenario íntimo", "con luces de colores", "con público entusiasta", "con instrumentos brillantes", "con energía vibrante", "con ambiente acogedor"]
    };
    const context = contexts[theme] || ["en un entorno natural", "con iluminación perfecta", "con colores armoniosos", "con detalles nítidos", "con fondo suave", "con ambiente relajado"];
    const desc = `${randomPick(adj)} imagen de ${theme} ${randomPick(context)}. Captura la esencia del momento con colores auténticos y composición equilibrada. Ideal para campañas de marketing que buscan transmitir ${randomPick(["emociones positivas", "conexión con la naturaleza", "modernidad", "elegancia", "autenticidad", "innovación"])}.`;
    return desc.length >= 150 ? desc : desc + ` La escena transmite una sensación de ${randomPick(["armonía", "energía", "tranquilidad", "creatividad", "profesionalismo"])} que conecta con el público objetivo.`;
}
function generateTags(theme) {
    const base = [theme];
    const extras = {
        playa: ["mar", "arena", "sol", "vacaciones", "relax", "tropical", "océano", "costa"],
        montaña: ["naturaleza", "senderismo", "aventura", "paisaje", "alto", "verde", "bosque", "aire libre"],
        ciudad: ["urbano", "edificios", "arquitectura", "moderno", "centro", "metrópoli", "rascacielos", "calles"],
        comida: ["delicioso", "saludable", "fresco", "gourmet", "cocina", "nutritivo", "sabroso", "plato"],
        tecnología: ["digital", "innovación", "moderno", "dispositivo", "pantalla", "conectividad", "inteligente", "futuro"],
        moda: ["estilo", "tendencia", "elegante", "diseño", "textil", "prenda", "accesorio", "look"],
        arte: ["creatividad", "expresión", "artístico", "obra", "visual", "estética", "cultura", "galería"],
        música: ["ritmo", "melodía", "instrumento", "concierto", "sonido", "armonía", "vibración", "audiencia"]
    }[theme] || ["belleza", "inspiración", "creatividad", "profesional", "calidad", "original"];
    return [...base, ...extras.slice(0, 4)];
}
async function seed() {
    const client = new mongodb_1.MongoClient(URI);
    await client.connect();
    const db = client.db(DB);
    const images = db.collection("images");
    const hashtags = db.collection("hashtags");
    console.log("Limpiando colecciones...");
    await images.deleteMany({});
    await hashtags.deleteMany({});
    console.log("Creando índices...");
    try {
        await images.createIndex({ title: "text", alt: "text", tags: "text" });
    }
    catch { }
    try {
        await hashtags.createIndex({ tag: 1 }, { unique: true, collation: { locale: "en", strength: 2 } });
    }
    catch { }
    console.log("Generando imágenes...");
    const docs = [];
    for (let i = 0; i < 100; i++) {
        const theme = randomPick(THEMES);
        const tags = generateTags(theme);
        const desc = generateDescription(theme);
        const url = `https://picsum.photos/seed/${(0, crypto_1.randomUUID)()}/800/600`;
        docs.push({
            url,
            title: `${theme} ${randomPick(["vista", "perspectiva", "escena", "vista panorámica", "detalle", "composición"])}`,
            alt: desc.slice(0, 200),
            tags,
            score: randomInt(70, 99),
            createdAt: new Date()
        });
    }
    await images.insertMany(docs).catch(() => { });
    console.log("Generando hashtags...");
    const allTags = new Set();
    docs.forEach(d => d.tags.forEach((t) => allTags.add(t)));
    const tagDocs = Array.from(allTags).map(tag => ({
        tag,
        popularity: randomInt(1, 100),
        aliases: [],
        createdAt: new Date()
    }));
    await hashtags.insertMany(tagDocs, { ordered: false }).catch(() => { });
    console.log("✅ Seed completado");
    await client.close();
}
seed().catch(console.error);
