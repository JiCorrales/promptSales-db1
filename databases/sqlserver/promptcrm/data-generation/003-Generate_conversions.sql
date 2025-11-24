-- =============================================
-- STEP 4: Generar LeadConversions v2
-- =============================================
-- Genera conversiones para subset de leads con eventos:
--   - 40% de leads con eventos convierten
--   - Mayor probabilidad si tiene eventos "CONVERSION_INTENT"
--   - conversionValue NOT NULL (5-500 USD)
--   - leadEventId NOT NULL (referencia a evento específico)
--   - currencyId NOT NULL
--   - occurredAt posterior al último LeadEvent
--   - Un lead puede tener múltiples conversiones
-- Target: ~600K conversiones
-- =============================================

PRINT 'Generando LeadConversions...';
PRINT '';

SET NOCOUNT ON;

-- =============================================
-- CONFIGURACIÓN
-- =============================================
DECLARE @TargetConversionRate DECIMAL(5,2) = 0.40; -- 40% de leads convierten
DECLARE @MultipleConversionProb DECIMAL(5,2) = 0.15; -- 15% tienen múltiples conversiones
DECLARE @LeadsPerBatch INT = 50000;
DECLARE @TotalLeadsWithEvents BIGINT;
DECLARE @TargetConversions BIGINT;
DECLARE @GeneratedConversions BIGINT = 0;
DECLARE @ProcessedLeads BIGINT = 0;
DECLARE @CurrentBatch INT = 1;
DECLARE @BatchStartTime DATETIME2;
DECLARE @BatchSeconds INT;

-- Contar leads con eventos
SELECT @TotalLeadsWithEvents = COUNT(DISTINCT leadId)
FROM [crm].[LeadEvents];

SET @TargetConversions = CAST(@TotalLeadsWithEvents * @TargetConversionRate AS BIGINT);

PRINT '  Leads con eventos: ' + FORMAT(@TotalLeadsWithEvents, 'N0');
PRINT '  Target conversions (40%): ' + FORMAT(@TargetConversions, 'N0');
PRINT '';

IF @TotalLeadsWithEvents = 0
BEGIN
    PRINT '  ⚠️  No hay LeadEvents. Ejecutar Step3 primero.';
    GOTO SkipConversionGeneration;
END

DECLARE @TotalBatches INT = CEILING(CAST(@TotalLeadsWithEvents AS DECIMAL(18,2)) / @LeadsPerBatch);

-- =============================================
-- CARGAR CATÁLOGOS
-- =============================================
CREATE TABLE #ConversionTypes (
    ConversionTypeId INT,
    ConversionTypeName VARCHAR(60),
    MinValue DECIMAL(18,4),
    MaxValue DECIMAL(18,4)
);

-- Tipos de conversión con rangos de valor
INSERT INTO #ConversionTypes VALUES
(1, 'PURCHASE', 50.00, 500.00),
(2, 'SUBSCRIPTION', 10.00, 200.00),
(3, 'TRIAL_SIGNUP', 5.00, 5.00),       -- Valor mínimo para NOT NULL
(4, 'DEMO_REQUEST', 10.00, 10.00),     -- Valor mínimo para NOT NULL
(5, 'QUOTE_REQUEST', 100.00, 5000.00),
(6, 'CONTACT_FORM', 5.00, 5.00);       -- Valor mínimo para NOT NULL

-- Obtener currency USD (asumir USD = currencyId 1, o buscar)
DECLARE @USDCurrencyId INT;
SELECT TOP 1 @USDCurrencyId = currencyId
FROM [crm].[Currencies]
WHERE currencyCode = 'USD' AND enabled = 1;

IF @USDCurrencyId IS NULL
BEGIN
    PRINT '  ⚠️  No se encontró currency USD habilitada. Usando currencyId = 1 por defecto.';
    SET @USDCurrencyId = 1;
END

PRINT 'Catálogos cargados (Currency: ' + CAST(@USDCurrencyId AS VARCHAR(10)) + ')';
PRINT '';

-- =============================================
-- IDENTIFICAR LEADS QUE CONVERTIRÁN
-- =============================================
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Identificando leads candidatos a conversión...';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

CREATE TABLE #LeadsToConvert (
    LeadId INT PRIMARY KEY,
    LastEventId BIGINT NOT NULL,
    LastEventDate DATETIME2,
    HasConversionIntent BIT,
    ConversionProbability DECIMAL(5,3)
);

