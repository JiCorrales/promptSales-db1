export type CampaignInteractions = {
    clicks: number | null
    likes: number | null
    comments: number | null
    reactions: number | null
    shares: number | null
    usersReached: number | null
}

export type CampaignRow = {
    campaignId: number
    campaignName: string | null
    status: string | null
    companyName: string | null
    startDate: string | null
    endDate: string | null
    budgetAmount?: number | null
    clicks?: number | null
    likes?: number | null
    comments?: number | null
    reactions?: number | null
    shares?: number | null
    usersReached?: number | null
    interactions: CampaignInteractions
    conversionRate: number | null
    engagementRate: number | null
    roi: number | null
    totalSpent: number | null
    calcTotalRevenue: number | null
}

export type PromptAdsSnapshot = {
    campaignId: number
    campaignBudget: number | null
    snapshotDate: string | null
    totalReach: number | null
    totalImpressions: number | null
    totalClicks: number | null
    totalInteractions: number | null
    totalHoursViewed: number | null
    totalCost: number | null
    totalRevenue: number | null
    snapshotChannels: string[] | null
    snapshotMarkets: string[] | null
    companyName: string | null
}

export type CampaignChannelRow = {
    campaignId: number
    channelName: string
}

export type SalesSummaryRow = {
    campaignId: number
    orders: number | null
    salesAmount: number | null
    returnsAmount: number | null
    adsRevenue: number | null
    currencyId: number | null
}

export type CrmSummaryRow = {
    campaignId: number
    totalLeads: number
    conversionEvents: number
    channelNames: string[]
}

export type CrmStatusRow = {
    campaignId: number
    leadStatus: string
    count: number
}

export type Filters = {
    campaignId?: number | null
    companyId?: number | null
    countryId?: number | null
    startDateFrom?: string | null
    startDateTo?: string | null
    status?: string | null
}
