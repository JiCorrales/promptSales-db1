USE PromptAds;
GO

/* -----------------------------------------------------------
   PARÁMETROS DE ENTRADA
   ----------------------------------------------------------- */

DECLARE @StartDate datetime = '2024-01-01';   -- Fecha de inicio del análisis
DECLARE @EndDate   datetime = '2024-01-31';  -- Fecha de fin del análisis
DECLARE @BrandId   bigint   = NULL;          -- Opcional: si se indica, filtra por UNA marca
DECLARE @DropMin   decimal(5,2) = 10;        -- % mínimo de baja para considerar que es relevante

/* -----------------------------------------------------------
   PARTIR EL RANGO EN DOS MITADES
   - Base:     [StartDate, MidDate)
   - Evaluada: [MidDate,  EndDate)
   comparar "antes" vs "después" dentro del mismo rango
   ----------------------------------------------------------- */

DECLARE @MidDate datetime = DATEADD(SECOND,
    DATEDIFF(SECOND, @StartDate, @EndDate) / 2,  -- mitad del intervalo en segundos
    @StartDate
);

/* 
   CTE 1: NegFeeling
   Objetivo:
     - Encontrar Ads que:
         * pertenecen a una marca,
         * aparecen en un canal,
         * tienen registros de SocialFeeling con sentimiento NEGATIVO
           en el rango completo [StartDate, EndDate).
     - Guardar:
         * Marca, Anuncio, Canal, Influencer,
         * Tipo de sentimiento, promedio del feelingScore,
         * conteo de eventos negativos.
*/
;WITH NegFeeling AS
(
    SELECT
        b.BrandId,
        b.name              AS BrandName,      -- Nombre de la marca
        a.AdId,                                 -- Anuncio
        ch.ChannelId,
        ch.name             AS ChannelName,    -- Nombre del canal (Facebook, etc.)
        sf.InfluencerId,                       -- Influencer asociado
        st.SentimentTypeId,
        st.name             AS SentimentName,  -- Nombre del tipo de sentimiento (ej. 'Negative')
        COUNT(*)            AS NegativeEvents, -- Cuántos registros negativos hubo
        AVG(sf.feelingScore) AS AvgNegativeScore -- Promedio del score negativo
    FROM dbo.SocialFeeling      sf
    JOIN dbo.SentimentTypes     st  ON st.SentimentTypeId = sf.SentimentTypeId
    JOIN dbo.Ads                a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns          c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands             b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd      ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels           ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @StartDate           -- Solo dentro del rango de fechas de análisis
        AND sf.posttime <  @EndDate
        AND st.name = 'Negative'           -- SOLO sentimientos negativos
        AND (@BrandId IS NULL OR b.BrandId = @BrandId) -- Si @BrandId tiene valor, filtra esa marca
    GROUP BY
        b.BrandId, b.name,
        a.AdId,
        ch.ChannelId, ch.name,
        sf.InfluencerId,
        st.SentimentTypeId, st.name
),

/* 
   CTE 2: ReaccionesBase
   Objetivo:
     - Medir el "nivel de reacción" BASE (antes) en la primera
       mitad del rango de fechas:
          [StartDate, MidDate)
     - proxy de reacción = SUM(sampleSize)
     - Agrupar por:
         Marca, Anuncio, Influencer, Canal
*/
ReaccionesBase AS
(
    SELECT
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId,
        SUM(sf.sampleSize) AS TotalBase       -- Volumen de reacción en la mitad base
    FROM dbo.SocialFeeling  sf
    JOIN dbo.Ads            a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns      c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands         b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd  ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels       ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @StartDate
        AND sf.posttime <  @MidDate          -- Primera mitad del rango
        AND (@BrandId IS NULL OR b.BrandId = @BrandId)
    GROUP BY
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId
),

/* 
   CTE 3: ReaccionesEval
   Objetivo:
     - Medir el "nivel de reacción" EVALUADO (después) en la
       segunda mitad del rango de fechas:
          [MidDate, EndDate)
     - Igual que ReaccionesBase, pero en el período posterior.
*/
ReaccionesEval AS
(
    SELECT
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId,
        SUM(sf.sampleSize) AS TotalEval       -- Volumen de reacción en la mitad evaluada
    FROM dbo.SocialFeeling  sf
    JOIN dbo.Ads            a   ON a.AdId = sf.AdId
    JOIN dbo.Campaigns      c   ON c.CampaignId = a.CampaignId
    JOIN dbo.Brands         b   ON b.BrandId = c.BrandId
    JOIN dbo.ChannelsPerAd  ca  ON ca.AdId = a.AdId
    JOIN dbo.Channels       ch  ON ch.ChannelId = ca.ChannelId
    WHERE
        sf.posttime >= @MidDate              -- Segunda mitad del rango
        AND sf.posttime <  @EndDate
        AND (@BrandId IS NULL OR b.BrandId = @BrandId)
    GROUP BY
        b.BrandId,
        a.AdId,
        sf.InfluencerId,
        ch.ChannelId
),

/*
   CTE 4: Comparacion
   Objetivo:
     - Unir ReaccionesBase y ReaccionesEval por:
         BrandId, AdId, InfluencerId, ChannelId
     - Calcular el porcentaje de BAJA de reacciones:
         PorcBaja = (Base - Eval) / Base * 100
     - Si no hay datos en la segunda mitad:
         TotalEval se toma como 0.
*/
Comparacion AS
(
    SELECT
        rb.BrandId,
        rb.AdId,
        rb.InfluencerId,
        rb.ChannelId,
        rb.TotalBase,
        ISNULL(re.TotalEval, 0) AS TotalEval, -- Si no hubo reacciones en la segunda mitad, se considera 0
        CASE
            WHEN rb.TotalBase > 0
            THEN CAST( (rb.TotalBase - ISNULL(re.TotalEval, 0)) * 100.0
                       / rb.TotalBase AS decimal(10,2))
            ELSE NULL
        END AS PorcBaja                       -- % de baja de reacciones
    FROM ReaccionesBase rb
    LEFT JOIN ReaccionesEval re
      ON  re.BrandId      = rb.BrandId
      AND re.AdId         = rb.AdId
      AND re.InfluencerId = rb.InfluencerId
      AND re.ChannelId    = rb.ChannelId
)

/* 
   SELECT FINAL
   Objetivo:
     - Devolver SOLO aquellos Ads (por marca, canal, influencer)
       que cumplen dos condiciones:

       1) Tienen sentimiento NEGATIVO (NegFeeling)
       2) Tienen una BAJA de reacciones mayor a @DropMin (%)

     - Campos que se devuelven:
       * Marca (id, nombre)
       * AdId
       * Influencer
       * Canal (id, nombre)
       * Tipo de sentimiento (Negative)
       * Score promedio negativo
       * Reacción base (sampleSize)
       * Reacción evaluada (sampleSize)
       * % de baja
*/
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
    AND cmp.PorcBaja > @DropMin          -- Solo reportar casos donde la baja de reacción es "significativa"
ORDER BY
    nf.BrandName,
    cmp.PorcBaja DESC;                   -- Ordenar por % de baja (mayores problemas primero)
