"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongodb_1 = require("mongodb");
const pinecone_1 = require("@pinecone-database/pinecone");
const openai_1 = require("openai");
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const MONGO_URI = process.env.MONGODB_URI || "mongodb://127.0.0.1:27017";
const MONGO_DB = process.env.MONGODB_DB || "promptcontent";
const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX || "promptcontent";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const EMBED_MAX_AGE_DAYS = Number(process.env.EMBED_MAX_AGE_DAYS || 30);
if (!PINECONE_API_KEY || !OPENAI_API_KEY) {
    console.error("Faltan PINECONE_API_KEY o OPENAI_API_KEY en .env");
    process.exit(1);
}
const openai = new openai_1.OpenAI({ apiKey: OPENAI_API_KEY });
const pc = new pinecone_1.Pinecone({ apiKey: PINECONE_API_KEY });
async function ensureIndex() {
    const indexes = await pc.listIndexes();
    const exists = indexes.indexes?.some(idx => idx.name === PINECONE_INDEX_NAME);
    if (!exists) {
        console.log("Creando índice Pinecone...");
        await pc.createIndex({
            name: PINECONE_INDEX_NAME,
            dimension: 1536,
            metric: "cosine",
            spec: { serverless: { cloud: "aws", region: "us-east-1" } }
        });
        console.log("Índice creado.");
    }
}
async function generateEmbedding(text) {
    const resp = await openai.embeddings.create({ model: "text-embedding-3-small", input: text });
    return resp.data[0].embedding;
}
async function main() {
    await ensureIndex();
    const index = pc.index(PINECONE_INDEX_NAME);
    const mongo = new mongodb_1.MongoClient(MONGO_URI);
    await mongo.connect();
    const db = mongo.db(MONGO_DB);
    const images = db.collection("images");
    const cutoff = new Date(Date.now() - EMBED_MAX_AGE_DAYS * 24 * 60 * 60 * 1000);
    const docs = await images.find({ $or: [{ lastEmbeddedAt: { $exists: false } }, { lastEmbeddedAt: { $lt: cutoff } }] }).toArray();
    console.log(`Procesando ${docs.length} documentos...`);
    const batchSize = 100;
    for (let i = 0; i < docs.length; i += batchSize) {
        const batch = docs.slice(i, i + batchSize);
        const vectors = await Promise.all(batch.map(async (doc) => ({
            id: doc._id.toString(),
            values: await generateEmbedding(doc.alt),
            metadata: { url: doc.url, title: doc.title, tags: doc.tags, alt: doc.alt }
        })));
        await index.upsert(vectors);
        const ids = batch.map(d => d._id);
        await images.updateMany({ _id: { $in: ids } }, { $set: { lastEmbeddedAt: new Date() } });
        console.log(`Upsertados ${i + batch.length}`);
    }
    await mongo.close();
    console.log("✅ Embeddings y upsert completados");
}
main().catch(console.error);
