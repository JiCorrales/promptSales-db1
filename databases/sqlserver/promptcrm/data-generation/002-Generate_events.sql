-- =============================================
-- STEP 3: Generar LeadEvents (1-20 por Lead) v3.0 - OPTIMIZED
-- =============================================
-- Genera entre 1 y 20 eventos por lead con:
--   - Distribución realista de tipos (muchos views, pocos conversions)
--   - Consistencia temporal (occurredAt > Lead.createdAt)
--   - Campos de campaña (campaignKey, adGroupKey, adKey, contentKey)
--   - Geolocalización completa (countryId, stateId, cityId)
--   - Device context coherente (mediumId, originChannelId, deviceTypeId, devicePlatformId, browserId)
--   - Metadata estructurado por tipo de evento
--   - Checksum para integridad de datos
--   - Coherencia semántica heredada del LeadSource (70%) + variación (30%)
--   - IP cifrada usando ENCRYPTBYKEY en batch (OPTIMIZADO)
-- Distribución de eventos:
--   • 15% leads → 1 evento
--   • 20% leads → 2-5 eventos (avg 3.5)
--   • 30% leads → 6-10 eventos (avg 8)
--   • 25% leads → 11-17 eventos (avg 14)
--   • 10% leads → 18-20 eventos (avg 19)
-- Target: ~13M eventos (promedio 8.65 eventos por lead)
-- OPTIMIZACIÓN v3.0:
--   • Cifrado vectorizado (ENCRYPTBYKEY batch)
--   • Sin cursores para cifrado individual
--   • Apertura única de symmetric key por batch
-- =============================================

SET NOCOUNT ON;

PRINT 'Generando LeadEvents con campos completos (v3.0 OPTIMIZED)...';
PRINT '';

-- =============================================
-- CONFIGURACIÓN
-- =============================================
DECLARE @LeadsPerBatch INT = 25000; -- Procesar 25K leads a la vez
DECLARE @TotalLeads BIGINT;
DECLARE @ProcessedLeads BIGINT = 0;
DECLARE @TotalEvents BIGINT = 0;
DECLARE @CurrentBatch INT = 1;
DECLARE @BatchStartTime DATETIME2;
DECLARE @BatchSeconds INT;

-- Obtener total de leads a procesar
SELECT @TotalLeads = COUNT(*)
FROM [crm].[Leads] l
WHERE NOT EXISTS (
    SELECT 1
    FROM [crm].[LeadEvents] le
    WHERE le.leadId = l.leadId
); -- Solo procesar leads sin eventos aún

IF @TotalLeads = 0
BEGIN
    SELECT @TotalLeads = COUNT(*) FROM [crm].[Leads];
    PRINT '  ⚠️  Todos los leads ya tienen eventos. Total leads: ' + FORMAT(@TotalLeads, 'N0');
    GOTO SkipEventGeneration;
END

DECLARE @TotalBatches INT = CEILING(CAST(@TotalLeads AS DECIMAL(18,2)) / @LeadsPerBatch);

PRINT '  Leads a procesar: ' + FORMAT(@TotalLeads, 'N0');
PRINT '  Batches: ' + CAST(@TotalBatches AS VARCHAR(10)) + ' de ' + FORMAT(@LeadsPerBatch, 'N0') + ' leads';
PRINT '';

-- =============================================
-- CARGAR CATÁLOGOS EN MEMORIA
-- =============================================
PRINT 'Cargando catálogos...';

-- Event Types con probabilidades
CREATE TABLE #EventTypes (
    EventTypeId INT,
    EventTypeName VARCHAR(60),
    CategoryKey VARCHAR(30),
    Probability DECIMAL(5,3)
);

INSERT INTO #EventTypes (EventTypeId, EventTypeName, CategoryKey, Probability)
SELECT leadEventTypeId, eventTypeKey, categoryKey,
    CASE eventTypeKey
        WHEN 'PAGE_VIEW' THEN 0.250
        WHEN 'LINK_CLICK' THEN 0.150
        WHEN 'BUTTON_CLICK' THEN 0.120
        WHEN 'FORM_VIEW' THEN 0.080
        WHEN 'FORM_START' THEN 0.060
        WHEN 'FORM_SUBMIT' THEN 0.040
        WHEN 'VIDEO_VIEW' THEN 0.070
        WHEN 'VIDEO_25' THEN 0.050
        WHEN 'VIDEO_50' THEN 0.040
        WHEN 'VIDEO_75' THEN 0.030
        WHEN 'VIDEO_100' THEN 0.020
        WHEN 'DOWNLOAD' THEN 0.025
        WHEN 'SIGNUP' THEN 0.015
        WHEN 'ADD_TO_CART' THEN 0.020
        WHEN 'CHECKOUT_START' THEN 0.010
        WHEN 'PURCHASE' THEN 0.008
        WHEN 'EMAIL_OPEN' THEN 0.045
        WHEN 'EMAIL_CLICK' THEN 0.030
        WHEN 'CALL' THEN 0.012
        WHEN 'CHAT_START' THEN 0.025
        ELSE 0.001
    END
FROM [crm].[LeadEventTypes]
WHERE enabled = 1;

-- Event Sources
CREATE TABLE #EventSources (EventSourceId INT, SourceKey VARCHAR(60));
INSERT INTO #EventSources
SELECT leadEventSourceId, sourceKey
FROM [crm].[LeadEventSources]
WHERE enabled = 1;

