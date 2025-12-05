"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("./env");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const server_1 = require("./server");
const stdio_1 = require("./utils/stdio");
(0, stdio_1.redirectConsoleToStderrForStdio)();
(async () => {
    if (process.env.RUN_AS_MCP_STDIO !== "0") {
        const server = (0, server_1.createMCPServer)();
        const transport = new stdio_js_1.StdioServerTransport();
        await server.connect(transport);
    }
})();
