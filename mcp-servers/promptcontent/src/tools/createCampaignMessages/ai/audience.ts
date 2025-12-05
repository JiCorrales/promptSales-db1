import { randomUUID } from "crypto"
import OpenAI from "openai"
import { logAiRequest, logAiResponse } from "../../../utils/aiLogs"
import { parseSegmentsPayload } from "./aiPayload"

export type AudienceTarget = {
    audience: string
    ageRange: string
    gender: string
    interests: string[]
    location: string
    lifestyle: string
    profession: string
    needs: string[]
    objective: string
    tone: string
    cta: string
}

const normalizeString = (value: unknown) => (typeof value === "string" ? value.trim() : "")
const normalizeArray = (value: unknown) =>
    Array.isArray(value)
        ? value
            .map(item => (typeof item === "string" ? item.trim() : ""))
            .filter(item => item.length > 0)
        : []

const normalizeTarget = (rawTarget: any): AudienceTarget => {
    const target = rawTarget ?? {}
    const audience = normalizeString(target.audience)
    const ageRange = normalizeString(target.ageRange)
    return {
        audience,
        ageRange,
        gender: normalizeString(target.gender) || "no determinado",
        interests: normalizeArray(target.interests),
        location: normalizeString(target.location) || "no especificada",
        lifestyle: normalizeString(target.lifestyle),
        profession: normalizeString(target.profession),
        needs: normalizeArray(target.needs),
        objective: normalizeString(target.objective),
        tone: normalizeString(target.tone),
        cta: normalizeString(target.cta)
    }
}

export async function getAudienceWithAI(descripcion: string) {
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")

    const client = new OpenAI({ apiKey: key })
    const system = `Tarea general:
A partir únicamente del texto recibido en el campo description, analiza la campaña y deduce todas las audiencias (públicos meta) mencionadas o implícitas.

Instrucciones obligatorias:

1. Lee y analiza la descripción completa.
2. Interpreta todo exclusivamente desde ese texto.
3. Identifica y clasifica automáticamente los públicos meta.
4. Para cada audiencia detectada, deduce:

- Rango de edad (explícito o inferido)
- Género (si es posible)
- Intereses
- Ubicación (si existe)
- Estilo de vida o comportamientos relevantes
- Profesión u ocupación (si aplica)
- Necesidades o dolores asociados
- Objetivo de marketing que esta audiencia persigue o responde mejor
- Tono ideal para comunicar
- CTA más adecuado para esta audiencia

5. Si la descripción sugiere múltiples segmentos, divídelos correctamente.
6. No generes mensajes. Solo devuelve la descripción de cada audiencia y su metadata inferida.

El output debe ser estrictamente en formato JSON.

Formato exacto de salida:

{
  "targets": [
    {
      "audience": "Descripción detallada del público meta",
      "ageRange": "Rango inferido",
      "gender": "Género inferido o 'no determinado'",
      "interests": ["...", "..."],
      "location": "Ubicación inferida o 'no especificada'",
      "lifestyle": "Estilo de vida o comportamiento",
      "profession": "Profesión si se infiere",
      "needs": ["Necesidad 1", "Necesidad 2"],
      "objective": "Objetivo deducido",
      "tone": "Tono deducido",
      "cta": "CTA deducido"
    }
  ]
}

NO escribas nada fuera del JSON.
NO incluyas explicaciones.`

    const user = { descripcion }
    const tries = [1, 2, 3]

    for (const attempt of tries) {
        const aiRequestId = randomUUID()
        const attemptStart = new Date()
        const requestStartMs = attemptStart.getTime()
        const requestBody = { attempt, user, system }

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

            const raw = completion.output_text ?? ""
            const parsed = parseSegmentsPayload(raw)
            const targetsRaw = Array.isArray(parsed?.targets) ? parsed.targets : []
            const normalizedTargets: AudienceTarget[] = targetsRaw.map(normalizeTarget)
            const hasTargets = normalizedTargets.length > 0
            const requiredFieldsOk = normalizedTargets.every((target: AudienceTarget) =>
                Boolean(target.audience && target.ageRange && target.objective && target.tone && target.cta)
            )
            const responseStatus: "ok" | "partial" = hasTargets && requiredFieldsOk ? "ok" : "partial"
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
                byProcess: "promptcontent:getAudienceWithAI",
                campaignRef: null,
                segmentKey: null,
                context: { attempt }
            })

            if (responseStatus === "ok" && hasTargets) {
                return normalizedTargets
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
                byProcess: "promptcontent:getAudienceWithAI",
                campaignRef: null,
                segmentKey: null,
                context: { attempt }
            })

            if (error?.status === 429 || error?.code === "insufficient_quota") {
                return []
            }
        }
    }

    return []
}
