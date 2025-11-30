import { MongoClient } from "mongodb"
import { getPinecone, ensureIndex } from "../src/pinecone-util"
import { generateEmbedding as sharedGenerateEmbedding } from "../src/embeddings"
import dotenv from "dotenv"

dotenv.config()

const INIT_ONLY = process.argv.includes("--init-only")
const MONGO_URI = process.env.MONGODB_URI
const MONGO_DB = process.env.MONGODB_DB
const PINECONE_API_KEY = process.env.PINECONE_API_KEY
const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX
const OPENAI_API_KEY = process.env.OPENAI_API_KEY
const EMBED_MAX_AGE_DAYS_RAW = process.env.EMBED_MAX_AGE_DAYS
const EMBED_LIMIT_RAW = process.env.EMBED_LIMIT
const EMBED_DIM_RAW = process.env.EMBED_DIM
const PINECONE_CLOUD = process.env.PINECONE_CLOUD
const PINECONE_REGION = process.env.PINECONE_REGION
const PINECONE_NAMESPACE = process.env.PINECONE_NAMESPACE || "default"

if (INIT_ONLY) {
  if (!PINECONE_API_KEY || !PINECONE_INDEX_NAME || !EMBED_DIM_RAW || !PINECONE_CLOUD || !PINECONE_REGION) {
    console.error("ENV_MISSING_INIT")
    process.exit(1)
  }
} else {
  if (!MONGO_URI || !MONGO_DB || !PINECONE_API_KEY || !PINECONE_INDEX_NAME || !OPENAI_API_KEY || !EMBED_MAX_AGE_DAYS_RAW || !EMBED_LIMIT_RAW || !EMBED_DIM_RAW || !PINECONE_CLOUD || !PINECONE_REGION) {
    console.error("ENV_MISSING")
    process.exit(1)
  }
}
const EMBED_DIM = Number(EMBED_DIM_RAW)
let EMBED_MAX_AGE_DAYS = 0
let EMBED_LIMIT = 0
if (!INIT_ONLY) {
  EMBED_MAX_AGE_DAYS = Number(EMBED_MAX_AGE_DAYS_RAW)
  EMBED_LIMIT = Number(EMBED_LIMIT_RAW)
}

const pc = getPinecone()

async function initIndex() {
  await ensureIndex(PINECONE_INDEX_NAME!, EMBED_DIM, PINECONE_CLOUD!, PINECONE_REGION!)
}


async function generateEmbedding(text: string): Promise<number[]> {
  console.log("[embedAndUpsert] embed", { inputLen: text?.length })
  return await sharedGenerateEmbedding(text)
}

async function main() {
  await initIndex()
  if (INIT_ONLY) {
    console.log("✅ Índice verificado/creado")
    return
  }
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
        const text = String(doc.alt || '')
        const values = await generateEmbedding(text)
        vectors.push({ id: doc._id.toString(), values })
      } catch {}
    }
    if (vectors.length) {
      console.log("[embedAndUpsert] upsert", { count: vectors.length, namespace: PINECONE_NAMESPACE })
      await index.upsert(vectors, { namespace: PINECONE_NAMESPACE })
    }
    const ids = vectors.map(v => (v.id as any))
    if (ids.length) {
      await images.updateMany({ _id: { $in: ids as any } }, { $set: { lastEmbeddedAt: new Date() } })
    }
    console.log(`Upsertados ${i + batch.length} (ns=${PINECONE_NAMESPACE})`)
  }

  await mongo.close()
  console.log("✅ Embeddings y upsert completados")
}

main().catch(console.error)
