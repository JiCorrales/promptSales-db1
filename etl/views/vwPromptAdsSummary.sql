
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
        STRING_AGG( ch.name, ', ') AS Channels
    FROM dbo.InfluencersPerAd ipa
    JOIN dbo.Influencers inf ON inf.InfluencerId = ipa.InfluencerId
    JOIN dbo.Channels ch     ON ch.ChannelId     = inf.ChannelId
    WHERE ipa.enabled = 1
    GROUP BY ipa.AdId
),
MarketsByAd AS (
    SELECT
        aa.AdId,
        STRING_AGG( ta.name, ', ') AS TargetMarkets
    FROM dbo.AdAudience aa
    JOIN dbo.TargetAudience ta ON ta.TargetAudienceId = aa.TargetAudienceId
    WHERE aa.enabled = 1
    GROUP BY aa.AdId
),
CurrencyByAd AS (
    SELECT
        ct.AdId,
        STRING_AGG(DISTINCT cur.isoCode, ', ') AS CurrencyIsoCodes,
        STRING_AGG(DISTINCT cur.name, ', ')    AS CurrencyNames
    FROM dbo.CampaignTransactions ct
    JOIN dbo.Payments    pay ON pay.PaymentId   = ct.PaymentId
    JOIN dbo.Currencies  cur ON cur.CurrencyId  = pay.CurrencyId
    GROUP BY ct.AdId
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
    ctry.name       AS Country,
    crrcy.name      AS Currency,

    COALESCE(chs.Channels,      'Sin canal')   AS Channels,
    COALESCE(mks.TargetMarkets, 'Sin mercado') AS TargetMarkets,
    COALESCE(cur.CurrencyIsoCodes, 'Sin moneda') AS CurrencyCodes,
    COALESCE(cur.CurrencyNames,    'Sin moneda') AS CurrencyNames,
    COALESCE(cc.CountryName,       'Sin país')   AS CompanyCountry,
    cc.CountryId                                   AS CompanyCountryId,

    ISNULL(m.TotalImpressions,  0) AS TotalImpressions,
    ISNULL(m.TotalClicks,       0) AS TotalClicks,
    ISNULL(m.TotalInteractions, 0) AS TotalInteractions,
    ISNULL(m.TotalReach,        0) AS TotalReach,
    ISNULL(m.TotalHoursViewed,  0) AS TotalHoursViewed,
    ISNULL(m.TotalCost,         0) AS TotalCost,
    ISNULL(m.TotalRevenue,      0) AS TotalRevenue
FROM dbo.Campaigns camp
JOIN dbo.Companies comp    ON comp.CompanyId   = camp.CompanyId
JOIN dbo.Ads ad            ON ad.CampaignId    = camp.CampaignId
JOIN dbo.AdStatus ast      ON ast.AdStatusId   = ad.AdStatusId
JOIN dbo.AdTypes  at       ON at.AdTypeId      = ad.AdTypeId
JOIN dbo.Countries ctry    ON ctry.CountryId   = ad.CountryId
JOIN dbo.Currencies crrcy   ON crrcy.CurrencyId = ad.CurrencyId
LEFT JOIN MetricsByAd  m   ON m.AdId           = ad.AdId
LEFT JOIN ChannelsByAd chs ON chs.AdId         = ad.AdId
LEFT JOIN MarketsByAd  mks ON mks.AdId         = ad.AdId
LEFT JOIN CurrencyByAd cur ON cur.AdId         = ad.AdId
OUTER APPLY (
    SELECT TOP 1
        ctr.CountryId,
        ctr.name AS CountryName
    FROM dbo.CompanyAddresses ca
    JOIN dbo.Addresses addr ON addr.AddressId = ca.AddressId
    JOIN dbo.Cities    ci   ON ci.CityId      = addr.CityId
    JOIN dbo.States    st   ON st.StateId     = ci.StateId
    JOIN dbo.Countries ctr  ON ctr.CountryId  = st.CountryId
    WHERE ca.CompanyId = comp.CompanyId
    ORDER BY ca.isPrimary DESC, ca.CompanyAddressId
) cc
WHERE ISNULL(ad.processed, '') <> 'procesado';
