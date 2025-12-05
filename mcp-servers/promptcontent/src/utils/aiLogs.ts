import { randomUUID } from "crypto"
import { getDb } from "../db"

export type AiRequestStatus = "pending" | "processing" | "completed" | "failed"

export type AiResponseStatus = "ok" | "error" | "partial"

/* The `export interface AiRequestLogParams` is defining a TypeScript interface that specifies the
structure of the parameters that can be passed to the `logAiRequest` function. This interface
outlines the properties that can be included when logging AI request data to a database collection.
Here's a breakdown of each property: */
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

/* The `AiResponseLogParams` interface defines the structure of the parameters that can be passed to
the `logAiResponse` function. It specifies the properties that can be included when logging AI
response data to a database collection. Here's a breakdown of each property: */
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

/**
 * The function `normalizeLatency` takes a number as input, rounds it to the nearest integer, and
 * returns the result, or `null` if the input is not a valid number.
 * @param {number | null} [value] - The `normalizeLatency` function takes a parameter `value`, which is
 * expected to be a number. The function checks if the `value` is a finite number and then rounds it to
 * the nearest integer using `Math.round()`. If the `value` is not a valid number or not finite
 * @returns If the `value` is not a finite number, or if it is not a number at all, the function will
 * return `null`. Otherwise, it will return the rounded value of the input `value`.
 */
function normalizeLatency(value?: number | null) {
    if (typeof value !== "number" || !Number.isFinite(value)) return null
    return Math.round(value)
}

/**
 * The function `logAiRequest` asynchronously logs AI request parameters into a database collection and
 * returns the generated AI request ID.
 * @param {AiRequestLogParams} params - The `params` object in the `logAiRequest` function contains the
 * following properties:
 * @returns The function `logAiRequest` is returning the `aiRequestId` after inserting the AI request
 * log data into the database collection "AIRequests".
 */
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

/**
 * The function `logAiResponse` logs AI response data to a database collection.
 * @param {AiResponseLogParams} params - The `params` object in the `logAiResponse` function contains
 * the following properties:
 * @returns The function `logAiResponse` is returning the `aiResponseId` that was either provided in
 * the `params` object or generated randomly if not provided.
 */
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
