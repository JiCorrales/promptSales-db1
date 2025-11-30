-- =============================================
-- STEP 4: Generar LeadConversions alineadas a PromptAds
-- Objetivos:
--   - 400-1000 clientes por campana (TargetClients)
--   - Total clientes >= 500k
--   - Suma de conversionValue por campana = revenue de PromptAds (o fallback)
--   - Solo eventos PURCHASE -> conversiones
--   - Sin cifrado (pendiente)
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT 'Generando LeadConversions alineadas a PromptAds (clientes 400-1000 por campana)...';
PRINT '';

-- =============================================
-- Limpieza defensiva de temp tables si el script fallo antes
-- =============================================
IF OBJECT_ID('tempdb..#PromptAdsMetrics') IS NOT NULL DROP TABLE #PromptAdsMetrics;
IF OBJECT_ID('tempdb..#CampaignTargets') IS NOT NULL DROP TABLE #CampaignTargets;
IF OBJECT_ID('tempdb..#PurchaseEvents') IS NOT NULL DROP TABLE #PurchaseEvents;
IF OBJECT_ID('tempdb..#Conversions') IS NOT NULL DROP TABLE #Conversions;
IF OBJECT_ID('tempdb..#InsertedConversions') IS NOT NULL DROP TABLE #InsertedConversions;

-- =============================================
-- CONFIGURACION
-- =============================================
DECLARE @PurchaseConversionTypeId INT;
DECLARE @USDCurrencyId INT;

SELECT TOP 1 @PurchaseConversionTypeId = leadConversionTypeId
FROM [crm].[LeadConversionTypes]
WHERE leadConversionKey = 'PURCHASE' AND enabled = 1;
IF @PurchaseConversionTypeId IS NULL SET @PurchaseConversionTypeId = 3;

SELECT TOP 1 @USDCurrencyId = currencyId
FROM [crm].[Currencies]
WHERE currencyCode = 'USD' AND enabled = 1;
IF @USDCurrencyId IS NULL SET @USDCurrencyId = 1;

PRINT '  - ConversionType PURCHASE=' + CAST(@PurchaseConversionTypeId AS VARCHAR(10)) + '  Currency USD=' + CAST(@USDCurrencyId AS VARCHAR(10));
PRINT '';

-- =============================================
-- Metricas PromptAds (revenue/impressions) via linked server
-- =============================================
IF OBJECT_ID('tempdb..#PromptAdsMetrics') IS NOT NULL DROP TABLE #PromptAdsMetrics;

-- Crear la tabla primero para evitar errores "ya existe" cuando falla el SELECT INTO
CREATE TABLE #PromptAdsMetrics (
    CampaignId BIGINT NULL,
    CampaignKey VARCHAR(255) NULL,
    Revenue DECIMAL(18,2) NULL,
    Impressions BIGINT NULL,
    FirstMetricAt DATETIME2 NULL,
    LastMetricAt DATETIME2 NULL
);

