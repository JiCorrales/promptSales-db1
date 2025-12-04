"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiDeriveFilters = aiDeriveFilters;
exports.formatLargeNumber = formatLargeNumber;
exports.formatPercent = formatPercent;
exports.getPostgresClient = getPostgresClient;
exports.fetchCampaignRows = fetchCampaignRows;
exports.fetchPromptAdsSnapshots = fetchPromptAdsSnapshots;
exports.fetchCampaignChannels = fetchCampaignChannels;
exports.fetchSalesSummaries = fetchSalesSummaries;
exports.fetchCrmInsights = fetchCrmInsights;
const pg_1 = require("pg");
const openai_1 = __importDefault(require("openai"));
const crypto_1 = require("crypto");
const aiLogs_1 = require("./aiLogs");
let pgClient = null;
function coerceNumber(value) {
    if (value === null || value === undefined)
        return null;
    const coerced = Number(value);
    return Number.isFinite(coerced) ? coerced : null;
}
function normalizeStringArray(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .filter((item) => typeof item === "string")
        .map(item => item.trim())
        .filter(Boolean);
}
async function aiDeriveFilters(question) {
    const key = process.env.OPENAI_API_KEY;
    if (!key)
        return { campaignId: null, companyId: null };
    const client = new openai_1.default({ apiKey: key });
    const system = `Devuelve SOLO un JSON vA�lido con esta forma exacta:
{
  "campaignId": <number|null>,
  "companyId": <number|null>
}`;
    const user = { question };
    const requestStart = new Date();
    const requestBody = {
        system,
        question,
        model: "o4-mini"
    };
    const aiRequestId = (0, crypto_1.randomUUID)();
    const requestStartMs = requestStart.getTime();
    try {
        const completion = await client.responses.create({
            model: "o4-mini",
            reasoning: { effort: "low" },
            input: [
                { role: "system", content: system },
                { role: "user", content: JSON.stringify(user) }
            ],
            max_output_tokens: 200
        });
        const raw = completion.output_text;
        const trimmed = (raw || "").trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
        let parsed = null;
        try {
            parsed = JSON.parse(trimmed);
        }
        catch { }
        const responseStatus = parsed ? "ok" : "partial";
        const latencyMs = Date.now() - requestStartMs;
        const traceId = typeof completion.id === "string" ? completion.id : null;
        const usage = completion.usage ?? {};
        const aiResponseId = await (0, aiLogs_1.logAiResponse)({
            aiRequestId,
            status: responseStatus,
            latencyMS: latencyMs,
            responseBody: trimmed || null,
            usageInputTokens: typeof usage.prompt_tokens === "number" ? usage.prompt_tokens : null,
            usageOutputTokens: typeof usage.completion_tokens === "number" ? usage.completion_tokens : null,
            usageTotalTokens: typeof usage.total_tokens === "number" ? usage.total_tokens : null,
            traceId
        });
        await (0, aiLogs_1.logAiRequest)({
            aiRequestId,
            createdAt: requestStart,
            completedAt: new Date(),
            status: responseStatus === "ok" ? "completed" : "failed",
            prompt: question,
            modality: "text",
            modelProvider: "openai",
            modelName: "o4-mini",
            modelVersion: typeof completion.model === "string" ? completion.model : "o4-mini",
            requestBody,
            responseRef: aiResponseId,
            traceId,
            byProcess: "promptcontent:queryCampaignPerformance"
        });
        if (!parsed) {
            return { campaignId: null, companyId: null };
        }
        const cId = typeof parsed.campaignId === "number" && Number.isFinite(parsed.campaignId) ? parsed.campaignId : null;
        const coId = typeof parsed.companyId === "number" && Number.isFinite(parsed.companyId) ? parsed.companyId : null;
        return { campaignId: cId, companyId: coId };
    }
    catch (error) {
        const latencyMs = Date.now() - requestStartMs;
        const traceId = typeof error?.response?.id === "string" ? error.response.id : null;
        const aiResponseId = await (0, aiLogs_1.logAiResponse)({
            aiRequestId,
            status: "error",
            latencyMS: latencyMs,
            responseBody: null,
            errorMessage: error?.message ?? "unknown",
            traceId
        });
        await (0, aiLogs_1.logAiRequest)({
            aiRequestId,
            createdAt: requestStart,
            completedAt: new Date(),
            status: "failed",
            prompt: question,
            modality: "text",
            modelProvider: "openai",
            modelName: "o4-mini",
            requestBody,
            responseRef: aiResponseId,
            traceId,
            byProcess: "promptcontent:queryCampaignPerformance"
        });
        return { campaignId: null, companyId: null };
    }
}
function formatTimestamp(value) {
    if (value === null || value === undefined)
        return null;
    if (value instanceof Date)
        return value.toISOString();
    if (typeof value === "string")
        return value;
    return null;
}
function formatLargeNumber(value) {
    return value === null ? "n/d" : value.toLocaleString("es-ES");
}
function formatPercent(value) {
    if (value === null)
        return "n/d";
    return `${(value * 100).toFixed(1)}%`;
}
function buildConfig() {
    const connectionString = process.env.POSTGRES_DSN;
    if (connectionString)
        return { connectionString };
    const missing = [];
    const host = process.env.POSTGRES_HOST;
    const port = Number(process.env.POSTGRES_PORT ?? "5432");
    const database = process.env.POSTGRES_DB;
    const user = process.env.POSTGRES_USER;
    const password = process.env.POSTGRES_PASSWORD;
    if (!host)
        missing.push("POSTGRES_HOST");
    if (!database)
        missing.push("POSTGRES_DB");
    if (!user)
        missing.push("POSTGRES_USER");
    if (!password)
        missing.push("POSTGRES_PASSWORD");
    if (missing.length) {
        throw new Error(`POSTGRES_ENV_MISSING:${missing.join(",")}`);
    }
    return {
        host,
        port: Number.isFinite(port) && port > 0 ? port : 5432,
        database,
        user,
        password
    };
}
async function getPostgresClient() {
    if (pgClient)
        return pgClient;
    const config = buildConfig();
    const client = new pg_1.Client(config);
    await client.connect();
    pgClient = client;
    return client;
}
// deriveFiltersFromQuestion eliminado en favor de aiDeriveFilters
async function fetchCampaignRows(client, filters, limit) {
    const { rows } = await client.query(`
        SELECT
            c."campaignId" AS campaign_id,
            c.name AS campaign_name,
            c.status AS status,
            c.description AS description,
            c."budgetAmount" AS budget_amount,
            c."startDate" AS start_date,
            c."endDate" AS end_date,
            c."companyId" AS company_id,
            comp."companyName" AS company_name,
            i."clicks" AS i_clicks,
            i.likes AS i_likes,
            i.comments AS i_comments,
            i.reactions AS i_reactions,
            i.shares AS i_shares,
            i."usersReached" AS i_users_reached,
            calc."conversionRate" AS conversion_rate,
            calc."engagementRate" AS engagement_rate,
            calc."ROI" AS roi,
            calc."totalSpent" AS total_spent,
            calc."totalRevenue" AS calc_total_revenue
        FROM public."Campaigns" c
        LEFT JOIN public."Companies" comp ON comp."companyId" = c."companyId"
        LEFT JOIN public."Interactions" i ON i."interactionId" = c."intereractionsId"
        LEFT JOIN public."Calculations" calc ON calc."calculoId" = c."calculatiosId"
        WHERE ($1::bigint IS NULL OR c."campaignId" = $1)
          AND ($2::bigint IS NULL OR c."companyId" = $2)
        ORDER BY c."startDate" DESC NULLS LAST, c."campaignId" DESC
        LIMIT $3
        `, [filters.campaignId ?? null, filters.companyId ?? null, limit]);
    return rows
        .map((row) => {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            return null;
        return {
            campaignId,
            campaignName: typeof row.campaign_name === "string" ? row.campaign_name : null,
            status: typeof row.status === "string" ? row.status : null,
            description: typeof row.description === "string" ? row.description : null,
            budgetAmount: coerceNumber(row.budget_amount),
            startDate: formatTimestamp(row.start_date),
            endDate: formatTimestamp(row.end_date),
            companyId: coerceNumber(row.company_id),
            companyName: typeof row.company_name === "string" ? row.company_name : null,
            interactions: {
                clicks: coerceNumber(row.i_clicks),
                likes: coerceNumber(row.i_likes),
                comments: coerceNumber(row.i_comments),
                reactions: coerceNumber(row.i_reactions),
                shares: coerceNumber(row.i_shares),
                usersReached: coerceNumber(row.i_users_reached)
            },
            conversionRate: coerceNumber(row.conversion_rate),
            engagementRate: coerceNumber(row.engagement_rate),
            roi: coerceNumber(row.roi),
            totalSpent: coerceNumber(row.total_spent),
            calcTotalRevenue: coerceNumber(row.calc_total_revenue)
        };
    })
        .filter((entry) => entry !== null);
}
async function fetchPromptAdsSnapshots(client, campaignIds) {
    if (campaignIds.length === 0)
        return new Map();
    const { rows } = await client.query(`
        WITH aggregated AS (
            SELECT
                campaign_id,
                SUM(COALESCE(total_reach, 0)) AS total_reach,
                SUM(COALESCE(total_impressions, 0)) AS total_impressions,
                SUM(COALESCE(total_clicks, 0)) AS total_clicks,
                SUM(COALESCE(total_interactions, 0)) AS total_interactions,
                SUM(COALESCE(total_hours_viewed, 0)) AS total_hours_viewed,
                SUM(COALESCE(total_cost, 0)) AS total_cost,
                SUM(COALESCE(total_revenue, 0)) AS total_revenue,
                MAX(campaign_budget) AS campaign_budget,
                MAX(company_name) AS company_name,
                MAX(snapshot_date) AS snapshot_date,
                STRING_AGG(DISTINCT COALESCE(channels, ''), ',') AS raw_channels,
                STRING_AGG(DISTINCT COALESCE(target_markets, ''), ',') AS raw_markets
            FROM public."PromptAdsSnapshots"
            WHERE campaign_id = ANY($1)
            GROUP BY campaign_id
        )
        SELECT
            campaign_id,
            total_reach,
            total_impressions,
            total_clicks,
            total_interactions,
            total_hours_viewed,
            total_cost,
            total_revenue,
            campaign_budget,
            company_name,
            snapshot_date,
            COALESCE(
                (
                    SELECT ARRAY_AGG(DISTINCT TRIM(channel))
                    FROM regexp_split_to_table(COALESCE(raw_channels, ''), ',') AS channel
                    WHERE TRIM(channel) <> ''
                ),
                ARRAY[]::text[]
            ) AS snapshot_channels,
            COALESCE(
                (
                    SELECT ARRAY_AGG(DISTINCT TRIM(market))
                    FROM regexp_split_to_table(COALESCE(raw_markets, ''), ',') AS market
                    WHERE TRIM(market) <> ''
                ),
                ARRAY[]::text[]
            ) AS snapshot_markets
        FROM aggregated
        `, [campaignIds]);
    const map = new Map();
    for (const row of rows) {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            continue;
        map.set(campaignId, {
            campaignId,
            totalReach: coerceNumber(row.total_reach),
            totalImpressions: coerceNumber(row.total_impressions),
            totalClicks: coerceNumber(row.total_clicks),
            totalInteractions: coerceNumber(row.total_interactions),
            totalHoursViewed: coerceNumber(row.total_hours_viewed),
            totalCost: coerceNumber(row.total_cost),
            totalRevenue: coerceNumber(row.total_revenue),
            campaignBudget: coerceNumber(row.campaign_budget),
            companyName: typeof row.company_name === "string" ? row.company_name : null,
            snapshotDate: formatTimestamp(row.snapshot_date),
            snapshotChannels: normalizeStringArray(row.snapshot_channels),
            snapshotMarkets: normalizeStringArray(row.snapshot_markets)
        });
    }
    return map;
}
async function fetchCampaignChannels(client, campaignIds) {
    if (campaignIds.length === 0)
        return new Map();
    const { rows } = await client.query(`
        SELECT
            "campaignId" AS campaign_id,
            COALESCE(
                ARRAY_AGG(DISTINCT name) FILTER (WHERE name IS NOT NULL AND TRIM(name) <> ''),
                ARRAY[]::text[]
            ) AS channel_names
        FROM public."CampaignChannels"
        WHERE "campaignId" = ANY($1)
        GROUP BY "campaignId"
        `, [campaignIds]);
    const map = new Map();
    for (const row of rows) {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            continue;
        map.set(campaignId, normalizeStringArray(row.channel_names));
    }
    return map;
}
async function fetchSalesSummaries(client, campaignIds) {
    if (campaignIds.length === 0)
        return new Map();
    const { rows } = await client.query(`
        SELECT
            "campaignId" AS campaign_id,
            SUM(orders) AS orders,
            SUM("salesAmount") AS sales_amount,
            SUM("returnsAmount") AS returns_amount,
            SUM("adsRevenue") AS ads_revenue,
            MAX(currencyd) AS currency_id
        FROM public."salesSummary"
        WHERE "campaignId" = ANY($1)
        GROUP BY "campaignId"
        `, [campaignIds]);
    const map = new Map();
    for (const row of rows) {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            continue;
        map.set(campaignId, {
            campaignId,
            orders: coerceNumber(row.orders),
            salesAmount: coerceNumber(row.sales_amount),
            returnsAmount: coerceNumber(row.returns_amount),
            adsRevenue: coerceNumber(row.ads_revenue),
            currencyId: coerceNumber(row.currency_id)
        });
    }
    return map;
}
async function fetchCrmInsights(client, campaignIds) {
    if (campaignIds.length === 0) {
        return { summaryMap: new Map(), statusMap: new Map() };
    }
    const summaryResult = await client.query(`
        SELECT
            campaign_id,
            COUNT(*) AS total_leads,
            SUM(COALESCE(conversion_events, 0)) AS conversion_events,
            COALESCE(
                ARRAY_AGG(DISTINCT channel_name) FILTER (WHERE channel_name IS NOT NULL AND TRIM(channel_name) <> ''),
                ARRAY[]::text[]
            ) AS channel_names
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id
        `, [campaignIds]);
    const summaryMap = new Map();
    for (const row of summaryResult.rows) {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            continue;
        summaryMap.set(campaignId, {
            campaignId,
            totalLeads: coerceNumber(row.total_leads) ?? 0,
            conversionEvents: coerceNumber(row.conversion_events) ?? 0,
            channelNames: normalizeStringArray(row.channel_names)
        });
    }
    const statusResult = await client.query(`
        SELECT
            campaign_id,
            COALESCE(lead_status, 'desconocido') AS lead_status,
            COUNT(*) AS status_count
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id, COALESCE(lead_status, 'desconocido')
        `, [campaignIds]);
    const statusMap = new Map();
    for (const row of statusResult.rows) {
        const campaignId = coerceNumber(row.campaign_id);
        if (campaignId === null)
            continue;
        const leadStatus = typeof row.lead_status === "string" ? row.lead_status : "desconocido";
        const statusCount = coerceNumber(row.status_count) ?? 0;
        const existing = statusMap.get(campaignId) ?? {};
        existing[leadStatus] = (existing[leadStatus] ?? 0) + statusCount;
        statusMap.set(campaignId, existing);
    }
    return { summaryMap, statusMap };
}
