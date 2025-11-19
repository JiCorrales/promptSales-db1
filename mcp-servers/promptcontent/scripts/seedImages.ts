// Script de seed para PromptContent: genera imágenes con descripciones y hashtags
import { MongoClient } from "mongodb"
import { randomUUID } from "crypto"
import fs from "fs"
import path from "path"
import { OpenAI } from "openai"
import dotenv from "dotenv"
dotenv.config()

// Configuración de conexión y parámetros
const URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017"
const DB = process.env.MONGODB_DB || "promptcontent"
const SEED_COUNT = Number(process.env.SEED_COUNT || 100)
// Lista de frases separadas por | para generar imágenes dirigidas
let PHRASES_CSV = process.env.PHRASES_CSV || ""

// Catálogo de temas para variedad de contenido
const THEMES = [
  "summer", "beach", "sunset", "tropical", "mountain", "forest", "city", "night", "aurora", "desert",
  "ocean", "waterfall", "architecture", "minimalist", "vintage", "futuristic", "abstract", "macro", "portrait", "neon",
  "sport", "fitness", "health", "food", "coffee", "icecream", "pizza", "salad", "fruit", "bakery",
  "technology", "startup", "office", "remote", "cowork", "computer", "smartphone", "drone", "printer", "code",
  "fashion", "clothing", "accessories", "shoes", "bag", "glasses", "watch", "jewelry", "trend", "style",
  "travel", "airplane", "train", "hotel", "backpack", "map", "passport", "luggage", "beach", "mountain",
  "art", "painting", "sculpture", "gallery", "museum", "palette", "brush", "canvas", "color", "texture",
  "music", "concert", "guitar", "piano", "headphones", "vinyl", "festival", "dance", "rhythm", "melody",
  "nature", "flower", "leaf", "river", "lake", "cloud", "sky", "star", "moon", "sun",
  "business", "entrepreneurship", "marketing", "sales", "customer", "meeting", "presentation", "chart", "strategy", "growth"
]

// Selecciona un elemento aleatorio del arreglo
function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]
}

function randomSample<T>(arr: T[], k: number): T[] {
  const out: T[] = []
  const used = new Set<number>()
  const n = Math.min(k, arr.length)
  while (out.length < n) {
    const i = Math.floor(Math.random() * arr.length)
    if (!used.has(i)) {
      used.add(i)
      out.push(arr[i])
    }
  }
  return out
}

// Entero aleatorio en rango [min, max]
function randomInt(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min
}

// Construye una descripción amplia y coherente según el tema
function generateDescription(theme: string): string {
  const adj = ["stunning", "vibrant", "serene", "dynamic", "minimal", "detailed", "colorful", "nostalgic", "futuristic", "organic"]
  const contexts: Record<string, string[]> = {
    beach: ["at sunrise", "at sunset", "with gentle waves", "with palm trees", "with boats", "in absolute calm"],
    mountain: ["with snow at the peak", "with morning fog", "with trails", "with native flora", "with golden light", "with mist"],
    city: ["from a skyscraper", "with neon lights", "with night traffic", "with modern architecture", "with cobblestone streets", "with skyline"],
    food: ["freshly prepared", "with fresh ingredients", "with crunchy textures", "with vibrant colors", "with elegant plating", "with tempting aroma"],
    technology: ["in a modern setup", "with LED lighting", "with minimalist design", "with touchscreens", "with tidy cables", "with futuristic aesthetics"],
    fashion: ["in a professional studio", "with natural light", "with neutral background", "with soft textures", "with elegant accessories", "with urban style"],
    art: ["with expressive brushstrokes", "with contrasting colors", "with visible textures", "with intricate details", "with captured motion", "with intense emotions"],
    music: ["on an intimate stage", "with colorful lights", "with enthusiastic audience", "with shiny instruments", "with vibrant energy", "with cozy atmosphere"]
  }
  const context = contexts[theme] || ["in a natural environment", "with perfect lighting", "with harmonious colors", "with sharp details", "with soft background", "with a relaxed mood"]
  const desc = `${randomPick(adj)} ${theme} image ${randomPick(context)}. Captures the essence of the moment with authentic colors and balanced composition. Ideal for marketing campaigns that aim to convey ${randomPick(["positive emotions", "connection with nature", "modernity", "elegance", "authenticity", "innovation"])}.`
  return desc.length >= 150 ? desc : desc + ` The scene delivers a sense of ${randomPick(["harmony", "energy", "calm", "creativity", "professionalism"])} that resonates with the target audience.`
}

