"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateMessagesWithAI = generateMessagesWithAI;
const crypto_1 = require("crypto");
const openai_1 = __importDefault(require("openai"));
const aiLogs_1 = require("../../../utils/aiLogs");
const aiPayload_1 = require("./aiPayload");
function toSegmentsFromResults(parsed) {
    const results = Array.isArray(parsed?.results) ? parsed.results : null;
    if (!results || results.length === 0)
        return null;
    return results.map((item, idx) => {
        const messages = Array.isArray(item.messages) ? item.messages.slice(0, 3) : [];
        const mapped = messages.map((text, i) => ({
            tipo: ["awareness", "consideration", "conversion"][i] ?? "mensaje",
            texto: typeof text === "string" ? text : ""
        }));
        return { nombre: item.audience || `Segmento ${idx + 1}`, mensajes: mapped };
    });
}
function fallbackSegments(auds) {
    return auds.map((aud, idx) => {
        const name = aud?.audience || `Audiencia ${idx + 1}`;
        const tone = aud?.tone || "informativo";
        const cta = aud?.cta || "Descarga ahora";
        const objective = aud?.objective || "generar interés";
        const base = (phase) => `${phase}: ${name}. Objetivo: ${objective}. Tono: ${tone}. CTA: ${cta}.`;
        return {
            nombre: name,
            mensajes: [
                { tipo: "awareness", texto: base("Descubre") },
                { tipo: "consideration", texto: base("Prueba") },
                { tipo: "conversion", texto: base("Actúa") }
            ]
        };
    });
}
async function generateMessagesWithAI(descripcion, auds, meta = {}) {
    const key = process.env.OPENAI_API_KEY;
    if (!key)
        throw new Error("OPENAI_API_KEY_MISSING");
    const client = new openai_1.default({ apiKey: key });
    const system = `
Recibe una descripción de campaña y audiencias ya procesadas (audience, objective, tone, cta).
Genera exactamente tres mensajes de campaña por cada audiencia.

Formato requerido:
{
  "results": [
    { "audience": "Descripción", "messages": ["Mensaje 1", "Mensaje 2", "Mensaje 3"] }
  ]
}

No agregues texto fuera del JSON.`;
    const user = { descripcion, audiencia: auds };
    const tries = [1, 2, 3];
    for (const attempt of tries) {
        const aiRequestId = (0, crypto_1.randomUUID)();
        const attemptStart = new Date();
        const requestStartMs = attemptStart.getTime();
        const requestBody = { attempt, user, system };
        try {
            const completion = await client.responses.create({
                model: "o4-mini",
                reasoning: { effort: "low" },
                input: [
                    { role: "system", content: system },
                    { role: "user", content: JSON.stringify(user) }
                ],
                max_output_tokens: 500
            });
            const raw = completion.output_text;
            const parsed = (0, aiPayload_1.parseSegmentsPayload)(raw);
            const fromSegmentos = Array.isArray(parsed?.segmentos) ? parsed.segmentos : null;
            const fromResults = toSegmentsFromResults(parsed);
            const segments = fromSegmentos || fromResults;
            const hasSegments = Array.isArray(segments) && segments.length > 0;
            const allGood = hasSegments &&
                segments.every(seg => Array.isArray(seg.mensajes) &&
                    seg.mensajes.length === 3 &&
                    seg.mensajes.every(m => typeof m.texto === "string" && typeof m.tipo === "string"));
            const responseStatus = allGood ? "ok" : hasSegments ? "partial" : "partial";
            const latencyMs = Date.now() - requestStartMs;
            const traceId = typeof completion.id === "string" ? completion.id : null;
            const usage = completion.usage ?? {};
            const aiResponseId = await (0, aiLogs_1.logAiResponse)({
                aiRequestId,
                status: responseStatus,
                latencyMS: latencyMs,
                responseBody: { raw },
                usageInputTokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : null,
                usageOutputTokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : null,
                usageTotalTokens: typeof usage.total_tokens === "number" ? usage.total_tokens : null,
                traceId
            });
            await (0, aiLogs_1.logAiRequest)({
                aiRequestId,
                createdAt: attemptStart,
                completedAt: new Date(),
                status: responseStatus === "ok" ? "completed" : "failed",
                prompt: descripcion,
                modality: "text",
                modelProvider: "openai",
                modelName: "o4-mini",
                modelVersion: typeof completion.model === "string" ? completion.model : "o4-mini",
                paramMaxTokens: 500,
                requestBody,
                responseRef: aiResponseId,
                traceId,
                byProcess: "promptcontent:createCampaignMessages",
                campaignRef: meta.campaignRef ?? null,
                segmentKey: meta.segmentKey ?? null,
                context: { audiences: auds, attempt }
            });
            if (allGood && segments)
                return segments;
            if (hasSegments && segments) {
                return segments.map(seg => ({
                    ...seg,
                    mensajes: seg.mensajes.slice(0, 3).map((m, i) => ({
                        tipo: m.tipo || ["awareness", "consideration", "conversion"][i] || "mensaje",
                        texto: m.texto || ""
                    }))
                }));
            }
        }
        catch (error) {
            const latencyMs = Date.now() - requestStartMs;
            const traceId = typeof error?.response?.id === "string" ? error.response.id : null;
            const aiResponseId = await (0, aiLogs_1.logAiResponse)({
                aiRequestId,
                status: "error",
                latencyMS: latencyMs,
                errorMessage: error?.message ?? "unknown",
                traceId
            });
            await (0, aiLogs_1.logAiRequest)({
                aiRequestId,
                createdAt: attemptStart,
                completedAt: new Date(),
                status: "failed",
                prompt: descripcion,
                modality: "text",
                modelProvider: "openai",
                modelName: "o4-mini",
                paramMaxTokens: 500,
                requestBody,
                responseRef: aiResponseId,
                traceId,
                byProcess: "promptcontent:createCampaignMessages",
                campaignRef: meta.campaignRef ?? null,
                segmentKey: meta.segmentKey ?? null,
                context: { audiences: auds, attempt }
            });
            if (error?.status === 429 || error?.code === "insufficient_quota") {
                return fallbackSegments(auds);
            }
        }
    }
    return fallbackSegments(auds);
}