-- Obtener todos los leads con eventos y su probabilidad de conversión
INSERT INTO #LeadsToConvert (LeadId, LastEventId, LastEventDate, HasConversionIntent, ConversionProbability)
SELECT
    le.leadId,
    (SELECT TOP 1 leadEventId
     FROM [crm].[LeadEvents] le2
     WHERE le2.leadId = le.leadId
     ORDER BY le2.occurredAt DESC) AS LastEventId,
    MAX(le.occurredAt) AS LastEventDate,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM [crm].[LeadEvents] le2
            INNER JOIN [crm].[LeadEventTypes] let ON le2.leadEventTypeId = let.leadEventTypeId
            WHERE le2.leadId = le.leadId
              AND let.eventTypeName = 'CONVERSION_INTENT'
        ) THEN 1
        ELSE 0
    END AS HasConversionIntent,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM [crm].[LeadEvents] le2
            INNER JOIN [crm].[LeadEventTypes] let ON le2.leadEventTypeId = let.leadEventTypeId
            WHERE le2.leadId = le.leadId
              AND let.eventTypeName = 'CONVERSION_INTENT'
        ) THEN 0.700  -- 70% si tiene intent
        WHEN COUNT(*) >= 10 THEN 0.500  -- 50% si tiene 10+ eventos
        WHEN COUNT(*) >= 5 THEN 0.350   -- 35% si tiene 5+ eventos
        ELSE 0.250  -- 25% base
    END AS ConversionProbability
FROM [crm].[LeadEvents] le
GROUP BY le.leadId;

DECLARE @LeadsToConvertCount BIGINT = (SELECT COUNT(*) FROM #LeadsToConvert);
PRINT '  ✓ ' + FORMAT(@LeadsToConvertCount, 'N0') + ' leads candidatos identificados';
PRINT '';

-- =============================================
-- GENERAR CONVERSIONES
-- =============================================
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Generando conversiones en batches...';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

DECLARE @LeadId INT;
DECLARE @LastEventId BIGINT;
DECLARE @LastEventDate DATETIME2;
DECLARE @ConversionProb DECIMAL(5,3);
DECLARE @NumConversions INT;
DECLARE @ConversionNum INT;
DECLARE @ConversionTypeId INT;
DECLARE @ConversionValue DECIMAL(18,4);
DECLARE @ConversionDate DATETIME2;
DECLARE @MinValue DECIMAL(18,4);
DECLARE @MaxValue DECIMAL(18,4);

CREATE TABLE #BatchConversions (
    LeadId INT NOT NULL,
    LeadEventId BIGINT NOT NULL,
    LeadConversionTypeId INT NOT NULL,
    ConversionValue DECIMAL(18,4) NOT NULL,
    CurrencyId INT NOT NULL,
    OccurredAt DATETIME2 NOT NULL
);

