import "./env"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { createMCPServer } from "./server"
import { redirectConsoleToStderrForStdio } from "./utils/stdio"

redirectConsoleToStderrForStdio()

;(async () => {
    if (process.env.RUN_AS_MCP_STDIO !== "0") {
        const server = createMCPServer()
        const transport = new StdioServerTransport()
        await server.connect(transport)
    }
})()
