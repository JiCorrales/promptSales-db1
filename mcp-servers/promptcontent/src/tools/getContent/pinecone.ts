import { getPinecone } from "./pinecone-util"
import { generateEmbedding } from "./embeddings"

export async function semanticSearch(query: string) {
    try {
        const pineconeClient = getPinecone()
        const indexName = process.env.PINECONE_INDEX
        const embeddingDimensionRaw = process.env.EMBED_DIM
        const namespace = process.env.PINECONE_NAMESPACE || ""

        if (!indexName || !embeddingDimensionRaw) throw new Error("PINECONE_ENV_MISSING")
        console.log("[semanticSearch] start", { indexName, namespace })

        const index = pineconeClient.index(indexName).namespace(namespace)
        const embeddingDimension = Number(embeddingDimensionRaw)
        const queryVector = await generateEmbedding(query)
        console.log("[semanticSearch] vector", { len: queryVector.length })
        if (queryVector.length !== embeddingDimension) throw new Error("EMBED_DIM_MISMATCH")
        const searchQuery: any = { vector: queryVector, topK: 5, includeMetadata: true }
        const searchResponse = await index.query(searchQuery)
        console.log("[semanticSearch] matches", { count: (searchResponse.matches || []).length, sample: searchResponse.matches?.[0]?.id })
        return (searchResponse.matches || []).map(match => ({
            id: (match as any).id,
            score: typeof (match as any).score === "number" ? (match as any).score : undefined
        }))
    } catch (error) {
        console.error("[semanticSearch] error", error)
        return []
    }
}
