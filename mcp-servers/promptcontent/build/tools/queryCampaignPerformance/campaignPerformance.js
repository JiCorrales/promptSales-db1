"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPostgresClient = getPostgresClient;
exports.formatLargeNumber = formatLargeNumber;
exports.formatPercent = formatPercent;
exports.aiDeriveFilters = aiDeriveFilters;
exports.fetchCampaignRows = fetchCampaignRows;
exports.fetchPromptAdsSnapshots = fetchPromptAdsSnapshots;
exports.fetchCampaignChannels = fetchCampaignChannels;
exports.fetchSalesSummaries = fetchSalesSummaries;
exports.fetchCrmInsights = fetchCrmInsights;
const crypto_1 = require("crypto");
const openai_1 = __importDefault(require("openai"));
const pg_1 = require("pg");
const aiLogs_1 = require("../../aiLogs");
let pgClient = null;
async function getPostgresClient() {
    if (pgClient) {
        return pgClient;
    }
    const url = process.env.PG_URL;
    if (!url)
        throw new Error("PG_URL_MISSING");
    pgClient = new pg_1.Client({ connectionString: url });
    await pgClient.connect();
    return pgClient;
}
function formatLargeNumber(n) {
    if (n === null || n === undefined || Number.isNaN(n))
        return "N/D";
    if (n >= 1_000_000)
        return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000)
        return `${(n / 1_000).toFixed(1)}K`;
    return String(n);
}
function formatPercent(n) {
    if (n === null || n === undefined || Number.isNaN(n))
        return "N/D";
    return `${(n * 100).toFixed(1)}%`;
}
async function aiDeriveFilters(question) {
    const key = process.env.OPENAI_API_KEY;
    if (!key)
        throw new Error("OPENAI_API_KEY_MISSING");
    const openai = new openai_1.default({ apiKey: key });
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
`;
    const user = { question };
    const aiRequestId = (0, crypto_1.randomUUID)();
    const attemptStart = new Date();
    const requestBody = { system, user };
    const completion = await openai.responses.create({
        model: "o4-mini",
        input: [
            { role: "system", content: system },
            { role: "user", content: JSON.stringify(user) }
        ]
    });
    const raw = completion.output_text ?? "{}";
    try {
        const parsed = JSON.parse(raw);
        return {
            campaignId: parsed.campaignId ?? null,
            companyId: parsed.companyId ?? null,
            countryId: parsed.countryId ?? null,
            startDateFrom: parsed.startDateFrom ?? null,
            startDateTo: parsed.startDateTo ?? null,
            status: parsed.status ?? null
        };
    }
    finally {
        const latencyMs = Date.now() - attemptStart.getTime();
        const traceId = typeof completion.id === "string" ? completion.id : null;
        const usage = completion.usage ?? {};
        const aiResponseId = await (0, aiLogs_1.logAiResponse)({
            aiRequestId,
            status: "ok",
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
        });
    }
}
async function fetchCampaignRows(client, filters, limit) {
    const conditions = [];
    const params = [];
    if (filters.campaignId) {
        conditions.push("c.campaign_id = $1");
        params.push(filters.campaignId);
    }
    if (filters.companyId) {
        conditions.push(`c.company_id = $${params.length + 1}`);
        params.push(filters.companyId);
    }
    if (filters.countryId) {
        conditions.push(`c.country_id = $${params.length + 1}`);
        params.push(filters.countryId);
    }
    if (filters.startDateFrom) {
        conditions.push(`c.start_date >= $${params.length + 1}`);
        params.push(filters.startDateFrom);
    }
    if (filters.startDateTo) {
        conditions.push(`c.start_date <= $${params.length + 1}`);
        params.push(filters.startDateTo);
    }
    if (filters.status) {
        conditions.push(`c.status = $${params.length + 1}`);
        params.push(filters.status);
    }
    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const query = `
        SELECT
            c.campaign_id AS "campaignId",
            c.campaign_name AS "campaignName",
            c.status,
            c.company_name AS "companyName",
            c.start_date AS "startDate",
            c.end_date AS "endDate",
            c.budget_amount AS "budgetAmount",
            calc.roi,
            calc.total_spent AS "totalSpent",
            calc.total_revenue AS "calcTotalRevenue",
            ints.clicks,
            ints.likes,
            ints.comments,
            ints.reactions,
            ints.shares,
            ints.users_reached AS "usersReached",
            calc.conversion_rate AS "conversionRate",
            calc.engagement_rate AS "engagementRate"
        FROM campaigns c
        LEFT JOIN interactions ints ON ints.campaign_id = c.campaign_id
        LEFT JOIN calculations calc ON calc.campaign_id = c.campaign_id
        ${where}
        ORDER BY c.start_date DESC
        LIMIT $${params.length + 1}
    `;
    params.push(limit);
    const result = await client.query(query, params);
    return result.rows.map(row => ({
        ...row,
        interactions: {
            clicks: row.interactions?.clicks ?? row.clicks ?? null,
            likes: row.interactions?.likes ?? row.likes ?? null,
            comments: row.interactions?.comments ?? row.comments ?? null,
            reactions: row.interactions?.reactions ?? row.reactions ?? null,
            shares: row.interactions?.shares ?? row.shares ?? null,
            usersReached: row.interactions?.usersReached ?? row.usersReached ?? null
        },
        budgetAmount: row.budgetAmount ?? null,
        conversionRate: row.conversionRate ?? null,
        engagementRate: row.engagementRate ?? null,
        roi: row.roi ?? null,
        totalSpent: row.totalSpent ?? null,
        calcTotalRevenue: row.calcTotalRevenue ?? null
    }));
}
async function fetchPromptAdsSnapshots(client, campaignIds) {
    const query = `
        SELECT
            campaign_id AS "campaignId",
            campaign_budget AS "campaignBudget",
            snapshot_date AS "snapshotDate",
            total_reach AS "totalReach",
            total_impressions AS "totalImpressions",
            total_clicks AS "totalClicks",
            total_interactions AS "totalInteractions",
            total_hours_viewed AS "totalHoursViewed",
            total_cost AS "totalCost",
            total_revenue AS "totalRevenue",
            snapshot_channels AS "snapshotChannels",
            snapshot_markets AS "snapshotMarkets",
            company_name AS "companyName"
        FROM prompt_ads_snapshots
        WHERE campaign_id = ANY($1)
    `;
    const result = await client.query(query, [campaignIds]);
    const map = new Map();
    for (const row of result.rows) {
        map.set(row.campaignId, row);
    }
    return map;
}
async function fetchCampaignChannels(client, campaignIds) {
    const query = `
        SELECT
            campaign_id AS "campaignId",
            channel_name AS "channelName"
        FROM campaign_channels
        WHERE campaign_id = ANY($1)
    `;
    const result = await client.query(query, [campaignIds]);
    const map = new Map();
    for (const row of result.rows) {
        const list = map.get(row.campaignId) || [];
        list.push(row.channelName);
        map.set(row.campaignId, list);
    }
    return map;
}
async function fetchSalesSummaries(client, campaignIds) {
    const query = `
        SELECT
            campaign_id AS "campaignId",
            orders,
            sales_amount AS "salesAmount",
            returns_amount AS "returnsAmount",
            ads_revenue AS "adsRevenue",
            currency_id AS "currencyId"
        FROM sales_summary
        WHERE campaign_id = ANY($1)
    `;
    const result = await client.query(query, [campaignIds]);
    const map = new Map();
    for (const row of result.rows) {
        map.set(row.campaignId, row);
    }
    return map;
}
async function fetchCrmInsights(client, campaignIds) {
    const summaryQuery = `
        SELECT
            campaign_id AS "campaignId",
            total_leads AS "totalLeads",
            conversion_events AS "conversionEvents",
            channel_names AS "channelNames"
        FROM prompt_crm_snapshots
        WHERE campaign_id = ANY($1)
    `;
    const statusQuery = `
        SELECT
            campaign_id AS "campaignId",
            lead_status AS "leadStatus",
            count
        FROM prompt_crm_status
        WHERE campaign_id = ANY($1)
    `;
    const [summaryResult, statusResult] = await Promise.all([
        client.query(summaryQuery, [campaignIds]),
        client.query(statusQuery, [campaignIds])
    ]);
    const summaryMap = new Map();
    for (const row of summaryResult.rows) {
        summaryMap.set(row.campaignId, row);
    }
    const statusMap = new Map();
    for (const row of statusResult.rows) {
        const map = statusMap.get(row.campaignId) || {};
        map[row.leadStatus] = row.count;
        statusMap.set(row.campaignId, map);
    }
    return { summaryMap, statusMap };
}
