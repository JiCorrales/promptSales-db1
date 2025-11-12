
CREATE OR ALTER VIEW dbo.vwPromptAdsSummary
AS
WITH MetricsByAd AS (
    SELECT
        amd.AdId,
        SUM(ISNULL(amd.impressions,  0)) AS TotalImpressions,
        SUM(ISNULL(amd.clicks,       0)) AS TotalClicks,
        SUM(ISNULL(amd.interactions, 0)) AS TotalInteractions,
        SUM(ISNULL(amd.publicReach,  0)) AS TotalReach,
        SUM(ISNULL(amd.hoursViewed,  0)) AS TotalHoursViewed,
        SUM(ISNULL(amd.cost,         0)) AS TotalCost,
        SUM(ISNULL(amd.revenue,      0)) AS TotalRevenue
    FROM dbo.AdMetricsDaily amd
    GROUP BY amd.AdId
),
ChannelsByAd AS (
    SELECT
        ipa.AdId,
        STRING_AGG(DISTINCT ch.name, ', ') AS Channels
    FROM dbo.InfluencersPerAd ipa
    JOIN dbo.Influencers inf ON inf.InfluencerId = ipa.InfluencerId
    JOIN dbo.Channels ch     ON ch.ChannelId     = inf.ChannelId
    WHERE ipa.enabled = 1
    GROUP BY ipa.AdId
),
MarketsByAd AS (
    SELECT
        aa.AdId,
        STRING_AGG(DISTINCT ta.name, ', ') AS TargetMarkets
    FROM dbo.AdAudience aa
    JOIN dbo.TargetAudience ta ON ta.TargetAudienceId = aa.TargetAudienceId
    WHERE aa.enabled = 1
    GROUP BY aa.AdId
)
SELECT
    camp.CampaignId,
    camp.name        AS CampaignName, 
    camp.startDate,
    camp.endDate,
    camp.budget      AS CampaignBudget,

    comp.CompanyId,
    comp.name        AS CompanyName,

    ad.AdId,
    ad.name          AS AdName,
    ad.createdAt     AS AdCreatedAt,
    ad.enabled       AS AdEnabled,
    ast.name         AS AdStatus,
    at.name          AS AdType,

    COALESCE(chs.Channels,      'Sin canal')   AS Channels,
    COALESCE(mks.TargetMarkets, 'Sin mercado') AS TargetMarkets,

    ISNULL(m.TotalImpressions,  0) AS TotalImpressions,
    ISNULL(m.TotalClicks,       0) AS TotalClicks,
    ISNULL(m.TotalInteractions, 0) AS TotalInteractions,
    ISNULL(m.TotalReach,        0) AS TotalReach,
    ISNULL(m.TotalHoursViewed,  0) AS TotalHoursViewed,
    ISNULL(m.TotalCost,         0) AS TotalCost,
    ISNULL(m.TotalRevenue,      0) AS TotalRevenue
FROM dbo.Campaigns camp
JOIN dbo.Companies comp   ON comp.CompanyId   = camp.CompanyId
JOIN dbo.Ads ad           ON ad.CampaignId    = camp.CampaignId
JOIN dbo.AdStatus ast     ON ast.AdStatusId   = ad.AdStatusId
JOIN dbo.AdTypes  at      ON at.AdTypeId      = ad.AdTypeId
LEFT JOIN MetricsByAd  m  ON m.AdId           = ad.AdId
LEFT JOIN ChannelsByAd chs ON chs.AdId        = ad.AdId
LEFT JOIN MarketsByAd  mks ON mks.AdId        = ad.AdId;
