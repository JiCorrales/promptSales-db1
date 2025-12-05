import { Pinecone } from "@pinecone-database/pinecone"

let pineconeClient: Pinecone | null = null

export function getPinecone() {
    if (!pineconeClient) {
        const key = process.env.PINECONE_API_KEY
        if (!key) throw new Error("PINECONE_API_KEY_MISSING")
        pineconeClient = new Pinecone({ apiKey: key })
    }
    return pineconeClient
}

export async function ensureIndex(name: string, dim: number, cloud: string, region: string) {
    const pc = getPinecone()
    const indexes = await pc.listIndexes()
    const exists = indexes.indexes?.some(idx => idx.name === name)
    if (!exists) {
        await pc.createIndex({ name, dimension: dim, metric: "cosine", spec: { serverless: { cloud: cloud as any, region } } })
    }
}
