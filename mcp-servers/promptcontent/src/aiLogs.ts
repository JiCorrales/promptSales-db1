import { randomUUID } from "crypto"
import { getDb } from "./db"

export type AiRequestStatus = "pending" | "processing" | "completed" | "failed"
export type AiResponseStatus = "ok" | "error" | "partial"

export interface AiRequestLogParams {
    aiRequestId?: string
    createdAt?: Date
    completedAt?: Date | null
    status: AiRequestStatus
    prompt?: string | null
    modality?: string | null
    modelProvider?: string | null
    modelName?: string | null
    modelVersion?: string | null
    paramTemperature?: number | null
    paramMaxTokens?: number | null
    requestHeaders?: any
    requestBody?: any
    responseRef?: string | null
    byUserId?: string | null
    byProcess?: string | null
    campaignRef?: string | null
    traceId?: string | null
    context?: any
    segmentKey?: string | null
}

export interface AiResponseLogParams {
    aiResponseId?: string
    aiRequestId: string
    generatedAt?: Date
    status: AiResponseStatus
    latencyMS?: number | null
    responseBody?: any
    outContentIds?: string[] | null
    usageInputTokens?: number | null
    usageOutputTokens?: number | null
    usageTotalTokens?: number | null
    errorCode?: string | null
    errorMessage?: string | null
    traceId?: string | null
}

function normalizeLatency(value?: number | null) {
    if (typeof value !== "number" || !Number.isFinite(value)) return null
    return Math.round(value)
}

export async function logAiRequest(params: AiRequestLogParams) {
    const db = await getDb()
    const aiRequestId = params.aiRequestId ?? randomUUID()
    await db.collection("AIRequests").insertOne({
        aiRequestId,
        createdAt: params.createdAt ?? new Date(),
        completedAt: params.completedAt ?? null,
        status: params.status,
        prompt: params.prompt ?? null,
        modality: params.modality ?? "text",
        modelProvider: params.modelProvider ?? null,
        modelName: params.modelName ?? null,
        modelVersion: params.modelVersion ?? null,
        paramTemperature: params.paramTemperature ?? null,
        paramMaxTokens: params.paramMaxTokens ?? null,
        requestHeaders: params.requestHeaders ?? null,
        requestBody: params.requestBody ?? null,
        responseRef: params.responseRef ?? null,
        byUserId: params.byUserId ?? null,
        byProcess: params.byProcess ?? null,
        campaignRef: params.campaignRef ?? null,
        traceId: params.traceId ?? null,
        context: params.context ?? null,
        segmentKey: params.segmentKey ?? null
    })
    return aiRequestId
}

export async function logAiResponse(params: AiResponseLogParams) {
    const db = await getDb()
    const aiResponseId = params.aiResponseId ?? randomUUID()
    await db.collection("AIResponses").insertOne({
        aiResponseId,
        aiRequestId: params.aiRequestId,
        generatedAt: params.generatedAt ?? new Date(),
        status: params.status,
        latencyMS: normalizeLatency(params.latencyMS),
        responseBody: params.responseBody ?? null,
        outContentIds: Array.isArray(params.outContentIds) ? params.outContentIds : null,
        usageInputTokens: params.usageInputTokens ?? null,
        usageOutputTokens: params.usageOutputTokens ?? null,
        usageTotalTokens: params.usageTotalTokens ?? null,
        errorCode: params.errorCode ?? null,
        errorMessage: params.errorMessage ?? null,
        traceId: params.traceId ?? null
    })
    return aiResponseId
}