BEGIN TRY
    INSERT INTO #PromptAdsMetrics (CampaignId, CampaignKey, Revenue, Impressions, FirstMetricAt, LastMetricAt)
    SELECT
        pa.CampaignId,
        'CAMP-' + CAST(pa.CampaignId AS VARCHAR(20)) AS CampaignKey,
        SUM(ISNULL(pa.revenue,0)) AS Revenue,
        SUM(ISNULL(pa.impressions,0)) AS Impressions,
        MIN(pa.posttime) AS FirstMetricAt,
        MAX(pa.posttime) AS LastMetricAt
    FROM OPENQUERY([PromptAds_LinkedServer], '
        SELECT c.CampaignId, amd.revenue, amd.impressions, amd.posttime
        FROM PromptAds.dbo.Campaigns c
        JOIN PromptAds.dbo.Ads a ON a.CampaignId = c.CampaignId
        JOIN PromptAds.dbo.AdMetricsDaily amd ON amd.AdId = a.AdId
    ') pa
    GROUP BY pa.CampaignId;
END TRY
BEGIN CATCH
    PRINT '  ERROR: No se pudo leer metricas de PromptAds: ' + ERROR_MESSAGE();
    TRUNCATE TABLE #PromptAdsMetrics; -- deja la estructura vacía
END CATCH

DECLARE @MetricsCount INT = (SELECT COUNT(*) FROM #PromptAdsMetrics);
IF @MetricsCount = 0
    PRINT '  WARN: Sin metricas PromptAds; se usaran valores por defecto.';
ELSE
    PRINT '  - Metricas PromptAds cargadas: ' + CAST(@MetricsCount AS VARCHAR(10)) + ' campanas';
PRINT '';

-- =============================================
-- Objetivos por campana (TargetClients 400-1000; TargetConversionValue=revenue)
-- =============================================
PRINT '>> Calculando objetivos de conversiones por campana...';
IF OBJECT_ID('tempdb..#CampaignTargets') IS NOT NULL DROP TABLE #CampaignTargets;

;WITH BaseTargets AS (
    SELECT
        c.CampaignKey,
        ISNULL(m.Revenue, 84000.0) AS Revenue,
        ISNULL(m.Impressions, 100000) AS Impressions,
        CASE
            WHEN ISNULL(m.Impressions,0) > 0 THEN
                LEAST(300.0, GREATEST(80.0, ISNULL(m.Revenue,84000.0) / NULLIF(m.Impressions/100.0,0)))
            ELSE 120.0
        END AS AvgTicketEstimate
    FROM (
        SELECT DISTINCT campaignKey AS CampaignKey
        FROM [crm].[LeadSources]
    ) c
    LEFT JOIN #PromptAdsMetrics m ON m.CampaignKey = c.CampaignKey
)
SELECT
    CampaignKey,
    Revenue,
    Impressions,
    CASE
        WHEN CEILING(Revenue / NULLIF(AvgTicketEstimate,0)) < 400 THEN 400
        WHEN CEILING(Revenue / NULLIF(AvgTicketEstimate,0)) > 1000 THEN 1000
        ELSE CEILING(Revenue / NULLIF(AvgTicketEstimate,0))
    END AS TargetClientsPre,
    Revenue AS TargetConversionValue
INTO #CampaignTargets
FROM BaseTargets;

-- Escalar a total >= 500k clientes
DECLARE @TotalClientsPre BIGINT = (SELECT SUM(TargetClientsPre) FROM #CampaignTargets);
DECLARE @Scale DECIMAL(18,8) = CASE WHEN @TotalClientsPre < 500000 THEN 500000.0 / NULLIF(@TotalClientsPre,0) ELSE 1 END;

UPDATE #CampaignTargets
SET TargetClientsPre = CEILING(TargetClientsPre * @Scale);

-- Reaplicar limites 400-1000
UPDATE #CampaignTargets
SET TargetClientsPre = CASE
    WHEN TargetClientsPre < 400 THEN 400
    WHEN TargetClientsPre > 1000 THEN 1000
    ELSE TargetClientsPre
END;

DECLARE @TotalClientsTarget BIGINT = (SELECT SUM(TargetClientsPre) FROM #CampaignTargets);
DECLARE @TotalRevenueTarget DECIMAL(18,2) = (SELECT SUM(TargetConversionValue) FROM #CampaignTargets);
PRINT '  - Clientes objetivo total: ' + FORMAT(@TotalClientsTarget, 'N0') + ' (rango 400-1000)';
PRINT '  - Revenue objetivo total: $' + FORMAT(@TotalRevenueTarget, 'N2');
PRINT '';

-- =============================================
-- Seleccionar PURCHASE events (TODOS, no solo primeros N)
-- =============================================
PRINT '>> Seleccionando eventos PURCHASE existentes...';
IF OBJECT_ID('tempdb..#PurchaseEvents') IS NOT NULL DROP TABLE #PurchaseEvents;

-- Seleccionar TODOS los eventos PURCHASE para crear conversiones
-- Nota: Cada PURCHASE crea una conversion, pero solo el 1er PURCHASE convierte al lead en cliente
SELECT
    le.leadEventId,
    le.leadId,
    le.campaignKey,
    le.occurredAt
INTO #PurchaseEvents
FROM [crm].[LeadEvents] le
INNER JOIN [crm].[LeadEventTypes] let ON le.leadEventTypeId = let.leadEventTypeId
WHERE let.eventTypeKey = 'PURCHASE';

DECLARE @AvailableConversions BIGINT = (SELECT COUNT(*) FROM #PurchaseEvents);
DECLARE @UniqueLeadsWithPurchase BIGINT = (SELECT COUNT(DISTINCT leadId) FROM #PurchaseEvents);
PRINT '  - Total eventos PURCHASE: ' + FORMAT(@AvailableConversions, 'N0');
PRINT '  - Leads unicos con PURCHASE: ' + FORMAT(@UniqueLeadsWithPurchase, 'N0');
PRINT '  - Promedio PURCHASE/lead: ' + CAST(CAST(@AvailableConversions AS DECIMAL(38,4)) / NULLIF(@UniqueLeadsWithPurchase,1) AS VARCHAR(128));
PRINT '';

IF @AvailableConversions = 0
BEGIN
    PRINT '  ERROR: No hay eventos PURCHASE para convertir. Ejecute Step 3 (Generate_events).';
    GOTO SkipConversionGeneration;
END

-- =============================================
-- Distribuir conversionValue para cuadrar revenue por campana
-- =============================================
PRINT '>> Distribuyendo conversionValue para alinear con revenue PromptAds...';
IF OBJECT_ID('tempdb..#Conversions') IS NOT NULL DROP TABLE #Conversions;

;WITH CampaignValue AS (
    SELECT
        ct.CampaignKey,
        ct.TargetConversionValue,
        ISNULL(pe.EventCount,0) AS EventCount
    FROM #CampaignTargets ct
    LEFT JOIN (
        SELECT campaignKey, COUNT(*) AS EventCount
        FROM #PurchaseEvents
        GROUP BY campaignKey
    ) pe ON pe.campaignKey = ct.CampaignKey
)
, ValuePerEvent AS (
    SELECT
        pv.CampaignKey,
        pe.leadEventId,
        pe.leadId,
        pe.occurredAt,
        pv.TargetConversionValue,
        pv.EventCount,
        CASE WHEN pv.EventCount > 1 THEN pv.TargetConversionValue / pv.EventCount ELSE pv.TargetConversionValue END AS BaseValue,
        ROW_NUMBER() OVER (PARTITION BY pe.campaignKey ORDER BY pe.occurredAt, pe.leadEventId) AS rn
    FROM #PurchaseEvents pe
    JOIN CampaignValue pv ON pv.CampaignKey = pe.campaignKey
)
SELECT
    CampaignKey,
    leadEventId,
    leadId,
    occurredAt,
    CASE
        WHEN EventCount = 0 THEN 0
        WHEN rn = EventCount THEN TargetConversionValue - BaseValue * (EventCount - 1)
        ELSE BaseValue
    END AS conversionValue
INTO #Conversions
FROM ValuePerEvent;

DECLARE @TotalConv INT = (SELECT COUNT(*) FROM #Conversions);
DECLARE @TotalConvValue DECIMAL(18,2) = (SELECT SUM(conversionValue) FROM #Conversions);
PRINT '  - Conversiones planificadas: ' + FORMAT(@TotalConv, 'N0');
PRINT '  - Valor total conversiones: $' + FORMAT(@TotalConvValue, 'N2');
PRINT '';

IF @TotalConv = 0
BEGIN
    PRINT '  ERROR: No hay conversiones para insertar.';
    GOTO SkipConversionGeneration;
END

-- =============================================
-- INSERTAR CONVERSIONES
-- =============================================
PRINT '>> Insertando conversiones en [crm].[LeadConversions]...';

IF OBJECT_ID('tempdb..#InsertedConversions') IS NOT NULL DROP TABLE #InsertedConversions;
CREATE TABLE #InsertedConversions (
    leadConversionId BIGINT,
    campaignKey VARCHAR(255),
    leadId BIGINT,
    leadEventId BIGINT,
    conversionValue DECIMAL(18,2),
    createdAt DATETIME2
);

INSERT INTO [crm].[LeadConversions] WITH (TABLOCK)
    (leadConversionTypeId, leadId, leadEventId, currencyId, conversionValue, createdAt)
OUTPUT inserted.leadConversionId, NULL, inserted.leadId, inserted.leadEventId, inserted.conversionValue, inserted.createdAt
INTO #InsertedConversions (leadConversionId, campaignKey, leadId, leadEventId, conversionValue, createdAt)
SELECT
    @PurchaseConversionTypeId,
    leadId,
    leadEventId,
    @USDCurrencyId,
    conversionValue,
    occurredAt
FROM #Conversions c
ORDER BY campaignKey, leadEventId;

-- Update campaignKey in #InsertedConversions
UPDATE ic
SET ic.campaignKey = c.CampaignKey
FROM #InsertedConversions ic
JOIN #Conversions c ON c.leadEventId = ic.leadEventId;

PRINT '  - Conversiones generadas: ' + FORMAT(@@ROWCOUNT, 'N0');

PRINT '';
PRINT 'Validacion por campana (target vs generado):';
SELECT
    ct.CampaignKey,
    ct.TargetClientsPre AS TargetClients,
    ct.TargetConversionValue AS TargetRevenue,
    COUNT(*) AS Conversions,
    COUNT(DISTINCT ic.leadId) AS DistinctClients,
    SUM(ic.conversionValue) AS TotalConversionValue,
    CASE WHEN COUNT(DISTINCT ic.leadId) < 400 OR COUNT(DISTINCT ic.leadId) > 1000 THEN 'WARN: clientes fuera de 400-1000' ELSE '' END AS ClientsFlag,
    CASE WHEN ABS(ISNULL(SUM(ic.conversionValue),0) - ISNULL(ct.TargetConversionValue,0)) > 1.0 THEN 'WARN: revenue != target' ELSE '' END AS RevenueFlag
FROM #CampaignTargets ct
LEFT JOIN #InsertedConversions ic ON ic.campaignKey = ct.CampaignKey
GROUP BY ct.CampaignKey, ct.TargetClientsPre, ct.TargetConversionValue
ORDER BY ct.CampaignKey;

DECLARE @TotalDistinctClients BIGINT = (SELECT COUNT(DISTINCT leadId) FROM #InsertedConversions);
DECLARE @TotalRevenue DECIMAL(18,2) = (SELECT SUM(conversionValue) FROM #InsertedConversions);

PRINT '';
PRINT 'Totales conversiones:';
PRINT '  Clientes distintos: ' + FORMAT(@TotalDistinctClients, 'N0');
PRINT '  Ingreso total:     ' + FORMAT(@TotalRevenue, 'N2');

-- =============================================
-- Resumen por campana
-- =============================================
PRINT '';
PRINT 'Resumen por campana:';
SELECT
    c.CampaignKey,
    COUNT(*) AS Conversions,
    SUM(lc.conversionValue) AS TotalConversionValue
FROM [crm].[LeadConversions] lc
JOIN #Conversions c ON c.leadEventId = lc.leadEventId
GROUP BY c.CampaignKey
ORDER BY c.CampaignKey;

SkipConversionGeneration:

-- Cleanup: Dropear TODAS las tablas temporales creadas
IF OBJECT_ID('tempdb..#PromptAdsMetrics') IS NOT NULL DROP TABLE #PromptAdsMetrics;
IF OBJECT_ID('tempdb..#CampaignTargets') IS NOT NULL DROP TABLE #CampaignTargets;
IF OBJECT_ID('tempdb..#PurchaseEvents') IS NOT NULL DROP TABLE #PurchaseEvents;
IF OBJECT_ID('tempdb..#Conversions') IS NOT NULL DROP TABLE #Conversions;
IF OBJECT_ID('tempdb..#InsertedConversions') IS NOT NULL DROP TABLE #InsertedConversions;

PRINT '';
PRINT '=============================================';
PRINT 'STEP 4 COMPLETADO';
PRINT '=============================================';
GO
