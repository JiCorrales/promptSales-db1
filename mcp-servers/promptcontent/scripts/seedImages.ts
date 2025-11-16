// Script de seed para PromptContent: genera imágenes con descripciones y hashtags
import { MongoClient } from "mongodb"
import { randomUUID } from "crypto"
import dotenv from "dotenv"
dotenv.config()

// Configuración de conexión y parámetros
const URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017"
const DB = process.env.MONGODB_DB || "promptcontent"
const SEED_COUNT = Number(process.env.SEED_COUNT || 100)
// Lista de frases separadas por | para generar imágenes dirigidas
const PHRASES_CSV = process.env.PHRASES_CSV || ""

// Catálogo de temas para variedad de contenido
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
]

// Selecciona un elemento aleatorio del arreglo
function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]
}

// Entero aleatorio en rango [min, max]
function randomInt(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min
}

// Construye una descripción amplia y coherente según el tema
function generateDescription(theme: string): string {
  const adj = ["impresionante", "vibrante", "serena", "dinámica", "minimalista", "detallada", "colorida", "nostálgica", "futurista", "orgánica"]
  const contexts: Record<string, string[]> = {
    playa: ["al amanecer", "al atardecer", "con olas suaves", "con palmeras", "con barcos", "con silencio absoluto"],
    montaña: ["con nieve en la cima", "con niebla matutina", "con senderos", "con flora autóctona", "con luz dorada", "con neblina"],
    ciudad: ["desde un rascacielos", "con luces de neón", "con tráfico nocturno", "con arquitectura moderna", "con calles empedradas", "con rascacielos"],
    comida: ["recién preparada", "con ingredientes frescos", "con texturas crujientes", "con colores vibrantes", "con presentación elegante", "con aroma tentador"],
    tecnología: ["en un ambiente moderno", "con iluminación LED", "con diseño minimalista", "con pantallas táctiles", "con cables ordenados", "con estética futurista"],
    moda: ["en un estudio profesional", "con iluminación natural", "con fondo neutro", "con texturas suaves", "con accesorios elegantes", "con estilo urbano"],
    arte: ["con pinceladas expresivas", "con colores contrastantes", "con texturas visibles", "con detalles intrincados", "con movimiento capturado", "con emociones intensas"],
    música: ["en un escenario íntimo", "con luces de colores", "con público entusiasta", "con instrumentos brillantes", "con energía vibrante", "con ambiente acogedor"]
  }
  const context = contexts[theme] || ["en un entorno natural", "con iluminación perfecta", "con colores armoniosos", "con detalles nítidos", "con fondo suave", "con ambiente relajado"]
  const desc = `${randomPick(adj)} imagen de ${theme} ${randomPick(context)}. Captura la esencia del momento con colores auténticos y composición equilibrada. Ideal para campañas de marketing que buscan transmitir ${randomPick(["emociones positivas", "conexión con la naturaleza", "modernidad", "elegancia", "autenticidad", "innovación"])}.`
  return desc.length >= 150 ? desc : desc + ` La escena transmite una sensación de ${randomPick(["armonía", "energía", "tranquilidad", "creatividad", "profesionalismo"])} que conecta con el público objetivo.`
}

// Genera hashtags base y relacionados para el tema
function generateTags(theme: string): string[] {
  const base = [theme]
  const extras = {
    playa: ["mar", "arena", "sol", "vacaciones", "relax", "tropical", "océano", "costa"],
    montaña: ["naturaleza", "senderismo", "aventura", "paisaje", "alto", "verde", "bosque", "aire libre"],
    ciudad: ["urbano", "edificios", "arquitectura", "moderno", "centro", "metrópoli", "rascacielos", "calles"],
    comida: ["delicioso", "saludable", "fresco", "gourmet", "cocina", "nutritivo", "sabroso", "plato"],
    tecnología: ["digital", "innovación", "moderno", "dispositivo", "pantalla", "conectividad", "inteligente", "futuro"],
    moda: ["estilo", "tendencia", "elegante", "diseño", "textil", "prenda", "accesorio", "look"],
    arte: ["creatividad", "expresión", "artístico", "obra", "visual", "estética", "cultura", "galería"],
    música: ["ritmo", "melodía", "instrumento", "concierto", "sonido", "armonía", "vibración", "audiencia"]
  }[theme] || ["belleza", "inspiración", "creatividad", "profesional", "calidad", "original"]
  return [...base, ...extras.slice(0, 4)]
}

