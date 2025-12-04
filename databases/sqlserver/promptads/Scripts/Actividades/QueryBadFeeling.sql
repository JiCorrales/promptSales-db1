USE PromptAds;

DECLARE @StartDate datetime = '2024-01-01';
DECLARE @EndDate   datetime = '2024-01-31';
DECLARE @BrandId   bigint   = NULL;   -- opcional: filtrar por una marca específica
DECLARE @DropMin   decimal(5,2) = 10; -- % mínimo de baja para considerar “relevante”

-- Partimos el rango en dos mitades:
--   Base:      [StartDate, MidDate)
--   Evaluada:  [MidDate,  EndDate)
DECLARE @MidDate datetime = DATEADD(SECOND,
    DATEDIFF(SECOND, @StartDate, @EndDate) / 2,
    @StartDate
);

;WITH NegFeeling AS
(
    -- Ads que, para una marca y un canal, tuvieron sentimiento NEGATIVO
    -- en algún momento del rango [StartDate, EndDate)
    SELECT
        b.BrandId,
        b.name              AS BrandName,
        a.AdId,
        ch.ChannelId,
        ch.name             AS ChannelName,
        sf.InfluencerId,
        st.SentimentTypeId,
        st.name             AS SentimentName,
        COUNT(*)            AS NegativeEvents,
        AVG(sf.feelingScore) AS AvgNegativeScore
    FROM dbo.SocialFeeling      sf
    JOIN dbo.SentimentTypes     st  ON st.SentimentTypeId = sf.SentimentTypeId
    JOIN dbo.Ads                a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns          c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands             b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd      ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels           ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @StartDate
        AND sf.posttime <  @EndDate
        AND st.name = 'Negative'
        AND (@BrandId IS NULL OR b.BrandId = @BrandId)
    GROUP BY
        b.BrandId, b.name,
        a.AdId,
        ch.ChannelId, ch.name,
        sf.InfluencerId,
        st.SentimentTypeId, st.name
),

ReaccionesBase AS
(
    -- “Reacción” base = suma de sampleSize por Ad + Influencer + Canal
    -- en la primera mitad del rango.
    SELECT
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId,
        SUM(sf.sampleSize) AS TotalBase
    FROM dbo.SocialFeeling  sf
    JOIN dbo.Ads            a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns      c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands         b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd  ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels       ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @StartDate
        AND sf.posttime <  @MidDate
        AND (@BrandId IS NULL OR b.BrandId = @BrandId)
    GROUP BY
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId
),

ReaccionesEval AS
(
    -- “Reacción” evaluada = suma de sampleSize por Ad + Influencer + Canal
    -- en la segunda mitad del rango.
    SELECT
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId,
        SUM(sf.sampleSize) AS TotalEval
    FROM dbo.SocialFeeling  sf
    JOIN dbo.Ads            a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns      c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands         b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd  ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels       ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @MidDate
        AND sf.posttime <  @EndDate
        AND (@BrandId IS NULL OR b.BrandId = @BrandId)
    GROUP BY
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId
),

Comparacion AS
(
    -- Unimos base + evaluada y calculamos % de baja por influencer y canal
    SELECT
        rb.BrandId,
        rb.AdId,
        rb.InfluencerId,
        rb.ChannelId,
        rb.TotalBase,
        ISNULL(re.TotalEval, 0) AS TotalEval,
        CASE
            WHEN rb.TotalBase > 0
            THEN CAST( (rb.TotalBase - ISNULL(re.TotalEval, 0)) * 100.0
                       / rb.TotalBase AS decimal(10,2))
            ELSE NULL
        END AS PorcBaja
    FROM ReaccionesBase rb
    LEFT JOIN ReaccionesEval re
      ON  re.BrandId      = rb.BrandId
      AND re.AdId         = rb.AdId
      AND re.InfluencerId = rb.InfluencerId
      AND re.ChannelId    = rb.ChannelId
)

SELECT
    nf.BrandId,
    nf.BrandName,
    nf.AdId,
    nf.InfluencerId,
    nf.ChannelId,
    nf.ChannelName,
    nf.SentimentName              AS TipoSentimientoNegativo,
    nf.AvgNegativeScore           AS ScorePromedioNegativo,
    cmp.TotalBase                 AS ReaccionBaseSampleSize,
    cmp.TotalEval                 AS ReaccionEvalSampleSize,
    cmp.PorcBaja                  AS PorcentajeBajaReaccion
FROM NegFeeling nf
JOIN Comparacion cmp
  ON  cmp.BrandId      = nf.BrandId
  AND cmp.AdId         = nf.AdId
  AND cmp.InfluencerId = nf.InfluencerId
  AND cmp.ChannelId    = nf.ChannelId
WHERE
    cmp.PorcBaja IS NOT NULL
    AND cmp.PorcBaja > @DropMin          -- solo donde realmente hay baja
ORDER BY
    nf.BrandName,
    cmp.PorcBaja DESC;
