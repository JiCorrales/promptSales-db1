import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { ObjectId } from "mongodb"
import { z } from "zod"
import { getDb } from "../../db"
import { extractHashtags, normalizeHashtag } from "./hashtags"
import { semanticSearch } from "./pinecone"

export function registerGetContentTool(server: McpServer) {
    server.registerTool(
        "getContent",
        {
            title: "Buscar imágenes por descripción",
            description: "Usa este tool cuando el usuario solicite imágenes, referencias visuales, inspiración visual, material gráfico, recursos visuales, ideas de contenido basado en imágenes, o cuando la intención sea obtener recursos visuales relevantes a partir de un concepto descrito en texto. El tool toma una descripción textual proporcionada por el usuario y genera embeddings del contenido para realizar una búsqueda semántica en Pinecone. Con esa búsqueda, recupera imágenes relevantes en español o inglés, priorizando coincidencias conceptuales, temáticas, estéticas y contextuales. El tool debe devolver URLs de las imágenes encontradas junto con sus metadatos disponibles, tales como título, etiquetas, categorías, fuente o resolución. Además, genera un conjunto de hashtags sugeridos basados en el contenido de la descripción y los conceptos presentes en las imágenes recuperadas. Llama a este tool únicamente cuando el usuario esté pidiendo imágenes o contenido visual derivado de una descripción textual. No lo llames si el usuario pide texto, análisis, redacción, código o cualquier otra información no relacionada con contenido visual.",
            inputSchema: {
                descripcion: z.string().describe("Descripción textual para buscar imágenes")
            },
            outputSchema: {
                images: z.array(
                    z.object({
                        url: z.string(),
                        description: z.string().optional(),
                        tags: z.array(z.string()).optional()
                    })
                ),
                hashtags: z.array(z.string())
            }
        },
        async ({ descripcion }) => {
            console.log("[getContent] start", { descripcion })
            let images: { url: string; description?: string; tags?: string[] }[] = []
            try {
                const idResults: any[] = await semanticSearch(descripcion)
                console.log("[getContent] pinecone.matches", { count: Array.isArray(idResults) ? idResults.length : 0, sample: idResults?.[0] })
                if (Array.isArray(idResults) && idResults.length > 0) {
                    const db = await getDb()
                    const imagesCol = db.collection("images")
                    const ids = idResults.map((r: any) => r.id).filter(Boolean)
                    console.log("[getContent] mongo.lookup.ids", ids)

                    const objIds = ids.map((s: string) => new ObjectId(s))
                    const docs = await imagesCol.find({ _id: { $in: objIds } }).limit(5).toArray()
                    console.log("[getContent] mongo.docs", { count: docs.length })
                    images = docs.map((doc: any) => ({ url: doc.url, description: doc.alt, tags: doc.tags }))
                }
            } catch (error: any) {
                console.error("[getContent] error.semanticSearch", error)
                images = []
            }

            const hashtagsFromImages = images.flatMap(image => image.tags || []).map(normalizeHashtag)
            let hashtags = Array.from(new Set(hashtagsFromImages)).slice(0, 15)
            if (hashtags.length === 0) {
                console.log("[getContent] hashtags.fallback", { reason: "no-image-tags" })
                hashtags = extractHashtags(descripcion)
            }

            const output = { images, hashtags }
            console.log("[getContent] end", { imagesCount: images.length, hashtagsCount: hashtags.length })
            return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output }
        }
    )
}
