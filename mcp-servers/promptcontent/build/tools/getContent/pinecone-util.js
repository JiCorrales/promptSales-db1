"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPinecone = getPinecone;
exports.ensureIndex = ensureIndex;
const pinecone_1 = require("@pinecone-database/pinecone");
let pineconeClient = null;
function getPinecone() {
    if (!pineconeClient) {
        const key = process.env.PINECONE_API_KEY;
        if (!key)
            throw new Error("PINECONE_API_KEY_MISSING");
        pineconeClient = new pinecone_1.Pinecone({ apiKey: key });
    }
    return pineconeClient;
}
async function ensureIndex(name, dim, cloud, region) {
    const pc = getPinecone();
    const indexes = await pc.listIndexes();
    const exists = indexes.indexes?.some(idx => idx.name === name);
    if (!exists) {
        await pc.createIndex({ name, dimension: dim, metric: "cosine", spec: { serverless: { cloud: cloud, region } } });
    }
}
