
import type { VercelRequest, VercelResponse } from "@vercel/node"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streaming-http.js"
import { createPromptContentServer } from "../src/server"

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method Not Allowed. Use POST with JSON-RPC 2.0 body." })
    return
  }

  const server = createPromptContentServer()

  const transport = new StreamableHTTPServerTransport({
    send: async (message) => {
      res.setHeader("Content-Type", "application/json")
      res.status(200).send(JSON.stringify(message))
    },
    receive: async () => {
      return req.body
    }
  })

  await server.connect(transport)
}
