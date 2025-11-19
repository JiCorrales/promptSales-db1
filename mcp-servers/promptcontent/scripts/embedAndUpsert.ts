import { MongoClient } from "mongodb"
import { Pinecone } from "@pinecone-database/pinecone"
import { OpenAI } from "openai"
import dotenv from "dotenv"

dotenv.config()

const MONGO_URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017"
const MONGO_DB = process.env.MONGODB_DB || "promptContent"
const PINECONE_API_KEY = process.env.PINECONE_API_KEY!
const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX || "promptcontent"
const OPENAI_API_KEY = process.env.OPENAI_API_KEY!
const EMBED_MAX_AGE_DAYS = Number(process.env.EMBED_MAX_AGE_DAYS || 30)
const EMBED_LIMIT = Number(process.env.EMBED_LIMIT || 100)

if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
  console.error("Faltan PINECONE_API_KEY o OPENAI_API_KEY en .env")
  process.exit(1)
}

const openai = new OpenAI({ apiKey: OPENAI_API_KEY })
const pc = new Pinecone({ apiKey: PINECONE_API_KEY })

async function ensureIndex() {
  const indexes = await pc.listIndexes()
  const exists = indexes.indexes?.some(idx => idx.name === PINECONE_INDEX_NAME)
  if (!exists) {
    console.log("Creando índice Pinecone...")
    await pc.createIndex({
      name: PINECONE_INDEX_NAME,
      dimension: 1536,
      metric: "cosine",
      spec: { serverless: { cloud: "aws", region: "us-east-1" } }
    })
    console.log("Índice creado.")
  }
}

function pseudoEmbedding(text: string, dim = 1536): number[] {
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

async function generateEmbedding(text: string): Promise<number[]> {
  try {
    const resp = await openai.embeddings.create({ model: "text-embedding-3-small", input: text })
    return resp.data[0].embedding
  } catch {
    return pseudoEmbedding(text)
  }
}

async function main() {
  await ensureIndex()
  const index = pc.index(PINECONE_INDEX_NAME)

  const mongo = new MongoClient(MONGO_URI)
  await mongo.connect()
  const db = mongo.db(MONGO_DB)
  const images = db.collection("images")

  const cutoff = new Date(Date.now() - EMBED_MAX_AGE_DAYS * 24 * 60 * 60 * 1000)
  const docsAll = await images.find({ $or: [{ lastEmbeddedAt: { $exists: false } }, { lastEmbeddedAt: { $lt: cutoff } }] }).toArray()
  const docs = docsAll.slice(0, EMBED_LIMIT)
  console.log(`Procesando ${docs.length} documentos...`)

  const batchSize = Math.min(25, Math.max(5, EMBED_LIMIT))
  for (let i = 0; i < docs.length; i += batchSize) {
    const batch = docs.slice(i, i + batchSize)
    const vectors: { id: string; values: number[]; metadata: any }[] = []
    for (const doc of batch) {
      try {
        const text = `${doc.alt || ''} ${doc.title || ''} tags: ${(doc.tags || []).join(', ')}`.trim()
        const values = await generateEmbedding(text)
        vectors.push({ id: doc._id.toString(), values, metadata: { url: doc.url, title: doc.title, tags: doc.tags, alt: doc.alt } })
      } catch {}
    }
    if (vectors.length) {
      await index.upsert(vectors)
    }
    const ids = vectors.map(v => (v.id as any))
    if (ids.length) {
      await images.updateMany({ _id: { $in: ids as any } }, { $set: { lastEmbeddedAt: new Date() } })
    }
    console.log(`Upsertados ${i + batch.length}`)
  }

  await mongo.close()
  console.log("✅ Embeddings y upsert completados")
}

main().catch(console.error)
