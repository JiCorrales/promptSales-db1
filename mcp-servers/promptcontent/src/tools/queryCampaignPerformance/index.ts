import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { z } from "zod"
import { aiDeriveFilters } from "./ai/deriveFilters"
import { getPostgresClient } from "./db/client"
import {
    fetchCampaignChannels,
    fetchCampaignRows,
    fetchCrmInsights,
    fetchPromptAdsSnapshots,
    fetchSalesSummaries
} from "./db/fetch"
import { formatLargeNumber, formatPercent } from "./utils/format"

export function registerQueryCampaignPerformanceTool(server: McpServer) {
    server.registerTool(
        "queryCampaignPerformance",
        {
            title: "Consultar rendimiento de campañas",
            description:
               "Permite preguntar en lenguaje natural por el alcance, éxito, ventas, reacciones y canales usados en campañas consolidadas. El handler cruza datos de PromptAdsSnapshots, CampaignChannels, salesSummary, Campaigns, Interactions, Calculations y PromptCrmSnapshots para materializar el alcance real, tasas de conversión/engagement/ROI, ventas netas, desglose de reacciones, canales o mercados y el estado de los leads asociados. Retorna este conjunto de métricas principales, fuentes ads/CRM, tasas clave y detalles por campaña listos para que la IA los exponga o explique sin inventar cifras.",
            inputSchema: {
                question: z
                    .string()
                    .min(10)
                    .describe("Pregunta en lenguaje natural sobre una o varias campañas.")
            },
            outputSchema: {
                question: z.string(),
                summary: z.string(),
                campaigns: z.array(
                    z.object({
                        campaignId: z.number(),
                        campaignName: z.string().nullable(),
                        status: z.string().nullable(),
                        companyName: z.string().nullable(),
                        startDate: z.string().nullable(),
                        endDate: z.string().nullable(),
                        snapshotDate: z.string().nullable(),
                        budgetAmount: z.number().nullable(),
                        reach: z.number().nullable(),
                        impressions: z.number().nullable(),
                        clicks: z.number().nullable(),
                        interactions: z.number().nullable(),
                        hoursViewed: z.number().nullable(),
                        cost: z.number().nullable(),
                        revenue: z.number().nullable(),
                        conversionRate: z.number().nullable(),
                        engagementRate: z.number().nullable(),
                        roi: z.number().nullable(),
                        totalSpent: z.number().nullable(),
                        totalRevenue: z.number().nullable(),
                        orders: z.number().nullable(),
                        salesAmount: z.number().nullable(),
                        returnsAmount: z.number().nullable(),
                        adsRevenue: z.number().nullable(),
                        currencyId: z.number().nullable(),
                        usersReached: z.number().nullable(),
                        interactionsBreakdown: z.object({
                            clicks: z.number().nullable(),
                            likes: z.number().nullable(),
                            comments: z.number().nullable(),
                            reactions: z.number().nullable(),
                            shares: z.number().nullable()
                        }),
                        channels: z.array(z.string()),
                        targetMarkets: z.array(z.string()),
                        crm: z.object({
                            totalLeads: z.number(),
                            conversionEvents: z.number(),
                            leadStatusCounts: z.record(z.number()),
                            channelNames: z.array(z.string())
                        })
                    })
                )
            }
        },
        async ({ question }) => {
            const sanitizedQuestion = question.trim()
            try {
                const client = await getPostgresClient()
                const filters = await aiDeriveFilters(sanitizedQuestion)
                const safeLimit = 3
                const campaigns = await fetchCampaignRows(client, filters, safeLimit)
                if (campaigns.length === 0) {
                    const empty = {
                        question: sanitizedQuestion,
                        summary: `No se encontraron campañas para la consulta: "${sanitizedQuestion}".`,
                        campaigns: []
                    }
                    return {
                        content: [{ type: "text", text: JSON.stringify(empty) }],
                        structuredContent: empty
                    }
                }
                const campaignIds = campaigns.map(row => row.campaignId)
                const snapshots = await fetchPromptAdsSnapshots(client, campaignIds)
                const channelMap = await fetchCampaignChannels(client, campaignIds)
                const salesMap = await fetchSalesSummaries(client, campaignIds)
                const { summaryMap, statusMap } = await fetchCrmInsights(client, campaignIds)
                const finalCampaigns = campaigns.map(row => {
                    const snapshot = snapshots.get(row.campaignId)
                    const sales = salesMap.get(row.campaignId)
                    const channelCandidates = [
                        ...(snapshot?.snapshotChannels ?? []),
                        ...(channelMap.get(row.campaignId) ?? [])
                    ]
                    const combinedChannels = Array.from(new Set(channelCandidates.filter(Boolean)))
                    const targetMarkets = Array.from(new Set(snapshot?.snapshotMarkets ?? [])).filter(Boolean)
                    const crmSummary = summaryMap.get(row.campaignId)
                    const leadStatusCounts = statusMap.get(row.campaignId) ?? {}
                    return {
                        campaignId: row.campaignId,
                        campaignName: row.campaignName,
                        status: row.status,
                        companyName: snapshot?.companyName ?? row.companyName,
                        startDate: row.startDate,
                        endDate: row.endDate,
                        snapshotDate: snapshot?.snapshotDate ?? null,
                        budgetAmount: row.budgetAmount ?? snapshot?.campaignBudget ?? null,
                        reach: snapshot?.totalReach ?? null,
                        impressions: snapshot?.totalImpressions ?? null,
                        clicks: snapshot?.totalClicks ?? null,
                        interactions: snapshot?.totalInteractions ?? null,
                        hoursViewed: snapshot?.totalHoursViewed ?? null,
                        cost: snapshot?.totalCost ?? null,
                        revenue: snapshot?.totalRevenue ?? null,
                        conversionRate: row.conversionRate,
                        engagementRate: row.engagementRate,
                        roi: row.roi,
                        totalSpent: row.totalSpent,
                        totalRevenue: row.calcTotalRevenue,
                        orders: sales?.orders ?? null,
                        salesAmount: sales?.salesAmount ?? null,
                        returnsAmount: sales?.returnsAmount ?? null,
                        adsRevenue: sales?.adsRevenue ?? snapshot?.totalRevenue ?? null,
                        currencyId: sales?.currencyId ?? null,
                        usersReached: row.interactions.usersReached,
                        interactionsBreakdown: {
                            clicks: row.interactions.clicks,
                            likes: row.interactions.likes,
                            comments: row.interactions.comments,
                            reactions: row.interactions.reactions,
                            shares: row.interactions.shares
                        },
                        channels: combinedChannels,
                        targetMarkets,
                        crm: {
                            totalLeads: crmSummary?.totalLeads ?? 0,
                            conversionEvents: crmSummary?.conversionEvents ?? 0,
                            leadStatusCounts,
                            channelNames: crmSummary?.channelNames ?? []
                        }
                    }
                })
                const summaryParts = [
                    `Pregunta: "${sanitizedQuestion}".`,
                    `Se analizaron ${finalCampaigns.length} campaña(s) relevantes.`
                ]
                const highlighted = finalCampaigns[0]
                if (highlighted) {
                    summaryParts.push(
                        `La campaña ${highlighted.campaignName ?? highlighted.campaignId} reportó alcance ${formatLargeNumber(
                            highlighted.reach
                        )}, tasa de éxito ${formatPercent(highlighted.conversionRate)}, ventas estimadas ${formatLargeNumber(
                            highlighted.salesAmount
                        )}.`
                    )
                }
                const output = {
                    question: sanitizedQuestion,
                    summary: summaryParts.join(" "),
                    campaigns: finalCampaigns
                }
                return {
                    content: [{ type: "text", text: JSON.stringify(output) }],
                    structuredContent: output
                }
            } catch (error: any) {
                console.error("[queryCampaignPerformance] error", error)
                const failed = {
                    question: sanitizedQuestion,
                    summary: `No fue posible responder la consulta (${error?.message || "error desconocido"}).`,
                    campaigns: []
                }
                return {
                    content: [{ type: "text", text: JSON.stringify(failed) }],
                    structuredContent: failed
                }
            }
        }
    )
}