-- Countries
CREATE TABLE #Countries (CountryId INT);
INSERT INTO #Countries
SELECT countryId FROM [crm].[Countries] WHERE enabled = 1;

-- Cities by Country (para coherencia geográfica)
CREATE TABLE #CitiesByCountry (CountryId INT, StateId INT, CityId INT);
INSERT INTO #CitiesByCountry
SELECT c.countryId, s.stateId, ci.cityId
FROM [crm].[Countries] c
INNER JOIN [crm].[States] s ON c.countryId = s.countryId
INNER JOIN [crm].[Cities] ci ON s.stateId = ci.stateId
WHERE c.enabled = 1 AND s.enabled = 1 AND ci.enabled = 1;

-- Mediums
CREATE TABLE #Mediums (MediumId INT, MediumKey VARCHAR(30));
INSERT INTO #Mediums
SELECT leadMediumId, leadMediumKey FROM [crm].[LeadMediums] WHERE enabled = 1;

-- Origin Channels
CREATE TABLE #OriginChannels (OriginChannelId INT, ChannelKey VARCHAR(30));
INSERT INTO #OriginChannels
SELECT leadOriginChannelId, leadOriginChannelKey FROM [crm].[LeadOriginChannels] WHERE enabled = 1;

-- Device Types
CREATE TABLE #DeviceTypes (DeviceTypeId INT, DeviceKey VARCHAR(30));
INSERT INTO #DeviceTypes
SELECT deviceTypeId, deviceTypeKey FROM [crm].[DeviceTypes] WHERE enabled = 1;

-- Device Platforms
CREATE TABLE #DevicePlatforms (PlatformId INT, PlatformKey VARCHAR(30));
INSERT INTO #DevicePlatforms
SELECT devicePlatformId, devicePlatformKey FROM [crm].[DevicePlatforms] WHERE enabled = 1;

-- Browsers
CREATE TABLE #Browsers (BrowserId INT, BrowserKey VARCHAR(30));
INSERT INTO #Browsers
SELECT browserId, browserKey FROM [crm].[Browsers] WHERE enabled = 1;

-- Coherencia Device-Platform-Browser
CREATE TABLE #DeviceCoherence (
    DeviceTypeId INT,
    PlatformId INT,
    BrowserId INT,
    Weight DECIMAL(3,2)
);

INSERT INTO #DeviceCoherence (DeviceTypeId, PlatformId, BrowserId, Weight) VALUES
-- Mobile + iOS
(3, 4, 3, 0.50), -- Mobile + iOS + Safari
(3, 4, 1, 0.40), -- Mobile + iOS + Chrome
(3, 4, 6, 0.10), -- Mobile + iOS + Brave
-- Mobile + Android
(3, 5, 1, 0.60), -- Mobile + Android + Chrome
(3, 5, 7, 0.20), -- Mobile + Android + Samsung
(3, 5, 2, 0.15), -- Mobile + Android + Firefox
(3, 5, 8, 0.05), -- Mobile + Android + UC
-- Desktop + Windows
(1, 1, 1, 0.50), -- Desktop + Windows + Chrome
(1, 1, 4, 0.30), -- Desktop + Windows + Edge
(1, 1, 2, 0.15), -- Desktop + Windows + Firefox
(1, 1, 5, 0.05), -- Desktop + Windows + Opera
-- Desktop + macOS
(1, 2, 3, 0.45), -- Desktop + macOS + Safari
(1, 2, 1, 0.40), -- Desktop + macOS + Chrome
(1, 2, 2, 0.10), -- Desktop + macOS + Firefox
(1, 2, 6, 0.05), -- Desktop + macOS + Brave
-- Laptop + Windows
(2, 1, 1, 0.50), -- Laptop + Windows + Chrome
(2, 1, 4, 0.30), -- Laptop + Windows + Edge
(2, 1, 2, 0.15), -- Laptop + Windows + Firefox
(2, 1, 5, 0.05), -- Laptop + Windows + Opera
-- Laptop + macOS
(2, 2, 3, 0.45), -- Laptop + macOS + Safari
(2, 2, 1, 0.40), -- Laptop + macOS + Chrome
(2, 2, 2, 0.10), -- Laptop + macOS + Firefox
(2, 2, 6, 0.05), -- Laptop + macOS + Brave
-- Tablet + iPadOS
(4, 6, 3, 0.60), -- Tablet + iPadOS + Safari
(4, 6, 1, 0.35), -- Tablet + iPadOS + Chrome
(4, 6, 6, 0.05), -- Tablet + iPadOS + Brave
-- Tablet + Android
(4, 5, 1, 0.70), -- Tablet + Android + Chrome
(4, 5, 2, 0.20), -- Tablet + Android + Firefox
(4, 5, 7, 0.10); -- Tablet + Android + Samsung

-- Coherencia Medium-OriginChannel
CREATE TABLE #MediumChannelCoherence (
    MediumId INT,
    OriginChannelId INT,
    Weight DECIMAL(3,2)
);

