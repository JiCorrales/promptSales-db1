import "./env"
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { registerCreateCampaignMessagesTool } from "./tools/createCampaignMessages"
import { registerGetContentTool } from "./tools/getContent"
import { registerQueryCampaignPerformanceTool } from "./tools/queryCampaignPerformance"
import { registerSearchMusicTool } from "./tools/searchMusic"

/**
 * Crea y configura una instancia de `McpServer` con todas las tools disponibles para PromptContent.
 */
export function createMCPServer() {
    const server = new McpServer({
        name: "mcp-server",
        version: "1.0.0",
        capabilities: { tools: {} }
    })

    registerGetContentTool(server)
    registerSearchMusicTool(server)
    registerCreateCampaignMessagesTool(server)
    registerQueryCampaignPerformanceTool(server)

    return server
}
