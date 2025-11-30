-- =============================================
-- STEP 3 (CORREGIDO FINAL V2): Generar LeadEvents alineados a PromptAds
-- Fix: Limpieza exhaustiva de tablas temporales (#NonPurchaseTypes)
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT 'Generando LeadEvents alineados a PromptAds...';
PRINT '';

-- =============================================
-- LIMPIEZA DEFENSIVA INICIAL (TODAS LAS TABLAS)
-- =============================================
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;
IF OBJECT_ID('tempdb..#PromptAdsMetrics') IS NOT NULL DROP TABLE #PromptAdsMetrics;
IF OBJECT_ID('tempdb..#PromptAdsCampaigns') IS NOT NULL DROP TABLE #PromptAdsCampaigns;
IF OBJECT_ID('tempdb..#CampaignTargets') IS NOT NULL DROP TABLE #CampaignTargets;
IF OBJECT_ID('tempdb..#LeadsCampaign') IS NOT NULL DROP TABLE #LeadsCampaign;
IF OBJECT_ID('tempdb..#EventSlots') IS NOT NULL DROP TABLE #EventSlots;
IF OBJECT_ID('tempdb..#PlannedEvents') IS NOT NULL DROP TABLE #PlannedEvents;
IF OBJECT_ID('tempdb..#NonPurchaseEventTypes') IS NOT NULL DROP TABLE #NonPurchaseEventTypes;

PRINT 'Limpieza defensiva completada.';
PRINT '';

-- =============================================
-- 1) Leads y campañas realmente usadas
-- =============================================
PRINT '>> Cargando leads por campaña...';

SELECT
    l.leadId,
    ls.campaignKey,
    ls.leadSourceId,
    ls.leadMediumId,
    ls.leadOriginChannelId,
    ls.deviceTypeId,
    ls.devicePlatformId,
    ls.browserId,
    ROW_NUMBER() OVER (PARTITION BY ls.campaignKey ORDER BY l.leadId) AS LeadRow,
    COUNT(*) OVER (PARTITION BY ls.campaignKey) AS LeadCount
INTO #LeadsCampaign
FROM [crm].[Leads] l
JOIN [crm].[LeadSources] ls ON ls.leadId = l.leadId;

DECLARE @PendingLeads BIGINT = (SELECT COUNT(*) FROM #LeadsCampaign);
PRINT '   Leads a procesar: ' + FORMAT(@PendingLeads, 'N0');

IF @PendingLeads = 0
BEGIN
    PRINT '   No hay leads para procesar. Abortando.';
    RETURN;
END

-- =============================================
-- 2) Cargar métricas PromptAds filtradas
-- =============================================
PRINT '>> Cargando métricas PromptAds filtradas...';

CREATE TABLE #PromptAdsCampaigns (
    CampaignKey VARCHAR(255),
    CampaignId BIGINT,
    startDate DATETIME2,
    endDate DATETIME2,
    DurationDays INT
);

CREATE TABLE #PromptAdsMetrics (
    CampaignId BIGINT,
    CampaignKey VARCHAR(255),
    Revenue DECIMAL(18,2),
    Impressions BIGINT
);

