"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseSegmentsPayload = parseSegmentsPayload;
/**
 * This TypeScript function parses a JSON payload from a string by extracting the JSON content enclosed
 * in triple backticks.
 * @param {string} raw - The `parseSegmentsPayload` function takes a raw string as input and attempts
 * to extract a JSON payload from it. The function trims the input string, removes any leading and
 * trailing triple backticks (```), and then searches for JSON content within the string. If it finds
 * valid JSON content, it
 * @returns The `parseSegmentsPayload` function is designed to parse a JSON payload from a raw string
 * input. It trims the input, removes any leading and trailing triple backticks (potentially with
 * "json" after the first set), and then attempts to extract and parse the JSON object within the
 * string. If successful, it returns the parsed JSON object; otherwise, it returns `null`.
 */
function parseSegmentsPayload(raw) {
    const fenced = (raw || "").trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
    const start = fenced.indexOf("{");
    const end = fenced.lastIndexOf("}");
    const candidates = [fenced];
    if (start !== -1 && end !== -1 && end > start) {
        candidates.push(fenced.slice(start, end + 1));
    }
    for (const candidate of candidates) {
        try {
            return JSON.parse(candidate);
        }
        catch {
            continue;
        }
    }
    return null;
}
