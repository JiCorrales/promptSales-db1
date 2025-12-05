"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchCampaignRows = fetchCampaignRows;
exports.fetchPromptAdsSnapshots = fetchPromptAdsSnapshots;
exports.fetchCampaignChannels = fetchCampaignChannels;
exports.fetchSalesSummaries = fetchSalesSummaries;
exports.fetchCrmInsights = fetchCrmInsights;
async function fetchCampaignRows(client, filters, limit) {
    const coerceNumber = (value) => {
        const n = typeof value === "string" || typeof value === "number" ? Number(value) : null;
        return Number.isFinite(n) ? n : null;
    };
    const toIsoOrNull = (value) => {
        if (value === null || value === undefined)
            return null;
        const d = value instanceof Date ? value : new Date(value);
        return Number.isFinite(d.getTime()) ? d.toISOString() : null;
    };
    const conditions = [];
    const params = [];
    if (filters.campaignId) {
        conditions.push(`c."campaignId" = $1`);
        params.push(filters.campaignId);
    }
    if (filters.companyId) {
        conditions.push(`c."companyId" = $${params.length + 1}`);
        params.push(filters.companyId);
    }
    // countryId no existe en Campaigns; se ignora si no viene
    if (filters.startDateFrom) {
        conditions.push(`c."startDate" >= $${params.length + 1}`);
        params.push(filters.startDateFrom);
    }
    if (filters.startDateTo) {
        conditions.push(`c."startDate" <= $${params.length + 1}`);
        params.push(filters.startDateTo);
    }
    if (filters.status) {
        conditions.push(`c."status" = $${params.length + 1}`);
        params.push(filters.status);
    }
    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const query = `
        SELECT
            c."campaignId" AS "campaignId",
            c."name" AS "campaignName",
            c."status" AS "status",
            comp."companyName" AS "companyName",
            c."startDate" AS "startDate",
            c."endDate" AS "endDate",
            c."budgetAmount" AS "budgetAmount",
            calc."ROI" AS "roi",
            calc."totalSpent" AS "totalSpent",
            calc."totalRevenue" AS "calcTotalRevenue",
            ints."clicks" AS "clicks",
            ints."likes" AS "likes",
            ints."comments" AS "comments",
            ints."reactions" AS "reactions",
            ints."shares" AS "shares",
            ints."usersReached" AS "usersReached",
            calc."conversionRate" AS "conversionRate",
            calc."engagementRate" AS "engagementRate"
        FROM public."Campaigns" c
        LEFT JOIN public."Companies" comp ON comp."companyId" = c."companyId"
        LEFT JOIN public."Interactions" ints ON ints."interactionId" = c."intereractionsId"
        LEFT JOIN public."Calculations" calc ON calc."calculoId" = c."calculatiosId"
        ${where}
        ORDER BY c."startDate" DESC NULLS LAST, c."campaignId" DESC
        LIMIT $${params.length + 1}
    `;
    params.push(limit);
    const result = await client.query(query, params);
    return result.rows.map(row => ({
        ...row,
        startDate: toIsoOrNull(row.startDate),
        endDate: toIsoOrNull(row.endDate),
        interactions: {
            clicks: row.clicks ?? null,
            likes: row.likes ?? null,
            comments: row.comments ?? null,
            reactions: row.reactions ?? null,
            shares: row.shares ?? null,
            usersReached: row.usersReached ?? null
        },
        budgetAmount: coerceNumber(row.budgetAmount),
        conversionRate: coerceNumber(row.conversionRate),
        engagementRate: coerceNumber(row.engagementRate),
        roi: coerceNumber(row.roi),
        totalSpent: coerceNumber(row.totalSpent),
        calcTotalRevenue: coerceNumber(row.calcTotalRevenue)
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
            channels AS "snapshotChannels",
            target_markets AS "snapshotMarkets",
            company_name AS "companyName"
        FROM public."PromptAdsSnapshots"
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
            "campaignId",
            name AS "channelName"
        FROM public."CampaignChannels"
        WHERE "campaignId" = ANY($1)
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
            "campaignId",
            "orders",
            "salesAmount",
            "returnsAmount",
            "adsRevenue",
            currencyd AS "currencyId"
        FROM public."salesSummary"
        WHERE "campaignId" = ANY($1)
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
            total_events AS "totalLeads",
            conversion_events AS "conversionEvents",
            ARRAY_AGG(DISTINCT channel_name) FILTER (WHERE channel_name IS NOT NULL AND TRIM(channel_name) <> '') AS "channelNames"
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id, total_events, conversion_events
    `;
    const statusQuery = `
        SELECT
            campaign_id AS "campaignId",
            COALESCE(lead_status, 'desconocido') AS "leadStatus",
            COUNT(*) AS "count"
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id, COALESCE(lead_status, 'desconocido')
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