BEGIN TRY
    INSERT INTO #PromptAdsCampaigns (CampaignId, CampaignKey, startDate, endDate, DurationDays)
    SELECT
        c.CampaignId,
        'CAMP-' + CAST(c.CampaignId AS VARCHAR(20)) AS CampaignKey,
        c.startDate,
        c.endDate,
        DATEDIFF(DAY, c.startDate, c.endDate) AS DurationDays
    FROM OPENQUERY([PromptAds_LinkedServer], 'SELECT CampaignId, startDate, endDate FROM PromptAds.dbo.Campaigns') c
    WHERE EXISTS (SELECT 1 FROM #LeadsCampaign lc WHERE lc.campaignKey = 'CAMP-' + CAST(c.CampaignId AS VARCHAR(20)));

    INSERT INTO #PromptAdsMetrics (CampaignId, CampaignKey, Revenue, Impressions)
    SELECT
        pa.CampaignId,
        'CAMP-' + CAST(pa.CampaignId AS VARCHAR(20)) AS CampaignKey,
        SUM(ISNULL(pa.revenue,0)),
        SUM(ISNULL(pa.impressions,0))
    FROM OPENQUERY([PromptAds_LinkedServer], '
        SELECT c.CampaignId, amd.revenue, amd.impressions
        FROM PromptAds.dbo.Campaigns c
        JOIN PromptAds.dbo.Ads a ON a.CampaignId = c.CampaignId
        JOIN PromptAds.dbo.AdMetricsDaily amd ON amd.AdId = a.AdId
    ') pa
    WHERE EXISTS (SELECT 1 FROM #LeadsCampaign lc WHERE lc.campaignKey = 'CAMP-' + CAST(pa.CampaignId AS VARCHAR(20)))
    GROUP BY pa.CampaignId;
END TRY
BEGIN CATCH
    PRINT '   Error leyendo PromptAds. Continuando con métricas por defecto.';
END CATCH

DECLARE @ActiveCampaignsCount INT = (SELECT COUNT(*) FROM #PromptAdsCampaigns);
PRINT '   Campañas activas con leads: ' + FORMAT(@ActiveCampaignsCount, 'N0');

-- =============================================
-- 3) Calcular objetivos
-- =============================================
PRINT '>> Calculando objetivos por campaña...';

;WITH Base AS (
    SELECT
        c.CampaignKey,
        c.startDate,
        c.endDate,
        c.DurationDays,
        ISNULL(m.Revenue, 84000.0) AS Revenue,
        ISNULL(m.Impressions, 100000) AS Impressions,
        CASE
            WHEN ISNULL(m.Impressions,0) > 0 THEN
                LEAST(300.0, GREATEST(80.0, ISNULL(m.Revenue,84000.0)/NULLIF(m.Impressions/100.0,0)))
            ELSE 120.0
        END AS AvgTicketEstimate
    FROM #PromptAdsCampaigns c
    LEFT JOIN #PromptAdsMetrics m ON m.CampaignKey = c.CampaignKey
)
SELECT
    b.CampaignKey,
    b.startDate,
    b.endDate,
    b.DurationDays,
    b.Revenue,
    (lc.LeadCount * 12) AS TargetEventsPre
INTO #CampaignTargets
FROM Base b
JOIN (
    SELECT campaignKey, MAX(LeadCount) AS LeadCount
    FROM #LeadsCampaign
    GROUP BY campaignKey
) lc ON lc.campaignKey = b.CampaignKey;

DECLARE @TotalEventsTarget BIGINT = (SELECT SUM(TargetEventsPre) FROM #CampaignTargets);
PRINT '   Eventos objetivo total: ' + FORMAT(@TotalEventsTarget, 'N0');

-- =============================================
-- 3.1) Tally table (solo lo necesario)
-- =============================================
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;
DECLARE @TallyRows BIGINT = ISNULL(@TotalEventsTarget, 0);
IF @TallyRows < 1 SET @TallyRows = 1; -- evita TOP(0)

;WITH E1 AS (SELECT 1 AS n FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) a(n)),
      E2 AS (SELECT 1 AS n FROM E1 a CROSS JOIN E1 b),
      E4 AS (SELECT 1 AS n FROM E2 a CROSS JOIN E2 b),
      E5 AS (SELECT 1 AS n FROM E4 a CROSS JOIN E2 b),
      Numbers AS (SELECT TOP (@TallyRows) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM E5 a CROSS JOIN E2 b)
SELECT n INTO #Numbers FROM Numbers;

PRINT '   Tally rows creadas: ' + FORMAT(@TallyRows, 'N0');

-- =============================================
-- 4) Generar slots de eventos
-- =============================================
PRINT '>> Generando slots de eventos...';

;WITH CampaignRanges AS (
    SELECT
        ct.CampaignKey,
        ct.TargetEventsPre,
        ct.startDate,
        ct.endDate,
        ct.DurationDays,
        SUM(ct.TargetEventsPre) OVER (ORDER BY ct.CampaignKey) AS CumEnd,
        SUM(ct.TargetEventsPre) OVER (ORDER BY ct.CampaignKey) - ct.TargetEventsPre + 1 AS CumStart
    FROM #CampaignTargets ct
)
SELECT
    n.n AS SlotRow,
    cr.CampaignKey,
    cr.startDate,
    cr.DurationDays,
    CASE WHEN (n.n % 22) = 0 THEN 1 ELSE 0 END AS IsPurchase  -- ~4.5% PURCHASE para ~500K clientes
INTO #EventSlots
FROM #Numbers n
JOIN CampaignRanges cr ON n.n BETWEEN cr.CumStart AND cr.CumEnd
WHERE n.n <= (SELECT MAX(CumEnd) FROM CampaignRanges);

-- =============================================
-- 5) Asignar eventos a leads
-- =============================================
PRINT '>> Asignando eventos a leads...';

