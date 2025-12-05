import { Client, QueryResult } from "pg"
import {
    CampaignChannelRow,
    CampaignRow,
    CrmStatusRow,
    CrmSummaryRow,
    Filters,
    PromptAdsSnapshot,
    SalesSummaryRow
} from "../utils/types"

/**
 * This TypeScript function fetches campaign rows based on specified filters and returns the results in
 * a structured format.
 * @param {Client} client - The `client` parameter in the `fetchCampaignRows` function is expected to
 * be an instance of a database client that allows you to execute queries against a database. This
 * client is used to interact with the database and retrieve the campaign rows based on the provided
 * filters and limit.
 * @param {Filters} filters - The `fetchCampaignRows` function you provided is used to fetch campaign
 * data based on the specified filters and limit. The filters object contains the following properties:
 * @param {number} limit - The `limit` parameter in the `fetchCampaignRows` function specifies the
 * maximum number of campaign rows to retrieve from the database. It is used to limit the number of
 * results returned by the query. The function will return at most `limit` number of campaign rows
 * based on the specified filters and conditions
 * @returns The `fetchCampaignRows` function returns an array of objects representing campaign rows
 * with specific properties such as campaignId, campaignName, status, companyName, startDate, endDate,
 * budgetAmount, ROI, totalSpent, calcTotalRevenue, interactions (clicks, likes, comments, reactions,
 * shares, usersReached), conversionRate, and engagementRate. The function fetches this data from the
 * database based
 */
