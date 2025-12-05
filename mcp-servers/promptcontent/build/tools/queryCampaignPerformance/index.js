"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerQueryCampaignPerformanceTool = registerQueryCampaignPerformanceTool;
const zod_1 = require("zod");
const deriveFilters_1 = require("./ai/deriveFilters");
const client_1 = require("./db/client");
const fetch_1 = require("./db/fetch");
const format_1 = require("./utils/format");
function registerQueryCampaignPerformanceTool(server) {
    server.registerTool("queryCampaignPerformance", {
        title: "Consultar rendimiento de campañas",
        description: "Permite preguntar en lenguaje natural por el alcance, éxito, ventas, reacciones y canales usados en campañas consolidadas. El handler cruza datos de PromptAdsSnapshots, CampaignChannels, salesSummary, Campaigns, Interactions, Calculations y PromptCrmSnapshots para materializar el alcance real, tasas de conversión/engagement/ROI, ventas netas, desglose de reacciones, canales o mercados y el estado de los leads asociados. Retorna este conjunto de métricas principales, fuentes ads/CRM, tasas clave y detalles por campaña listos para que la IA los exponga o explique sin inventar cifras.",
        inputSchema: {
            question: zod_1.z
                .string()
                .min(10)
                .describe("Pregunta en lenguaje natural sobre una o varias campañas.")
        },
        outputSchema: {
            question: zod_1.z.string(),
            summary: zod_1.z.string(),
            campaigns: zod_1.z.array(zod_1.z.object({
                campaignId: zod_1.z.number(),
                campaignName: zod_1.z.string().nullable(),
                status: zod_1.z.string().nullable(),
                companyName: zod_1.z.string().nullable(),
                startDate: zod_1.z.string().nullable(),
                endDate: zod_1.z.string().nullable(),
                snapshotDate: zod_1.z.string().nullable(),
                budgetAmount: zod_1.z.number().nullable(),
                reach: zod_1.z.number().nullable(),
                impressions: zod_1.z.number().nullable(),
                clicks: zod_1.z.number().nullable(),
                interactions: zod_1.z.number().nullable(),
                hoursViewed: zod_1.z.number().nullable(),
                cost: zod_1.z.number().nullable(),
                revenue: zod_1.z.number().nullable(),
                conversionRate: zod_1.z.number().nullable(),
                engagementRate: zod_1.z.number().nullable(),
                roi: zod_1.z.number().nullable(),
                totalSpent: zod_1.z.number().nullable(),
                totalRevenue: zod_1.z.number().nullable(),
                orders: zod_1.z.number().nullable(),
                salesAmount: zod_1.z.number().nullable(),
                returnsAmount: zod_1.z.number().nullable(),
                adsRevenue: zod_1.z.number().nullable(),
                currencyId: zod_1.z.number().nullable(),
                usersReached: zod_1.z.number().nullable(),
                interactionsBreakdown: zod_1.z.object({
                    clicks: zod_1.z.number().nullable(),
                    likes: zod_1.z.number().nullable(),
                    comments: zod_1.z.number().nullable(),
                    reactions: zod_1.z.number().nullable(),
                    shares: zod_1.z.number().nullable()
                }),
                channels: zod_1.z.array(zod_1.z.string()),
                targetMarkets: zod_1.z.array(zod_1.z.string()),
                crm: zod_1.z.object({
                    totalLeads: zod_1.z.number(),
                    conversionEvents: zod_1.z.number(),
                    leadStatusCounts: zod_1.z.record(zod_1.z.number()),
                    channelNames: zod_1.z.array(zod_1.z.string())
                })
            }))
        }
    }, async ({ question }) => {
        const sanitizedQuestion = question.trim();
        try {
            const client = await (0, client_1.getPostgresClient)();
            const filters = await (0, deriveFilters_1.aiDeriveFilters)(sanitizedQuestion);
            const safeLimit = 3;
            const campaigns = await (0, fetch_1.fetchCampaignRows)(client, filters, safeLimit);
            if (campaigns.length === 0) {
                const empty = {
                    question: sanitizedQuestion,
                    summary: `No se encontraron campañas para la consulta: "${sanitizedQuestion}".`,
                    campaigns: []
                };
                return {
                    content: [{ type: "text", text: JSON.stringify(empty) }],
                    structuredContent: empty
                };
            }
            const campaignIds = campaigns.map(row => row.campaignId);
            const snapshots = await (0, fetch_1.fetchPromptAdsSnapshots)(client, campaignIds);
            const channelMap = await (0, fetch_1.fetchCampaignChannels)(client, campaignIds);
            const salesMap = await (0, fetch_1.fetchSalesSummaries)(client, campaignIds);
            const { summaryMap, statusMap } = await (0, fetch_1.fetchCrmInsights)(client, campaignIds);
            const finalCampaigns = campaigns.map(row => {
                const snapshot = snapshots.get(row.campaignId);
                const sales = salesMap.get(row.campaignId);
                const channelCandidates = [
                    ...(snapshot?.snapshotChannels ?? []),
                    ...(channelMap.get(row.campaignId) ?? [])
                ];
                const combinedChannels = Array.from(new Set(channelCandidates.filter(Boolean)));
                const targetMarkets = Array.from(new Set(snapshot?.snapshotMarkets ?? [])).filter(Boolean);
                const crmSummary = summaryMap.get(row.campaignId);
                const leadStatusCounts = statusMap.get(row.campaignId) ?? {};
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
                };
            });
            const summaryParts = [
                `Pregunta: "${sanitizedQuestion}".`,
                `Se analizaron ${finalCampaigns.length} campaña(s) relevantes.`
            ];
            const highlighted = finalCampaigns[0];
            if (highlighted) {
                summaryParts.push(`La campaña ${highlighted.campaignName ?? highlighted.campaignId} reportó alcance ${(0, format_1.formatLargeNumber)(highlighted.reach)}, tasa de éxito ${(0, format_1.formatPercent)(highlighted.conversionRate)}, ventas estimadas ${(0, format_1.formatLargeNumber)(highlighted.salesAmount)}.`);
            }
            const output = {
                question: sanitizedQuestion,
                summary: summaryParts.join(" "),
                campaigns: finalCampaigns
            };
            return {
                content: [{ type: "text", text: JSON.stringify(output) }],
                structuredContent: output
            };
        }
        catch (error) {
            console.error("[queryCampaignPerformance] error", error);
            const failed = {
                question: sanitizedQuestion,
                summary: `No fue posible responder la consulta (${error?.message || "error desconocido"}).`,
                campaigns: []
            };
            return {
                content: [{ type: "text", text: JSON.stringify(failed) }],
                structuredContent: failed
            };
        }
    });
}
