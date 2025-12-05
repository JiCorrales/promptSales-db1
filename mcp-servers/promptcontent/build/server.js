"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createMCPServer = createMCPServer;
require("./env");
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const createCampaignMessages_1 = require("./tools/createCampaignMessages");
const getContent_1 = require("./tools/getContent");
const queryCampaignPerformance_1 = require("./tools/queryCampaignPerformance");
const searchMusic_1 = require("./tools/searchMusic");
/**
 * Crea y configura una instancia de `McpServer` con todas las tools disponibles para PromptContent.
 */
function createMCPServer() {
    const server = new mcp_js_1.McpServer({
        name: "mcp-server",
        version: "1.0.0",
        capabilities: { tools: {} }
    });
    (0, getContent_1.registerGetContentTool)(server);
    (0, searchMusic_1.registerSearchMusicTool)(server);
    (0, createCampaignMessages_1.registerCreateCampaignMessagesTool)(server);
    (0, queryCampaignPerformance_1.registerQueryCampaignPerformanceTool)(server);
    return server;
}
