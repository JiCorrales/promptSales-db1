"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.redirectConsoleToStderrForStdio = redirectConsoleToStderrForStdio;
/**
 * Redirect console output to stderr when running in MCP stdio mode.
 */
function redirectConsoleToStderrForStdio() {
    if (process.env.RUN_AS_MCP_STDIO === "0")
        return;
    const toStr = (value) => {
        if (typeof value === "string")
            return value;
        try {
            return JSON.stringify(value);
        }
        catch {
            return String(value);
        }
    };
    const logToErr = (...args) => {
        try {
            process.stderr.write(args.map(toStr).join(" ") + "\n");
        }
        catch { }
    };
    console.log = logToErr;
    console.info = logToErr;
}