WHILE @ProcessedLeads < @TotalLeadsWithEvents AND @GeneratedConversions < @TargetConversions
BEGIN
    SET @BatchStartTime = GETUTCDATE();

    PRINT 'Batch ' + CAST(@CurrentBatch AS VARCHAR(5)) + ' - Procesando hasta ' + FORMAT(@LeadsPerBatch, 'N0') + ' leads...';

    TRUNCATE TABLE #BatchConversions;

    DECLARE lead_cursor CURSOR FAST_FORWARD FOR
    SELECT TOP (@LeadsPerBatch)
        LeadId, LastEventId, LastEventDate, ConversionProbability
    FROM #LeadsToConvert
    WHERE LeadId NOT IN (SELECT DISTINCT leadId FROM [crm].[LeadConversions])
    ORDER BY ConversionProbability DESC, LeadId;

    OPEN lead_cursor;
    FETCH NEXT FROM lead_cursor INTO @LeadId, @LastEventId, @LastEventDate, @ConversionProb;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Decidir si este lead convierte basado en su probabilidad
        IF RAND() < @ConversionProb
        BEGIN
            -- Decidir cuántas conversiones (1-3)
            SET @NumConversions = CASE
                WHEN RAND() < @MultipleConversionProb THEN 2 + ABS(CHECKSUM(NEWID()) % 2)
                ELSE 1
            END;

            SET @ConversionNum = 1;
            WHILE @ConversionNum <= @NumConversions
            BEGIN
                -- Seleccionar tipo de conversión aleatorio
                SELECT TOP 1
                    @ConversionTypeId = ConversionTypeId,
                    @MinValue = MinValue,
                    @MaxValue = MaxValue
                FROM #ConversionTypes
                ORDER BY NEWID();

                -- Calcular valor aleatorio en el rango (NEVER NULL)
                IF @MaxValue > @MinValue
                    SET @ConversionValue = @MinValue + (RAND() * (@MaxValue - @MinValue));
                ELSE
                    SET @ConversionValue = @MinValue;

                -- Fecha de conversión (1-90 días después del último evento)
                DECLARE @DaysAfterLastEvent INT = 1 + ABS(CHECKSUM(NEWID()) % 90);
                SET @ConversionDate = DATEADD(DAY, @DaysAfterLastEvent, @LastEventDate);

                -- No permitir fechas futuras
                IF @ConversionDate > GETUTCDATE()
                    SET @ConversionDate = GETUTCDATE();

                -- Insertar conversión con todos los campos NOT NULL completos
                INSERT INTO #BatchConversions
                    (LeadId, LeadEventId, LeadConversionTypeId, ConversionValue, CurrencyId, OccurredAt)
                VALUES
                    (@LeadId, @LastEventId, @ConversionTypeId, @ConversionValue, @USDCurrencyId, @ConversionDate);

                SET @ConversionNum = @ConversionNum + 1;
            END
        END

        SET @ProcessedLeads = @ProcessedLeads + 1;

        -- Break si ya alcanzamos el target
        IF @GeneratedConversions >= @TargetConversions
            BREAK;

        FETCH NEXT FROM lead_cursor INTO @LeadId, @LastEventId, @LastEventDate, @ConversionProb;
    END

    CLOSE lead_cursor;
    DEALLOCATE lead_cursor;

    -- INSERT MASIVO
    INSERT INTO [crm].[LeadConversions] WITH (TABLOCK)
        (leadId, leadEventId, leadConversionTypeId, conversionValue, currencyId, createdAt, updatedAt)
    SELECT
        LeadId, LeadEventId, LeadConversionTypeId, ConversionValue, CurrencyId, OccurredAt, OccurredAt
    FROM #BatchConversions;

    DECLARE @ConversionsInBatch BIGINT = @@ROWCOUNT;
    SET @GeneratedConversions = @GeneratedConversions + @ConversionsInBatch;

    SET @BatchSeconds = DATEDIFF(SECOND, @BatchStartTime, GETUTCDATE());
    PRINT '  ✓ Batch completado en ' + CAST(@BatchSeconds AS VARCHAR(10)) + 's';
    PRINT '    • Conversiones generadas: ' + FORMAT(@ConversionsInBatch, 'N0');
    PRINT '    • Total acumulado: ' + FORMAT(@GeneratedConversions, 'N0') + ' conversiones';
    PRINT '';

    SET @CurrentBatch = @CurrentBatch + 1;

    IF @GeneratedConversions >= @TargetConversions
        BREAK;
END

-- Cleanup
DROP TABLE #BatchConversions;
DROP TABLE #LeadsToConvert;
DROP TABLE #ConversionTypes;

SkipConversionGeneration:

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ GENERACIÓN DE LEAD CONVERSIONS COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '  Total generado: ' + FORMAT(@GeneratedConversions, 'N0') + ' conversiones';
PRINT '';

-- Estadísticas
PRINT '  Distribución por tipo:';
SELECT
    lct.leadConversionName AS TipoConversion,
    FORMAT(COUNT(*), 'N0') AS TotalConversiones,
    FORMAT(AVG(lc.conversionValue), 'C2') AS ValorPromedio,
    FORMAT(SUM(lc.conversionValue), 'C2') AS ValorTotal
FROM [crm].[LeadConversions] lc
INNER JOIN [crm].[LeadConversionTypes] lct ON lc.leadConversionTypeId = lct.leadConversionTypeId
GROUP BY lct.leadConversionName
ORDER BY COUNT(*) DESC;

PRINT '';

-- Leads únicos que convirtieron
DECLARE @UniqueConvertedLeads BIGINT;
SELECT @UniqueConvertedLeads = COUNT(DISTINCT leadId)
FROM [crm].[LeadConversions];

PRINT '  Leads únicos con conversión: ' + FORMAT(@UniqueConvertedLeads, 'N0');
PRINT '';
