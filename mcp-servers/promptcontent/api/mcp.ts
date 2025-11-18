// api/mcp.ts  (raíz del proyecto, carpeta api/ para Vercel Node Functions)
import type { VercelRequest, VercelResponse } from "@vercel/node"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"
import dotenv from "dotenv"
dotenv.config()

import { createPromptContentServer } from "./src/server" // ajusta la ruta según tu estructura

export const config = {
    // Forzar runtime Node (no Edge) para que Mongo, Pinecone, etc. funcionen bien
    runtime: "nodejs20"
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
    // MCP normalmente habla por POST; puedes dejar GET para healthcheck si quieres.
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method Not Allowed. Use POST with MCP JSON-RPC body." })
        return
    }

    try {
        const server = createPromptContentServer()

        // Transport HTTP streamable del SDK MCP
        const transport = new StreamableHTTPServerTransport()

        // Limpiar recursos cuando la respuesta se cierra
        res.on("close", () => {
            transport.close()
            server.close()
        })

        await server.connect(transport)

        // En Vercel, si el Content-Type es application/json,
        // req.body ya viene parseado. Lo pasamos al transport.
        await transport.handleRequest(req as any, res as any, req.body)
        // No hacemos res.end aquí: handleRequest se encarga.
    } catch (error) {
        console.error("Error handling MCP request:", error)
        if (!res.headersSent) {
            res.status(500).json({
                jsonrpc: "2.0",
                error: {
                    code: -32603,
                    message: "Internal server error"
                },
                id: null
            })
        }
    }
}