async function seed() {
  // Conexión a MongoDB y selección de colecciones
  const client = new MongoClient(URI)
  await client.connect()
  const db = client.db(DB)
  const images = db.collection("images") // 
  const hashtags = db.collection("hashtags")

  // Limpia datos previos para evitar duplicados
  console.log("Limpiando colecciones...")
  await images.deleteMany({})
  await hashtags.deleteMany({})

  // Índices para búsqueda por texto y unicidad de hashtags
  console.log("Creando índices...")
  try {
    await images.createIndex({ title: "text", alt: "text", tags: "text" })
  } catch {}
  try {
    await hashtags.createIndex({ tag: 1 }, { unique: true, collation: { locale: "en", strength: 2 } })
  } catch {}

  // Construcción de documentos de imagen
  console.log("Generando imágenes...")
  const docs = [] as any[]
// Si se proveen frases, generar imágenes derivadas de cada frase
const phrases = PHRASES_CSV ? PHRASES_CSV.split(/\s*\|\s*/).filter(Boolean) : []
if (phrases.length > 0) {
  for (let i = 0; i < phrases.length; i++) {
    const p = phrases[i]
    const tags = tagsFromPhrase(p)
    const desc = descriptionFromPhrase(p)
    const seed = Math.abs(hashCode(p + ":" + i))
    const url = `https://picsum.photos/seed/${seed}/800/600`
    docs.push({
      url,
      title: p.slice(0, 120),
      alt: desc.slice(0, 200),
      tags,
      score: randomInt(70, 99),
      createdAt: new Date()
    })
  }
}
  // Completa hasta SEED_COUNT con temas aleatorios
const remaining = Math.max(SEED_COUNT - docs.length, 0)
for (let i = 0; i < remaining; i++) {
  const theme = randomPick(THEMES)
  const tags = generateTags(theme)
  const desc = generateDescription(theme)
  const url = `https://picsum.photos/seed/${randomUUID()}/800/600`
  docs.push({
    url,
    title: `${theme} ${randomPick(["vista", "perspectiva", "escena", "vista panorámica", "detalle", "composición"])}`,
    alt: desc.slice(0, 200),
    tags,
    score: randomInt(70, 99),
    createdAt: new Date()
  })
}
// Inserción masiva de imágenes
await images.insertMany(docs).catch(() => {})

  console.log("Generando hashtags...")
// Catálogo de hashtags único con popularidad simulada
const allTags = new Set<string>()
docs.forEach(d => d.tags.forEach((t: string) => allTags.add(t)))
const tagDocs = Array.from(allTags).map(tag => ({
  tag,
  popularity: randomInt(1, 100),
  aliases: [],
  createdAt: new Date()
}))
await hashtags.insertMany(tagDocs, { ordered: false }).catch(() => {})

console.log("✅ Seed completado")
// Cierre de conexión
await client.close()
}

// Ejecutar seed y capturar errores
seed().catch(console.error)
// Hash simple para generar seeds determinísticos desde frases
function hashCode(str: string) {
  let h = 0
  for (let i = 0; i < str.length; i++) h = (h << 5) - h + str.charCodeAt(i)
  return h | 0
}

// Tokeniza y limpia la frase, removiendo stopwords
function tokensFromPhrase(p: string): string[] {
  const toks = p.toLowerCase().split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean)
  const stop = new Set(["de","la","el","en","y","para","por","con","del","las","los","un","una","al","que","se"])
  return Array.from(new Set(toks.filter(t => !stop.has(t) && t.length > 2)))
}

// Deriva hashtags desde tokens, garantizando al menos 3
function tagsFromPhrase(p: string): string[] {
  const toks = tokensFromPhrase(p)
  const pick = toks.slice(0, 5)
  return pick.length >= 3 ? pick : [...pick, ...["inspiración","visual","marketing"].slice(0, 3 - pick.length)]
}

// Construye descripción larga basada en la frase
function descriptionFromPhrase(p: string): string {
  const base = `Imagen inspirada en "${p}" con composición equilibrada y detalles que refuerzan el mensaje principal. `
  const extra = `Colores y texturas se seleccionan para maximizar la relevancia y conectar emocionalmente con el público objetivo, integrando contexto claro y lenguaje natural. Ideal para campañas que buscan transmitir autenticidad y claridad.`
  const desc = base + extra
  return desc.length >= 150 ? desc : (desc + " " + extra)
}
