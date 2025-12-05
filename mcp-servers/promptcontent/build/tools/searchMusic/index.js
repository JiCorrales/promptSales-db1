"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerSearchMusicTool = registerSearchMusicTool;
const zod_1 = require("zod");
const spotify_1 = require("./spotify");
function registerSearchMusicTool(server) {
    server.registerTool("searchMusic", {
        title: "Buscar música para campaña",
        description: "busca pistas en Spotify por palabras clave y retorna datos útiles",
        inputSchema: {
            query: zod_1.z.string().describe("Palabras clave para buscar música"),
            limit: zod_1.z.number().int().min(1).max(10).optional()
        },
        outputSchema: {
            tracks: zod_1.z.array(zod_1.z.object({
                id: zod_1.z.string(),
                name: zod_1.z.string(),
                artist: zod_1.z.string(),
                album: zod_1.z.string(),
                preview: zod_1.z.string().nullable(),
                popularity: zod_1.z.number(),
                url: zod_1.z.string()
            }))
        }
    }, async ({ query, limit = 5 }) => {
        const tracks = await (0, spotify_1.searchTrack)(query, limit);
        const output = { tracks };
        return { content: [{ type: "text", text: JSON.stringify(output) }], structuredContent: output };
    });
}