export async function fetchCampaignRows(client: Client, filters: Filters, limit: number) {
    const coerceNumber = (value: any) => {
        const n = typeof value === "string" || typeof value === "number" ? Number(value) : null
        return Number.isFinite(n) ? n : null
    }
    const toIsoOrNull = (value: any) => {
        if (value === null || value === undefined) return null
        const d = value instanceof Date ? value : new Date(value)
        return Number.isFinite(d.getTime()) ? d.toISOString() : null
    }

    const conditions: string[] = []
    const params: any[] = []
    if (filters.campaignId) {
        conditions.push(`c."campaignId" = $1`)
        params.push(filters.campaignId)
    }
    if (filters.companyId) {
        conditions.push(`c."companyId" = $${params.length + 1}`)
        params.push(filters.companyId)
    }
    // countryId no existe en Campaigns; se ignora si no viene
    if (filters.startDateFrom) {
        conditions.push(`c."startDate" >= $${params.length + 1}`)
        params.push(filters.startDateFrom)
    }
    if (filters.startDateTo) {
        conditions.push(`c."startDate" <= $${params.length + 1}`)
        params.push(filters.startDateTo)
    }
    if (filters.status) {
        conditions.push(`c."status" = $${params.length + 1}`)
        params.push(filters.status)
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : ""
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
    `
    params.push(limit)
    const result: QueryResult<CampaignRow> = await client.query(query, params)
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
    }))
}

/**
 * The function fetches PromptAdsSnapshots data for specified campaign IDs from a database and returns
 * it as a map.
 * @param {Client} client - The `client` parameter in the `fetchPromptAdsSnapshots` function is
 * typically an instance of a database client that allows you to interact with a database. It is used
 * to execute the SQL query defined in the function and retrieve the results from the database. The
 * specific type of client being used here
 * @param {number[]} campaignIds - CampaignIds is an array of numbers representing the IDs of the
 * campaigns for which you want to fetch prompt ads snapshots.
 * @returns A Map containing PromptAdsSnapshot objects with campaignId as the key.
 */
export async function fetchPromptAdsSnapshots(client: Client, campaignIds: number[]) {
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
    `
    const result: QueryResult<PromptAdsSnapshot> = await client.query(query, [campaignIds])
    const map = new Map<number, PromptAdsSnapshot>()
    for (const row of result.rows) {
        map.set(row.campaignId, row)
    }
    return map
}

/**
 * The fetchCampaignChannels function retrieves campaign channels for the specified campaign IDs from a
 * database and organizes them into a map.
 * @param {Client} client - The `client` parameter in the `fetchCampaignChannels` function is typically
 * an instance of a database client that allows you to interact with a database. It is used to execute
 * queries against the database and retrieve results. In this case, it seems to be of type `Client`,
 * which is likely a
 * @param {number[]} campaignIds - CampaignIds is an array of numbers representing the IDs of the
 * campaigns for which you want to fetch the associated channels.
 * @returns The `fetchCampaignChannels` function returns a `Map<number, string[]>` where the keys are
 * campaign IDs (numbers) and the values are arrays of channel names (strings) associated with each
 * campaign ID.
 */
export async function fetchCampaignChannels(client: Client, campaignIds: number[]) {
    const query = `
        SELECT
            "campaignId",
            name AS "channelName"
        FROM public."CampaignChannels"
        WHERE "campaignId" = ANY($1)
    `
    const result: QueryResult<CampaignChannelRow> = await client.query(query, [campaignIds])
    const map = new Map<number, string[]>()
    for (const row of result.rows) {
        const list = map.get(row.campaignId) || []
        list.push(row.channelName)
        map.set(row.campaignId, list)
    }
    return map
}

/**
 * This TypeScript function fetches sales summaries for specified campaign IDs from a database table
 * and returns the results in a map.
 * @param {Client} client - The `client` parameter in the `fetchSalesSummaries` function is typically
 * an instance of a database client that allows you to interact with a database. It is used to execute
 * the SQL query against the database to fetch sales summaries for the specified campaign IDs. The
 * specific type of `Client` may
 * @param {number[]} campaignIds - The `campaignIds` parameter is an array of numbers representing the
 * IDs of the campaigns for which you want to fetch sales summaries.
 * @returns A Map containing sales summaries for the specified campaign IDs is being returned.
 */
export async function fetchSalesSummaries(client: Client, campaignIds: number[]) {
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
    `
    const result: QueryResult<SalesSummaryRow> = await client.query(query, [campaignIds])
    const map = new Map<number, SalesSummaryRow>()
    for (const row of result.rows) {
        map.set(row.campaignId, row)
    }
    return map
}

/**
 * The function fetches CRM insights for specified campaign IDs and returns summary and status data in
 * maps.
 * @param {Client} client - The `client` parameter in the `fetchCrmInsights` function is typically an
 * instance of a database client that allows you to interact with a database. It is used to execute
 * queries against the database to retrieve information based on the provided `campaignIds`.
 * @param {number[]} campaignIds - CampaignIds is an array of numbers representing the IDs of the
 * campaigns for which you want to fetch CRM insights. This function fetches CRM insights such as total
 * leads, conversion events, channel names, lead statuses, and their counts for the specified campaign
 * IDs from a database table named "PromptCrmSnap
 * @returns The `fetchCrmInsights` function returns an object containing two maps: `summaryMap` and
 * `statusMap`.
 */
export async function fetchCrmInsights(client: Client, campaignIds: number[]) {
    const summaryQuery = `
        SELECT
            campaign_id AS "campaignId",
            total_events AS "totalLeads",
            conversion_events AS "conversionEvents",
            ARRAY_AGG(DISTINCT channel_name) FILTER (WHERE channel_name IS NOT NULL AND TRIM(channel_name) <> '') AS "channelNames"
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id, total_events, conversion_events
    `
    const statusQuery = `
        SELECT
            campaign_id AS "campaignId",
            COALESCE(lead_status, 'desconocido') AS "leadStatus",
            COUNT(*) AS "count"
        FROM public."PromptCrmSnapshots"
        WHERE campaign_id = ANY($1)
        GROUP BY campaign_id, COALESCE(lead_status, 'desconocido')
    `

    const [summaryResult, statusResult]: [QueryResult<CrmSummaryRow>, QueryResult<CrmStatusRow>] = await Promise.all([
        client.query(summaryQuery, [campaignIds]),
        client.query(statusQuery, [campaignIds])
    ])

    const summaryMap = new Map<number, CrmSummaryRow>()
    for (const row of summaryResult.rows) {
        summaryMap.set(row.campaignId, row)
    }

    const statusMap = new Map<number, Record<string, number>>()
    for (const row of statusResult.rows) {
        const map = statusMap.get(row.campaignId) || {}
        map[row.leadStatus] = row.count
        statusMap.set(row.campaignId, map)
    }

    return { summaryMap, statusMap }
}
