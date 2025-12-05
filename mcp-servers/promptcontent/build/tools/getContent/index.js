"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerGetContentTool = registerGetContentTool;
const mongodb_1 = require("mongodb");
const zod_1 = require("zod");
const db_1 = require("../../db");
const hashtags_1 = require("./hashtags");
const pinecone_1 = require("./pinecone");
function registerGetContentTool(server) {
    server.registerTool("getContent", {
        title: "Buscar imágenes por descripción",
        description: "Busca imágenes relevantes (ES/EN) usando embeddings en Pinecone a partir de una descripción y devuelve URLs con metadatos más hashtags sugeridos",
        inputSchema: {
            descripcion: zod_1.z.string().describe("Descripción textual para buscar imágenes")
        },
        outputSchema: {
            images: zod_1.z.array(zod_1.z.object({
                url: zod_1.z.string(),
                description: zod_1.z.string().optional(),
                tags: zod_1.z.array(zod_1.z.string()).optional()
            })),
            hashtags: zod_1.z.array(zod_1.z.string())
        }
    }, async ({ descripcion }) => {
        console.log("[getContent] start", { descripcion });
        let images = [];
        try {
            const idResults = await (0, pinecone_1.semanticSearch)(descripcion);
            console.log("[getContent] pinecone.matches", { count: Array.isArray(idResults) ? idResults.length : 0, sample: idResults?.[0] });
            if (Array.isArray(idResults) && idResults.length > 0) {
                const db = await (0, db_1.getDb)();
                const imagesCol = db.collection("images");
                const ids = idResults.map((r) => r.id).filter(Boolean);
                console.log("[getContent] mongo.lookup.ids", ids);
                const objIds = ids.map((s) => new mongodb_1.ObjectId(s));
                const docs = await imagesCol.find({ _id: { $in: objIds } }).limit(5).toArray();
                console.log("[getContent] mongo.docs", { count: docs.length });
                images = docs.map((doc) => ({ url: doc.url, description: doc.alt, tags: doc.tags }));
            }
        }
        catch (error) {
            console.error("[getContent] error.semanticSearch", error);
            images = [];
        }
        const hashtagsFromImages = images.flatMap(image => image.tags || []).map(hashtags_1.normalizeHashtag);
        let hashtags = Array.from(new Set(hashtagsFromImages)).slice(0, 15);
        if (hashtags.length === 0) {
            console.log("[getContent] hashtags.fallback", { reason: "no-image-tags" });
            hashtags = (0, hashtags_1.extractHashtags)(descripcion);
        }
        const output = { images, hashtags };
        console.log("[getContent] end", { imagesCount: images.length, hashtagsCount: hashtags.length });
        return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output };
    });
}
