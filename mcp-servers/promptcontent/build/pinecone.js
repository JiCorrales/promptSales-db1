"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.semanticSearch = semanticSearch;
const pinecone_util_1 = require("./pinecone-util");
const embeddings_1 = require("./embeddings");
async function semanticSearch(query) {
    try {
        const pineconeClient = (0, pinecone_util_1.getPinecone)();
        const indexName = process.env.PINECONE_INDEX;
        const embeddingDimensionRaw = process.env.EMBED_DIM;
        const namespace = process.env.PINECONE_NAMESPACE || "";
        if (!indexName || !embeddingDimensionRaw)
            throw new Error("PINECONE_ENV_MISSING");
        console.log("[semanticSearch] start", { indexName, namespace });
        const index = pineconeClient.index(indexName).namespace(namespace);
        const embeddingDimension = Number(embeddingDimensionRaw);
        const queryVector = await (0, embeddings_1.generateEmbedding)(query);
        console.log("[semanticSearch] vector", { len: queryVector.length });
        if (queryVector.length !== embeddingDimension)
            throw new Error("EMBED_DIM_MISMATCH");
        // Preparar la consulta de búsqueda en Pinecone
        const searchQuery = { vector: queryVector, topK: 5, includeMetadata: true };
        // Ejecutar la consulta en Pinecone
        const searchResponse = await index.query(searchQuery);
        console.log("[semanticSearch] matches", { count: (searchResponse.matches || []).length, sample: searchResponse.matches?.[0]?.id });
        // Mapear los resultados de Pinecone a un formato más sencillo
        return (searchResponse.matches || []).map(match => ({
            id: match.id,
            score: typeof match.score === "number" ? match.score : undefined
        }));
    }
    catch (e) {
        console.error("[semanticSearch] error", e);
        return [];
    }
}