// Genera hashtags base y relacionados para el tema
function generateTags(theme: string): string[] {
  const base = [theme]
  const extras = {
    beach: ["sea", "sand", "sun", "vacation", "relax", "tropical", "ocean", "coast"],
    mountain: ["nature", "hiking", "adventure", "landscape", "high", "green", "forest", "outdoor"],
    city: ["urban", "buildings", "architecture", "modern", "downtown", "metropolis", "skyscraper", "streets"],
    food: ["delicious", "healthy", "fresh", "gourmet", "kitchen", "nutritious", "tasty", "dish"],
    technology: ["digital", "innovation", "modern", "device", "screen", "connectivity", "smart", "future"],
    fashion: ["style", "trend", "elegant", "design", "textile", "garment", "accessory", "look"],
    art: ["creativity", "expression", "artistic", "work", "visual", "aesthetic", "culture", "gallery"],
    music: ["rhythm", "melody", "instrument", "concert", "sound", "harmony", "vibration", "audience"]
  }[theme] || ["beauty", "inspiration", "creativity", "professional", "quality", "original"]
  return [...base, ...randomSample(extras, 4)]
}

async function seed() {
  const envTranslation = await ensureEnvPhrasesEnglish()
  // Conexión a MongoDB y selección de colecciones
  const client = new MongoClient(URI)
  await client.connect()
  const db = client.db(DB)
  if (envTranslation) {
    try {
      await db.collection("AIRequests").insertOne({
        aiRequestId: `env_translation_${Date.now()}`,
        createdAt: new Date(),
        completedAt: new Date(),
        status: "completed",
        type: "env-translation",
        prompt: envTranslation.original,
        output: envTranslation.translated
      })
    } catch {}
  }
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
    const qTokens = [tags[0], ...randomSample(tags.slice(1), 2)]
    const q = encodeURIComponent(qTokens.join(","))
    const url = `https://loremflickr.com/800/600/${q}?random=${i}`
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
  const q2Tokens = [tags[0], ...randomSample(tags.slice(1), 2)]
  const q2 = encodeURIComponent(q2Tokens.join(","))
  const url = `https://loremflickr.com/800/600/${q2}?random=${i}`
  docs.push({
    url,
    title: `${theme} ${randomPick(["view", "perspective", "scene", "panorama", "detail", "composition"])}`,
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
  const toks = p.toLowerCase().split(/[^a-z0-9]+/i).filter(Boolean)
  const stop = new Set(["the","a","an","and","or","to","for","with","of","in","on","by","at","is","are"])
  return Array.from(new Set(toks.filter(t => !stop.has(t) && t.length > 2)))
}

// Deriva hashtags desde tokens, garantizando al menos 3
function tagsFromPhrase(p: string): string[] {
  const toks = tokensFromPhrase(p)
  const pick = toks.slice(0, 5)
  return pick.length >= 3 ? pick : [...pick, ...["inspiration","visual","marketing"].slice(0, 3 - pick.length)]
}

// Construye descripción larga basada en la frase
function descriptionFromPhrase(p: string): string {
  const base = `Image inspired by "${p}" with balanced composition and details that reinforce the main message. `
  const extra = `Colors and textures are selected to maximize relevance and connect emotionally with the target audience, integrating clear context and natural language. Ideal for campaigns that aim to convey authenticity and clarity.`
  const desc = base + extra
  return desc.length >= 150 ? desc : (desc + " " + extra)
}
function isSpanishText(t: string) {
  return /[áéíóúñ]/i.test(t) || /(\bde\b|\bla\b|\bel\b|\ben\b|\by\b|\bpara\b|\bpor\b|\bcon\b|\bdel\b|\blas\b|\blos\b|\bun\b|\buna\b|\bal\b|\bque\b|\bse\b)/i.test(t)
}

async function translateCsvToEnglish(csv: string) {
  try {
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
    const resp = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "Translate each segment separated by '|' to English. Return a single line preserving the '|' separators and order. Do not add extra text." },
        { role: "user", content: csv }
      ]
    })
    const out = resp.choices?.[0]?.message?.content?.trim() || ""
    return out
  } catch {
    return csv
  }
}

async function ensureEnvPhrasesEnglish() {
  if (!PHRASES_CSV) return
  if (!isSpanishText(PHRASES_CSV)) return
  const translated = await translateCsvToEnglish(PHRASES_CSV)
  PHRASES_CSV = translated
  try {
    const envPath = path.resolve(__dirname, "..", ".env")
    const text = fs.readFileSync(envPath, "utf8")
    const updated = text.replace(/(^|[\r\n])PHRASES_CSV=.*?(?=[\r\n]|$)/s, `$1PHRASES_CSV=${translated}`)
    fs.writeFileSync(envPath, updated, "utf8")
    console.log("Actualizado .env con PHRASES_CSV en inglés")
  } catch {}
}
