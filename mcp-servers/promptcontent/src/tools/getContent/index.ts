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
            description: "Busca imágenes relevantes (ES/EN) usando embeddings en Pinecone a partir de una descripción y devuelve URLs con metadatos más hashtags sugeridos",
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
