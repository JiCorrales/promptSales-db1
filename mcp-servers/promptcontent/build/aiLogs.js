"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logAiRequest = logAiRequest;
exports.logAiResponse = logAiResponse;
const crypto_1 = require("crypto");
const db_1 = require("./db");
function normalizeLatency(value) {
    if (typeof value !== "number" || !Number.isFinite(value))
        return null;
    return Math.round(value);
}
async function logAiRequest(params) {
    const db = await (0, db_1.getDb)();
    const aiRequestId = params.aiRequestId ?? (0, crypto_1.randomUUID)();
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
    });
    return aiRequestId;
}
async function logAiResponse(params) {
    const db = await (0, db_1.getDb)();
    const aiResponseId = params.aiResponseId ?? (0, crypto_1.randomUUID)();
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
    });
    return aiResponseId;
}