INSERT INTO #MediumChannelCoherence (MediumId, OriginChannelId, Weight)
SELECT m.MediumId, oc.OriginChannelId,
    CASE
        WHEN m.MediumKey = 'SOCIAL' AND oc.ChannelKey IN ('FACEBOOK', 'INSTAGRAM', 'LINKEDIN', 'TWITTER', 'TIKTOK') THEN 0.80
        WHEN m.MediumKey = 'EMAIL' AND oc.ChannelKey = 'EMAIL' THEN 1.00
        WHEN m.MediumKey = 'ORGANIC' AND oc.ChannelKey IN ('GOOGLE', 'WEBSITE') THEN 0.70
        WHEN m.MediumKey = 'CPC' AND oc.ChannelKey IN ('GOOGLE', 'FACEBOOK', 'INSTAGRAM', 'LINKEDIN') THEN 0.80
        WHEN m.MediumKey = 'VIDEO' AND oc.ChannelKey IN ('YOUTUBE', 'TIKTOK', 'FACEBOOK') THEN 0.90
        WHEN m.MediumKey = 'DISPLAY' AND oc.ChannelKey = 'GOOGLE' THEN 0.70
        ELSE 0.20
    END AS Weight
FROM #Mediums m
CROSS JOIN #OriginChannels oc
WHERE CASE
    WHEN m.MediumKey = 'SOCIAL' AND oc.ChannelKey IN ('FACEBOOK', 'INSTAGRAM', 'LINKEDIN', 'TWITTER', 'TIKTOK') THEN 1
    WHEN m.MediumKey = 'EMAIL' AND oc.ChannelKey = 'EMAIL' THEN 1
    WHEN m.MediumKey = 'ORGANIC' AND oc.ChannelKey IN ('GOOGLE', 'WEBSITE') THEN 1
    WHEN m.MediumKey = 'CPC' AND oc.ChannelKey IN ('GOOGLE', 'FACEBOOK', 'INSTAGRAM', 'LINKEDIN') THEN 1
    WHEN m.MediumKey = 'VIDEO' AND oc.ChannelKey IN ('YOUTUBE', 'TIKTOK', 'FACEBOOK') THEN 1
    WHEN m.MediumKey = 'DISPLAY' AND oc.ChannelKey = 'GOOGLE' THEN 1
    ELSE 0
END = 1;

