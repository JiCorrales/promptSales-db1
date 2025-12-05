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

export async function fetchCampaignRows(client: Client, filters: Filters, limit: number) {
    const conditions: string[] = []
    const params: any[] = []
    if (filters.campaignId) {
        conditions.push("c.campaign_id = $1")
        params.push(filters.campaignId)
    }
    if (filters.companyId) {
        conditions.push(`c.company_id = $${params.length + 1}`)
        params.push(filters.companyId)
    }
    if (filters.countryId) {
        conditions.push(`c.country_id = $${params.length + 1}`)
        params.push(filters.countryId)
    }
    if (filters.startDateFrom) {
        conditions.push(`c.start_date >= $${params.length + 1}`)
        params.push(filters.startDateFrom)
    }
    if (filters.startDateTo) {
        conditions.push(`c.start_date <= $${params.length + 1}`)
        params.push(filters.startDateTo)
    }
    if (filters.status) {
        conditions.push(`c.status = $${params.length + 1}`)
        params.push(filters.status)
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : ""
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
    `
    params.push(limit)
    const result: QueryResult<CampaignRow> = await client.query(query, params)
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
    }))
}

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
            snapshot_channels AS "snapshotChannels",
            snapshot_markets AS "snapshotMarkets",
            company_name AS "companyName"
        FROM prompt_ads_snapshots
        WHERE campaign_id = ANY($1)
    `
    const result: QueryResult<PromptAdsSnapshot> = await client.query(query, [campaignIds])
    const map = new Map<number, PromptAdsSnapshot>()
    for (const row of result.rows) {
        map.set(row.campaignId, row)
    }
    return map
}

export async function fetchCampaignChannels(client: Client, campaignIds: number[]) {
    const query = `
        SELECT
            campaign_id AS "campaignId",
            channel_name AS "channelName"
        FROM campaign_channels
        WHERE campaign_id = ANY($1)
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

export async function fetchSalesSummaries(client: Client, campaignIds: number[]) {
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
    `
    const result: QueryResult<SalesSummaryRow> = await client.query(query, [campaignIds])
    const map = new Map<number, SalesSummaryRow>()
    for (const row of result.rows) {
        map.set(row.campaignId, row)
    }
    return map
}

export async function fetchCrmInsights(client: Client, campaignIds: number[]) {
    const summaryQuery = `
        SELECT
            campaign_id AS "campaignId",
            total_leads AS "totalLeads",
            conversion_events AS "conversionEvents",
            channel_names AS "channelNames"
        FROM prompt_crm_snapshots
        WHERE campaign_id = ANY($1)
    `
    const statusQuery = `
        SELECT
            campaign_id AS "campaignId",
            lead_status AS "leadStatus",
            count
        FROM prompt_crm_status
        WHERE campaign_id = ANY($1)
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