SELECT
    es.CampaignKey,
    es.IsPurchase,
    es.DurationDays,
    es.startDate,
    lc.leadId,
    lc.leadSourceId,
    lc.leadMediumId,
    lc.leadOriginChannelId,
    lc.deviceTypeId,
    lc.devicePlatformId,
    lc.browserId
INTO #PlannedEvents
FROM #EventSlots es
JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY campaignKey ORDER BY leadId) AS LeadRowOrdered
    FROM #LeadsCampaign
) lc ON lc.campaignKey = es.CampaignKey
    AND (((es.SlotRow - 1) % lc.LeadCount) + 1) = lc.LeadRowOrdered;

-- =============================================
-- 6) Insertar eventos
-- =============================================
PRINT '>> Insertando en [crm].[LeadEvents]...';

DECLARE @PurchaseEventTypeId INT;
SELECT TOP 1 @PurchaseEventTypeId = leadEventTypeId FROM [crm].[LeadEventTypes] WHERE eventTypeKey = 'PURCHASE';
IF @PurchaseEventTypeId IS NULL SET @PurchaseEventTypeId = 1;

-- Crear tabla temporal antes del insert para poder usarla en el subquery
IF OBJECT_ID('tempdb..#NonPurchaseTypes') IS NOT NULL DROP TABLE #NonPurchaseTypes;
SELECT leadEventTypeId INTO #NonPurchaseTypes FROM [crm].[LeadEventTypes] WHERE eventTypeKey <> 'PURCHASE';

INSERT INTO [crm].[LeadEvents] WITH (TABLOCK)
    (leadId, campaignKey, leadSourceId,
     mediumId, originChannelId,
     deviceTypeId, devicePlatformId, browserId,
     leadEventTypeId, leadEventSourceId, occurredAt, receivedAt, checksum)
SELECT
    p.leadId,
    p.campaignKey,
    p.leadSourceId,
    p.leadMediumId,
    p.leadOriginChannelId,
    p.deviceTypeId,
    p.devicePlatformId,
    p.browserId,
    CASE WHEN p.IsPurchase = 1 THEN @PurchaseEventTypeId
         ELSE (SELECT TOP 1 leadEventTypeId FROM #NonPurchaseTypes ORDER BY NEWID())
    END,
    1,
    DATEADD(MINUTE,
        ABS(CHECKSUM(NEWID()) % (1440 * (CASE WHEN p.DurationDays > 0 THEN p.DurationDays ELSE 1 END))),
        ISNULL(p.startDate, GETUTCDATE())),
    GETUTCDATE(),
    CONVERT(varchar(64), NEWID())
FROM #PlannedEvents p;

PRINT '✅ Insertados: ' + FORMAT(@@ROWCOUNT, 'N0') + ' eventos.';

-- =============================================
-- LIMPIEZA FINAL
-- =============================================
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;
IF OBJECT_ID('tempdb..#LeadsCampaign') IS NOT NULL DROP TABLE #LeadsCampaign;
IF OBJECT_ID('tempdb..#PromptAdsCampaigns') IS NOT NULL DROP TABLE #PromptAdsCampaigns;
IF OBJECT_ID('tempdb..#PromptAdsMetrics') IS NOT NULL DROP TABLE #PromptAdsMetrics;
IF OBJECT_ID('tempdb..#CampaignTargets') IS NOT NULL DROP TABLE #CampaignTargets;
IF OBJECT_ID('tempdb..#EventSlots') IS NOT NULL DROP TABLE #EventSlots;
IF OBJECT_ID('tempdb..#PlannedEvents') IS NOT NULL DROP TABLE #PlannedEvents;
IF OBJECT_ID('tempdb..#NonPurchaseEventTypes') IS NOT NULL DROP TABLE #NonPurchaseEventTypes;
GO