DECLARE @CountryCount INT = (SELECT COUNT(*) FROM #Countries);
DECLARE @EventSourceCount INT = (SELECT COUNT(*) FROM #EventSources);
DECLARE @MediumCount INT = (SELECT COUNT(*) FROM #Mediums);
DECLARE @ChannelCount INT = (SELECT COUNT(*) FROM #OriginChannels);
DECLARE @DeviceTypeCount INT = (SELECT COUNT(*) FROM #DeviceTypes);

PRINT '  ✓ ' + CAST(@CountryCount AS VARCHAR(10)) + ' países disponibles';
PRINT '  ✓ ' + CAST(@EventSourceCount AS VARCHAR(10)) + ' event sources disponibles';
PRINT '  ✓ ' + CAST(@MediumCount AS VARCHAR(10)) + ' mediums disponibles';
PRINT '  ✓ ' + CAST(@ChannelCount AS VARCHAR(10)) + ' origin channels disponibles';
PRINT '  ✓ ' + CAST(@DeviceTypeCount AS VARCHAR(10)) + ' device types disponibles';
PRINT '  ✓ 20 event types configurados';
PRINT '';

-- =============================================
-- GENERACIÓN DE EVENTOS EN BATCHES
-- =============================================
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Iniciando generación de eventos con campos completos...';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

-- Crear tabla temporal para almacenar IDs de leads a procesar
CREATE TABLE #LeadsToProcess (
    LeadId INT PRIMARY KEY,
    LeadSourceId INT NOT NULL,
    CreatedAt DATETIME2,
    SubscriberId INT,
    LeadCountryId INT,
    LeadStateId INT,
    LeadCityId INT,
    SourceCampaignKey VARCHAR(255),
    SourceDeviceTypeId INT,
    SourceDevicePlatformId INT,
    SourceBrowserId INT,
    SourceMediumId INT,
    SourceOriginChannelId INT
);

WHILE @ProcessedLeads < @TotalLeads
BEGIN
    SET @BatchStartTime = GETUTCDATE();

    PRINT 'Batch ' + CAST(@CurrentBatch AS VARCHAR(5)) + '/' + CAST(@TotalBatches AS VARCHAR(5)) + ' - Procesando hasta ' + FORMAT(@LeadsPerBatch, 'N0') + ' leads...';

    -- Limpiar tabla temporal
    TRUNCATE TABLE #LeadsToProcess;

    -- Seleccionar siguiente batch de leads SIN eventos (con contexto del LeadSource)
    INSERT INTO #LeadsToProcess (
        LeadId, LeadSourceId, CreatedAt, SubscriberId,
        LeadCountryId, LeadStateId, LeadCityId,
        SourceCampaignKey, SourceDeviceTypeId, SourceDevicePlatformId, SourceBrowserId,
        SourceMediumId, SourceOriginChannelId
    )
    SELECT TOP (@LeadsPerBatch)
        l.leadId,
        ls.leadSourceId,
        l.createdAt,
        l.subscriberId,
        l.countryId,
        l.StateId,
        l.cityId,
        ls.campaignKey,
        ls.deviceTypeId,
        ls.devicePlatformId,
        ls.browserId,
        ls.leadMediumId,
        ls.leadOriginChannelId
    FROM [crm].[Leads] l
    INNER JOIN [crm].[LeadSources] ls ON l.leadId = ls.leadId
    WHERE NOT EXISTS (
        SELECT 1
        FROM [crm].[LeadEvents] le
        WHERE le.leadId = l.leadId
    )
    ORDER BY l.leadId;

    DECLARE @LeadsInBatch INT = @@ROWCOUNT;

    IF @LeadsInBatch = 0
        BREAK; -- No más leads para procesar

    -- Tabla temporal para eventos de este batch
    -- OPTIMIZACIÓN: IP en texto plano primero, cifrar después en batch
    CREATE TABLE #BatchEvents (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        LeadId INT,
        LeadSourceId INT NOT NULL,
        LeadEventTypeId INT NOT NULL,
        LeadEventSourceId INT NOT NULL,
        OccurredAt DATETIME2 NOT NULL,
        CountryId INT,
        StateId INT,
        CityId INT,
        IpAddressClearText VARCHAR(45),  -- Texto plano temporal
        IpAddressEncrypted VARBINARY(64),  -- Cifrado después
        CampaignKey VARCHAR(255),
        AdGroupKey VARCHAR(255),
        AdKey VARCHAR(255),
        ContentKey VARCHAR(255),
        MediumId INT,
        OriginChannelId INT,
        DeviceTypeId INT,
        DevicePlatformId INT,
        BrowserId INT,
        Metadata NVARCHAR(MAX),
        Checksum VARCHAR(64)
    );

    -- Generar eventos para cada lead del batch
    DECLARE @LeadId INT;
    DECLARE @LeadSourceId INT;
    DECLARE @LeadCreatedAt DATETIME2;
    DECLARE @SubscriberId INT;
    DECLARE @LeadCountryId INT;
    DECLARE @LeadStateId INT;
    DECLARE @LeadCityId INT;
    DECLARE @SourceCampaignKey VARCHAR(255);
    DECLARE @SourceDeviceTypeId INT;
    DECLARE @SourceDevicePlatformId INT;
    DECLARE @SourceBrowserId INT;
    DECLARE @SourceMediumId INT;
    DECLARE @SourceOriginChannelId INT;

    DECLARE @NumEvents INT;
    DECLARE @EventNum INT;
    DECLARE @EventTypeId INT;
    DECLARE @EventTypeName VARCHAR(60);
    DECLARE @EventCategoryKey VARCHAR(30);
    DECLARE @EventSourceId INT;
    DECLARE @EventOccurredAt DATETIME2;
    DECLARE @EventCountryId INT;
    DECLARE @EventStateId INT;
    DECLARE @EventCityId INT;
    DECLARE @EventIP VARCHAR(45);
    DECLARE @DaysSinceCreation INT;
    DECLARE @HoursOffset INT;

    -- Campaign fields
    DECLARE @CampaignKey VARCHAR(255);
    DECLARE @AdGroupKey VARCHAR(255);
    DECLARE @AdKey VARCHAR(255);
    DECLARE @ContentKey VARCHAR(255);

    -- Device context
    DECLARE @MediumId INT;
    DECLARE @OriginChannelId INT;
    DECLARE @DeviceTypeId INT;
    DECLARE @DevicePlatformId INT;
    DECLARE @BrowserId INT;

    -- Metadata & checksum
    DECLARE @Metadata NVARCHAR(MAX);
    DECLARE @Checksum VARCHAR(64);
    DECLARE @ChecksumSource VARCHAR(500);

    DECLARE lead_cursor CURSOR FAST_FORWARD FOR
    SELECT
        LeadId, LeadSourceId, CreatedAt, SubscriberId,
        LeadCountryId, LeadStateId, LeadCityId,
        SourceCampaignKey, SourceDeviceTypeId, SourceDevicePlatformId, SourceBrowserId,
        SourceMediumId, SourceOriginChannelId
    FROM #LeadsToProcess;

    OPEN lead_cursor;
    FETCH NEXT FROM lead_cursor INTO
        @LeadId, @LeadSourceId, @LeadCreatedAt, @SubscriberId,
        @LeadCountryId, @LeadStateId, @LeadCityId,
        @SourceCampaignKey, @SourceDeviceTypeId, @SourceDevicePlatformId, @SourceBrowserId,
        @SourceMediumId, @SourceOriginChannelId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Decidir número de eventos para este lead (1-20)
        -- Distribución mejorada: Mayor promedio de eventos por lead
        DECLARE @RandEventDist DECIMAL(5,3) = RAND();
        SET @NumEvents = CASE
            WHEN @RandEventDist < 0.15 THEN 1                          -- 15% → 1 evento
            WHEN @RandEventDist < 0.35 THEN 2 + ABS(CHECKSUM(NEWID()) % 4)  -- 20% → 2-5 eventos
            WHEN @RandEventDist < 0.65 THEN 6 + ABS(CHECKSUM(NEWID()) % 5)  -- 30% → 6-10 eventos
            WHEN @RandEventDist < 0.90 THEN 11 + ABS(CHECKSUM(NEWID()) % 7) -- 25% → 11-17 eventos
            ELSE 18 + ABS(CHECKSUM(NEWID()) % 3)                       -- 10% → 18-20 eventos
        END;

        SET @EventNum = 1;
        SET @DaysSinceCreation = DATEDIFF(DAY, @LeadCreatedAt, GETUTCDATE());

        WHILE @EventNum <= @NumEvents
        BEGIN
            -- =============================================
            -- 1. TIPO DE EVENTO (probabilistic)
            -- =============================================
            DECLARE @RandomProb DECIMAL(5,3) = RAND();

            SELECT TOP 1
                @EventTypeId = EventTypeId,
                @EventTypeName = EventTypeName,
                @EventCategoryKey = CategoryKey
            FROM (
                SELECT
                    EventTypeId,
                    EventTypeName,
                    CategoryKey,
                    SUM(Probability) OVER (ORDER BY EventTypeId) AS CumulativeProb
                FROM #EventTypes
            ) t
            WHERE @RandomProb <= CumulativeProb
            ORDER BY CumulativeProb;

            -- =============================================
            -- 2. EVENT SOURCE
            -- =============================================
            SELECT TOP 1 @EventSourceId = EventSourceId
            FROM #EventSources
            ORDER BY NEWID();

            -- =============================================
            -- 3. FECHA DEL EVENTO
            -- =============================================
            IF @DaysSinceCreation > 0
                SET @HoursOffset = ABS(CHECKSUM(NEWID()) % (@DaysSinceCreation * 24));
            ELSE
                SET @HoursOffset = ABS(CHECKSUM(NEWID()) % 24);

            SET @EventOccurredAt = DATEADD(HOUR, @HoursOffset, @LeadCreatedAt);

            -- =============================================
            -- 4. GEOLOCALIZACIÓN (coherente con Lead 60%)
            -- =============================================
            IF RAND() < 0.60 AND @LeadCountryId IS NOT NULL
            BEGIN
                -- Heredar del Lead
                SET @EventCountryId = @LeadCountryId;
                SET @EventStateId = @LeadStateId;
                SET @EventCityId = @LeadCityId;
            END
            ELSE
            BEGIN
                -- País aleatorio
                SELECT TOP 1 @EventCountryId = CountryId
                FROM #Countries
                ORDER BY NEWID();

                -- Buscar state/city coherente
                SELECT TOP 1
                    @EventStateId = StateId,
                    @EventCityId = CityId
                FROM #CitiesByCountry
                WHERE CountryId = @EventCountryId
                ORDER BY NEWID();
            END

            -- IP aleatoria (guardar en texto plano, cifrar después en batch)
            SET @EventIP = CAST(ABS(CHECKSUM(NEWID()) % 256) AS VARCHAR(3)) + '.' +
                          CAST(ABS(CHECKSUM(NEWID()) % 256) AS VARCHAR(3)) + '.' +
                          CAST(ABS(CHECKSUM(NEWID()) % 256) AS VARCHAR(3)) + '.' +
                          CAST(ABS(CHECKSUM(NEWID()) % 256) AS VARCHAR(3));

            -- =============================================
            -- 5. CAMPAIGN KEYS (80% hereda, 20% nueva)
            -- =============================================
            IF RAND() < 0.80 AND @SourceCampaignKey IS NOT NULL
            BEGIN
                -- Heredar campaña del LeadSource
                SET @CampaignKey = @SourceCampaignKey;
                SET @AdGroupKey = @SourceCampaignKey + '-AG' + RIGHT('0' + CAST((ABS(CHECKSUM(NEWID()) % 5) + 1) AS VARCHAR(2)), 2);
                SET @AdKey = @AdGroupKey + '-AD' + RIGHT('0' + CAST((ABS(CHECKSUM(NEWID()) % 10) + 1) AS VARCHAR(2)), 2);
                SET @ContentKey = @AdKey + '-' + CASE ABS(CHECKSUM(NEWID()) % 4)
                    WHEN 0 THEN 'IMG'
                    WHEN 1 THEN 'VID'
                    WHEN 2 THEN 'TXT'
                    ELSE 'CAR'
                END;
            END
            ELSE IF @EventCategoryKey = 'CONVERSION' OR @EventTypeName LIKE '%FORM%'
            BEGIN
                -- Eventos de conversión casi siempre tienen campaña
                SET @CampaignKey = 'CAMP-' + CAST(YEAR(@EventOccurredAt) AS VARCHAR(4)) +
                                   RIGHT('0' + CAST(MONTH(@EventOccurredAt) AS VARCHAR(2)), 2) + '-' +
                                   CASE ABS(CHECKSUM(NEWID()) % 3)
                                       WHEN 0 THEN 'META'
                                       WHEN 1 THEN 'GOOGLE'
                                       ELSE 'EMAIL'
                                   END;
                SET @AdGroupKey = @CampaignKey + '-AG01';
                SET @AdKey = @AdGroupKey + '-AD01';
                SET @ContentKey = @AdKey + '-IMG';
            END
            ELSE IF @EventTypeName LIKE 'EMAIL%'
            BEGIN
                -- Emails tienen estructura especial
                SET @CampaignKey = 'EMAIL-NURTURE-W' + CAST(ABS(CHECKSUM(NEWID()) % 12) + 1 AS VARCHAR(2));
                SET @AdGroupKey = NULL;
                SET @AdKey = NULL;
                SET @ContentKey = 'TEMPLATE-V' + CAST(ABS(CHECKSUM(NEWID()) % 5) + 1 AS VARCHAR(1));
            END
            ELSE
            BEGIN
                -- Contenido orgánico o sin campaña
                SET @CampaignKey = NULL;
                SET @AdGroupKey = NULL;
                SET @AdKey = NULL;
                SET @ContentKey = NULL;
            END

            -- =============================================
            -- 6. DEVICE CONTEXT (70% hereda, 30% varía)
            -- =============================================
            IF RAND() < 0.70 AND @SourceDeviceTypeId IS NOT NULL
            BEGIN
                -- Heredar del LeadSource
                SET @DeviceTypeId = @SourceDeviceTypeId;
                SET @DevicePlatformId = @SourceDevicePlatformId;
                SET @BrowserId = @SourceBrowserId;
                SET @MediumId = @SourceMediumId;
                SET @OriginChannelId = @SourceOriginChannelId;
            END
            ELSE
            BEGIN
                -- Nuevo dispositivo (multi-device journey)
                SELECT TOP 1 @DeviceTypeId = DeviceTypeId
                FROM #DeviceTypes
                ORDER BY NEWID();

                -- Seleccionar platform/browser coherente
                SELECT TOP 1
                    @DevicePlatformId = PlatformId,
                    @BrowserId = BrowserId
                FROM #DeviceCoherence
                WHERE DeviceTypeId = @DeviceTypeId
                ORDER BY NEWID();

                -- Si no hay coherencia, aleatorio
                IF @DevicePlatformId IS NULL
                BEGIN
                    SELECT TOP 1 @DevicePlatformId = PlatformId FROM #DevicePlatforms ORDER BY NEWID();
                    SELECT TOP 1 @BrowserId = BrowserId FROM #Browsers ORDER BY NEWID();
                END

                -- Medium coherente con tipo de evento
                IF @EventTypeName LIKE 'EMAIL%'
                    SELECT @MediumId = MediumId FROM #Mediums WHERE MediumKey = 'EMAIL';
                ELSE IF @EventTypeName LIKE 'VIDEO%'
                    SELECT TOP 1 @MediumId = MediumId FROM #Mediums WHERE MediumKey IN ('VIDEO', 'SOCIAL') ORDER BY NEWID();
                ELSE
                    SELECT TOP 1 @MediumId = MediumId FROM #Mediums ORDER BY NEWID();

                -- Origin channel coherente con medium
                SELECT TOP 1 @OriginChannelId = OriginChannelId
                FROM #MediumChannelCoherence
                WHERE MediumId = @MediumId
                ORDER BY NEWID();

                IF @OriginChannelId IS NULL
                    SELECT TOP 1 @OriginChannelId = OriginChannelId FROM #OriginChannels ORDER BY NEWID();
            END

            -- =============================================
            -- 7. METADATA (estructurado por tipo de evento)
            -- =============================================
            SET @Metadata = CASE
                WHEN @EventTypeName = 'PAGE_VIEW' THEN
                    '{"page_url":"/products/plan-' + CAST(ABS(CHECKSUM(NEWID()) % 5) + 1 AS VARCHAR(1)) +
                    '","page_title":"Product Page","referrer":"' +
                    CASE ABS(CHECKSUM(NEWID()) % 3)
                        WHEN 0 THEN 'google.com'
                        WHEN 1 THEN 'facebook.com'
                        ELSE 'direct'
                    END +
                    '","scroll_depth":' + CAST(20 + ABS(CHECKSUM(NEWID()) % 80) AS VARCHAR(3)) +
                    ',"time_on_page":' + CAST(10 + ABS(CHECKSUM(NEWID()) % 180) AS VARCHAR(3)) + '}'

                WHEN @EventTypeName IN ('FORM_SUBMIT', 'FORM_START') THEN
                    '{"form_id":"form-' + CAST(ABS(CHECKSUM(NEWID()) % 10) + 1 AS VARCHAR(2)) +
                    '","form_name":"Contact Form","fields_filled":' + CAST(2 + ABS(CHECKSUM(NEWID()) % 5) AS VARCHAR(1)) +
                    ',"submit_time":' + CAST(30 + ABS(CHECKSUM(NEWID()) % 300) AS VARCHAR(3)) + '}'

                WHEN @EventTypeName LIKE 'VIDEO%' THEN
                    '{"video_id":"vid-' + CAST(ABS(CHECKSUM(NEWID()) % 100) + 1 AS VARCHAR(3)) +
                    '","duration":' + CAST(30 + ABS(CHECKSUM(NEWID()) % 600) AS VARCHAR(3)) +
                    ',"watch_pct":' +
                    CASE @EventTypeName
                        WHEN 'VIDEO_25' THEN '25'
                        WHEN 'VIDEO_50' THEN '50'
                        WHEN 'VIDEO_75' THEN '75'
                        WHEN 'VIDEO_100' THEN '100'
                        ELSE CAST(ABS(CHECKSUM(NEWID()) % 100) AS VARCHAR(3))
                    END + '}'

                WHEN @EventTypeName LIKE 'EMAIL%' THEN
                    '{"campaign":"' + ISNULL(@CampaignKey, 'UNKNOWN') +
                    '","subject":"Promo Email","email_client":"' +
                    CASE ABS(CHECKSUM(NEWID()) % 3)
                        WHEN 0 THEN 'Gmail'
                        WHEN 1 THEN 'Outlook'
                        ELSE 'Apple Mail'
                    END + '"}'

                WHEN @EventTypeName IN ('ADD_TO_CART', 'PURCHASE', 'CHECKOUT_START') THEN
                    '{"product_id":"PROD-' + CAST(ABS(CHECKSUM(NEWID()) % 50) + 1 AS VARCHAR(3)) +
                    '","quantity":' + CAST(1 + ABS(CHECKSUM(NEWID()) % 3) AS VARCHAR(1)) +
                    ',"price":' + CAST(50 + ABS(CHECKSUM(NEWID()) % 500) AS VARCHAR(4)) +
                    ',"currency":"USD"}'

                WHEN @EventTypeName = 'DOWNLOAD' THEN
                    '{"file_name":"whitepaper-' + CAST(ABS(CHECKSUM(NEWID()) % 20) + 1 AS VARCHAR(2)) +
                    '.pdf","file_size_kb":' + CAST(500 + ABS(CHECKSUM(NEWID()) % 5000) AS VARCHAR(5)) + '}'

                WHEN @EventTypeName = 'CALL' THEN
                    '{"call_duration":' + CAST(60 + ABS(CHECKSUM(NEWID()) % 600) AS VARCHAR(4)) +
                    ',"call_outcome":"' +
                    CASE ABS(CHECKSUM(NEWID()) % 3)
                        WHEN 0 THEN 'answered'
                        WHEN 1 THEN 'voicemail'
                        ELSE 'no_answer'
                    END + '"}'

                ELSE
                    '{"event":"' + @EventTypeName + '","timestamp":"' + CONVERT(VARCHAR(30), @EventOccurredAt, 127) + '"}'
            END;

            -- =============================================
            -- 8. CHECKSUM (integridad)
            -- =============================================
            SET @ChecksumSource = CONCAT(
                CAST(@LeadId AS VARCHAR(10)), '|',
                CAST(@EventTypeId AS VARCHAR(10)), '|',
                CONVERT(VARCHAR(30), @EventOccurredAt, 127), '|',
                ISNULL(@CampaignKey, ''), '|',
                ISNULL(@EventIP, '')
            );

            SET @Checksum = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @ChecksumSource), 2);

            -- =============================================
            -- 9. INSERTAR EN BATCH (IP sin cifrar aún)
            -- =============================================
            INSERT INTO #BatchEvents (
                LeadId, LeadSourceId, LeadEventTypeId, LeadEventSourceId,
                OccurredAt, CountryId, StateId, CityId, IpAddressClearText,
                CampaignKey, AdGroupKey, AdKey, ContentKey,
                MediumId, OriginChannelId,
                DeviceTypeId, DevicePlatformId, BrowserId,
                Metadata, Checksum
            )
            VALUES (
                @LeadId, @LeadSourceId, @EventTypeId, @EventSourceId,
                @EventOccurredAt, @EventCountryId, @EventStateId, @EventCityId, @EventIP,
                @CampaignKey, @AdGroupKey, @AdKey, @ContentKey,
                @MediumId, @OriginChannelId,
                @DeviceTypeId, @DevicePlatformId, @BrowserId,
                @Metadata, @Checksum
            );

            SET @EventNum = @EventNum + 1;
        END

        FETCH NEXT FROM lead_cursor INTO
            @LeadId, @LeadSourceId, @LeadCreatedAt, @SubscriberId,
            @LeadCountryId, @LeadStateId, @LeadCityId,
            @SourceCampaignKey, @SourceDeviceTypeId, @SourceDevicePlatformId, @SourceBrowserId,
            @SourceMediumId, @SourceOriginChannelId;
    END

    CLOSE lead_cursor;
    DEALLOCATE lead_cursor;

    -- =============================================
    -- CIFRADO BATCH DE IPs (OPTIMIZACIÓN v3.0)
    -- =============================================
    DECLARE @EventsToEncrypt INT = (SELECT COUNT(*) FROM #BatchEvents WHERE IpAddressClearText IS NOT NULL);

    IF @EventsToEncrypt > 0
    BEGIN
        PRINT '    → Cifrando ' + FORMAT(@EventsToEncrypt, 'N0') + ' IPs en batch...';

        -- Abrir llave simétrica UNA SOLA VEZ para todo el batch
        EXEC sp_executesql N'
            EXEC master.sys.sp_executesql N''
                OPEN SYMMETRIC KEY SK_PromptCRM_Master_Key
                DECRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;
            ''
        ';

        -- Cifrar TODAS las IPs del batch de una sola vez
        UPDATE #BatchEvents
        SET IpAddressEncrypted = ENCRYPTBYKEY(KEY_GUID('SK_PromptCRM_Master_Key'), IpAddressClearText)
        WHERE IpAddressClearText IS NOT NULL;

        -- Cerrar llave simétrica
        EXEC sp_executesql N'
            EXEC master.sys.sp_executesql N''
                CLOSE SYMMETRIC KEY SK_PromptCRM_Master_Key;
            ''
        ';
    END

    -- =============================================
    -- INSERT MASIVO en tabla particionada (con IP cifrada)
    -- =============================================
    INSERT INTO [crm].[LeadEvents] WITH (TABLOCK) (
        leadId, leadSourceId, leadEventTypeId, leadEventSourceId,
        occurredAt, countryId, StateId, cityId, ipAddress,
        campaignKey, adGroupKey, adKey, contentKey,
        mediumId, originChannelId,
        deviceTypeId, devicePlatformId, browserId,
        metadata, checksum
    )
    SELECT
        LeadId, LeadSourceId, LeadEventTypeId, LeadEventSourceId,
        OccurredAt, CountryId, StateId, CityId,
        IpAddressEncrypted,
        CampaignKey, AdGroupKey, AdKey, ContentKey,
        MediumId, OriginChannelId,
        DeviceTypeId, DevicePlatformId, BrowserId,
        Metadata, Checksum
    FROM #BatchEvents;

    DECLARE @EventsInBatch BIGINT = @@ROWCOUNT;
    SET @TotalEvents = @TotalEvents + @EventsInBatch;
    SET @ProcessedLeads = @ProcessedLeads + @LeadsInBatch;

    DROP TABLE #BatchEvents;

    SET @BatchSeconds = DATEDIFF(SECOND, @BatchStartTime, GETUTCDATE());
    DECLARE @AvgEventsPerLead DECIMAL(10,2) = CAST(@EventsInBatch AS DECIMAL(18,2)) / NULLIF(@LeadsInBatch, 0);

    PRINT '  ✓ Batch completado en ' + CAST(@BatchSeconds AS VARCHAR(10)) + 's';
    PRINT '    • Leads procesados: ' + FORMAT(@LeadsInBatch, 'N0');
    PRINT '    • Eventos generados: ' + FORMAT(@EventsInBatch, 'N0') + ' (promedio: ' + CAST(@AvgEventsPerLead AS VARCHAR(10)) + ' por lead)';
    PRINT '    • Total acumulado: ' + FORMAT(@TotalEvents, 'N0') + ' eventos de ' + FORMAT(@ProcessedLeads, 'N0') + ' leads';
    PRINT '';

    SET @CurrentBatch = @CurrentBatch + 1;
END

-- Cleanup
DROP TABLE #LeadsToProcess;
DROP TABLE #EventTypes;
DROP TABLE #EventSources;
DROP TABLE #Countries;
DROP TABLE #CitiesByCountry;
DROP TABLE #Mediums;
DROP TABLE #OriginChannels;
DROP TABLE #DeviceTypes;
DROP TABLE #DevicePlatforms;
DROP TABLE #Browsers;
DROP TABLE #DeviceCoherence;
DROP TABLE #MediumChannelCoherence;

SkipEventGeneration:

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ GENERACIÓN DE LEAD EVENTS COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '  Total generado: ' + FORMAT(@TotalEvents, 'N0') + ' eventos';
PRINT '  Leads procesados: ' + FORMAT(@ProcessedLeads, 'N0');
PRINT '';

-- Estadísticas por tipo de evento
PRINT '  Distribución por tipo de evento:';
SELECT
    let.eventTypeName AS TipoEvento,
    FORMAT(COUNT(*), 'N0') AS TotalEventos,
    FORMAT((CAST(COUNT(*) AS DECIMAL(18,2)) / NULLIF(@TotalEvents, 0)) * 100, 'N2') + '%' AS Porcentaje
FROM [crm].[LeadEvents] le
INNER JOIN [crm].[LeadEventTypes] let ON le.leadEventTypeId = let.leadEventTypeId
GROUP BY let.eventTypeName
ORDER BY COUNT(*) DESC;

PRINT '';
PRINT '  Campos poblados por evento:';
SELECT
    'Campos de Campaña' AS Categoria,
    FORMAT(SUM(CASE WHEN campaignKey IS NOT NULL THEN 1 ELSE 0 END), 'N0') AS Total,
    FORMAT((CAST(SUM(CASE WHEN campaignKey IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18,2)) / COUNT(*)) * 100, 'N1') + '%' AS Porcentaje
FROM [crm].[LeadEvents]
UNION ALL
SELECT
    'Geolocalización Completa',
    FORMAT(SUM(CASE WHEN countryId IS NOT NULL AND StateId IS NOT NULL AND cityId IS NOT NULL THEN 1 ELSE 0 END), 'N0'),
    FORMAT((CAST(SUM(CASE WHEN countryId IS NOT NULL AND StateId IS NOT NULL AND cityId IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18,2)) / COUNT(*)) * 100, 'N1') + '%'
FROM [crm].[LeadEvents]
UNION ALL
SELECT
    'Device Context Completo',
    FORMAT(SUM(CASE WHEN deviceTypeId IS NOT NULL AND devicePlatformId IS NOT NULL AND browserId IS NOT NULL THEN 1 ELSE 0 END), 'N0'),
    FORMAT((CAST(SUM(CASE WHEN deviceTypeId IS NOT NULL AND devicePlatformId IS NOT NULL AND browserId IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18,2)) / COUNT(*)) * 100, 'N1') + '%'
FROM [crm].[LeadEvents]
UNION ALL
SELECT
    'Metadata JSON',
    FORMAT(SUM(CASE WHEN metadata IS NOT NULL THEN 1 ELSE 0 END), 'N0'),
    FORMAT((CAST(SUM(CASE WHEN metadata IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18,2)) / COUNT(*)) * 100, 'N1') + '%'
FROM [crm].[LeadEvents]
UNION ALL
SELECT
    'Checksum',
    FORMAT(SUM(CASE WHEN checksum IS NOT NULL THEN 1 ELSE 0 END), 'N0'),
    FORMAT((CAST(SUM(CASE WHEN checksum IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18,2)) / COUNT(*)) * 100, 'N1') + '%'
FROM [crm].[LeadEvents];

PRINT '';
