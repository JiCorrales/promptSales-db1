"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logAiRequest = logAiRequest;
exports.logAiResponse = logAiResponse;
const crypto_1 = require("crypto");
const db_1 = require("../db");
/**
 * The function `normalizeLatency` takes a number as input, rounds it to the nearest integer, and
 * returns the result, or `null` if the input is not a valid number.
 * @param {number | null} [value] - The `normalizeLatency` function takes a parameter `value`, which is
 * expected to be a number. The function checks if the `value` is a finite number and then rounds it to
 * the nearest integer using `Math.round()`. If the `value` is not a valid number or not finite
 * @returns If the `value` is not a finite number, or if it is not a number at all, the function will
 * return `null`. Otherwise, it will return the rounded value of the input `value`.
 */
function normalizeLatency(value) {
    if (typeof value !== "number" || !Number.isFinite(value))
        return null;
    return Math.round(value);
}
/**
 * The function `logAiRequest` asynchronously logs AI request parameters into a database collection and
 * returns the generated AI request ID.
 * @param {AiRequestLogParams} params - The `params` object in the `logAiRequest` function contains the
 * following properties:
 * @returns The function `logAiRequest` is returning the `aiRequestId` after inserting the AI request
 * log data into the database collection "AIRequests".
 */
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
/**
 * The function `logAiResponse` logs AI response data to a database collection.
 * @param {AiResponseLogParams} params - The `params` object in the `logAiResponse` function contains
 * the following properties:
 * @returns The function `logAiResponse` is returning the `aiResponseId` that was either provided in
 * the `params` object or generated randomly if not provided.
 */
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
