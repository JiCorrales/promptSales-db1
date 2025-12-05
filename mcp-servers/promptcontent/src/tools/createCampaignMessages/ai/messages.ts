import { randomUUID } from "crypto"
import OpenAI from "openai"
import { logAiRequest, logAiResponse } from "../../../utils/aiLogs"
import { parseSegmentsPayload } from "./aiPayload"

export type AiRequestMeta = {
    campaignRef?: string
    segmentKey?: string
}

export async function generateMessagesWithAI(descripcion: string, auds: any[], meta: AiRequestMeta = {}) {
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")

    const client = new OpenAI({ apiKey: key })
    const system = `
Tarea general:
A partir únicamente del texto recibido en el campo description, analiza la campaña, deduce toda la información necesaria y genera tres mensajes publicitarios por cada público meta identificado.
Tarea general:
Recibe un objeto JSON con audiencias ya procesadas, cada una con: audience, objective, tone y cta.
A partir de esa información, genera exactamente tres mensajes de campaña publicitaria por cada segmento.

Instrucciones obligatorias:

1. Usa únicamente la información proporcionada dentro de cada audiencia.
2. Cada mensaje debe ser:
   - Claro y persuasivo
   - Alineado al tono indicado
   - Coherente con el objetivo deducido
   - Adaptado al perfil de la audiencia
   - Debe incluir explícitamente el CTA asignado
3. Los mensajes deben ser 100% originales.
4. No repitas frases entre mensajes ni entre audiencias.
5. NO infieras nuevos públicos meta.
6. NO cambies datos de las audiencias.
7. Devuelve exactamente tres mensajes por audiencia.

El output debe ser estrictamente en formato JSON.

Formato exacto de salida:

{
  "results": [
    {
      "audience": "Descripción del público meta",
      "messages": [
        "Mensaje 1",
        "Mensaje 2",
        "Mensaje 3"
      ]
    }
  ]
}

NO escribas nada fuera del JSON.
NO incluyas explicaciones.

DEVUELVE exactamente 3 mensajes de campañas de marketing por segmento.
`

    const user = {
        descripcion,
        audiencia: auds
    }

    const tries = [1, 2, 3]

    for (const attempt of tries) {
        const aiRequestId = randomUUID()
        const attemptStart = new Date()
        const requestStartMs = attemptStart.getTime()
        const requestBody = {
            attempt,
            user,
            system
        }

        try {
            const completion = await client.responses.create({
                model: "o4-mini",
                reasoning: { effort: "low" },
                input: [
                    { role: "system", content: system },
                    { role: "user", content: JSON.stringify(user) }
                ],
                max_output_tokens: 500
            })
            const raw = completion.output_text
            const parsed = parseSegmentsPayload(raw) 
            const segments = parsed?.segmentos
            const hasSegments = Array.isArray(segments)
            const allGood = hasSegments && segments.every((seg: any) =>
                Array.isArray(seg.mensajes) &&
                seg.mensajes.length === 3 &&
                seg.mensajes.every((m: any) =>
                    typeof m.texto === "string" && typeof m.tipo === "string"
                )
            )
            const responseStatus: "ok" | "partial" = allGood ? "ok" : "partial"
            const latencyMs = Date.now() - requestStartMs
            const traceId = typeof completion.id === "string" ? completion.id : null
            const usage: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number } = completion.usage ?? {}
            const aiResponseId = await logAiResponse({
                aiRequestId,
                status: responseStatus,
                latencyMS: latencyMs,
                responseBody: { raw },
                usageInputTokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : null,
                usageOutputTokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : null,
                usageTotalTokens: typeof usage.total_tokens === "number" ? usage.total_tokens : null,
                traceId
            })
            await logAiRequest({
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
                context: {
                    audiences: auds,
                    attempt
                }
            })

            if (responseStatus === "ok" && hasSegments) {
                return segments
            }
        } catch (error: any) {
            const latencyMs = Date.now() - requestStartMs
            const traceId = typeof error?.response?.id === "string" ? error.response.id : null
            const aiResponseId = await logAiResponse({
                aiRequestId,
                status: "error",
                latencyMS: latencyMs,
                errorMessage: error?.message ?? "unknown",
                traceId
            })
            await logAiRequest({
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
                context: {
                    audiences: auds,
                    attempt
                }
            })
            if (error?.status === 429 || error?.code === "insufficient_quota") {
                return []
            }
        }
    }

    return []
}
