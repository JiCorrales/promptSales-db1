import { randomUUID } from "crypto"
import OpenAI from "openai"
import { logAiRequest, logAiResponse } from "../../../utils/aiLogs"
import { Filters } from "../utils/types"

export async function aiDeriveFilters(question: string): Promise<Filters> {
    const key = process.env.OPENAI_API_KEY
    if (!key) throw new Error("OPENAI_API_KEY_MISSING")
    const openai = new OpenAI({ apiKey: key })
    const system = `
Eres un asistente que extrae filtros estructurados para consultar campañas de marketing en una base de datos.

Recibes una pregunta en español y debes devolver un JSON con los posibles filtros derivados de la pregunta:
- campaignId (number | null)
- companyId (number | null)
- countryId (number | null)
- startDateFrom (YYYY-MM-DD | null)
- startDateTo (YYYY-MM-DD | null)
- status (string | null)

Si un filtro no se puede inferir, usa null.

Devuelve SOLO el JSON.
`
    const user = { question }
    const aiRequestId = randomUUID()
    const attemptStart = new Date()
    const requestBody = { system, user }
    const completion = await openai.responses.create({
        model: "o4-mini",
        input: [
            { role: "system", content: system },
            { role: "user", content: JSON.stringify(user) }
        ]
    })
    const raw = completion.output_text ?? "{}"
    try {
        const parsed = JSON.parse(raw)
        return {
            campaignId: parsed.campaignId ?? null,
            companyId: parsed.companyId ?? null,
            countryId: parsed.countryId ?? null,
            startDateFrom: parsed.startDateFrom ?? null,
            startDateTo: parsed.startDateTo ?? null,
            status: parsed.status ?? null
        }
    } finally {
        const latencyMs = Date.now() - attemptStart.getTime()
        const traceId = typeof completion.id === "string" ? completion.id : null
        const usage: any = completion.usage ?? {}
        const aiResponseId = await logAiResponse({
            aiRequestId,
            status: "ok",
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
            status: "completed",
            prompt: question,
            modality: "text",
            modelProvider: "openai",
            modelName: "o4-mini",
            paramMaxTokens: null,
            requestBody,
            responseRef: aiResponseId,
            traceId,
            byProcess: "promptcontent:aiDeriveFilters"
        })
    }
}
