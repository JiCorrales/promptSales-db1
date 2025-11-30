
Use PromptCRM
GO

SET NOCOUNT ON;

PRINT 'Generando 1.5 millones de Leads + LeadSources en batches...';
PRINT '';

-- Limpieza defensiva de temp tables si el script falló antes
IF OBJECT_ID('tempdb..#SubscriberWeights') IS NOT NULL DROP TABLE #SubscriberWeights;
IF OBJECT_ID('tempdb..#CountryIds') IS NOT NULL DROP TABLE #CountryIds;
IF OBJECT_ID('tempdb..#SourceTypes') IS NOT NULL DROP TABLE #SourceTypes;
IF OBJECT_ID('tempdb..#Systems') IS NOT NULL DROP TABLE #Systems;
IF OBJECT_ID('tempdb..#Mediums') IS NOT NULL DROP TABLE #Mediums;
IF OBJECT_ID('tempdb..#Channels') IS NOT NULL DROP TABLE #Channels;
IF OBJECT_ID('tempdb..#Devices') IS NOT NULL DROP TABLE #Devices;
IF OBJECT_ID('tempdb..#Platforms') IS NOT NULL DROP TABLE #Platforms;
IF OBJECT_ID('tempdb..#Browsers') IS NOT NULL DROP TABLE #Browsers;
IF OBJECT_ID('tempdb..#PromptAdsCampaigns') IS NOT NULL DROP TABLE #PromptAdsCampaigns;
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;
IF OBJECT_ID('tempdb..#CampaignLeadSlots') IS NOT NULL DROP TABLE #CampaignLeadSlots;
IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
IF OBJECT_ID('tempdb..#BatchLeads') IS NOT NULL DROP TABLE #BatchLeads;
IF OBJECT_ID('tempdb..#GenderIds') IS NOT NULL DROP TABLE #GenderIds;
IF OBJECT_ID('tempdb..#RaceIds') IS NOT NULL DROP TABLE #RaceIds;
IF OBJECT_ID('tempdb..#EthnicityIds') IS NOT NULL DROP TABLE #EthnicityIds;
IF OBJECT_ID('tempdb..#StateIds') IS NOT NULL DROP TABLE #StateIds;
IF OBJECT_ID('tempdb..#CityIds') IS NOT NULL DROP TABLE #CityIds;

-- =============================================
-- CONFIGURACIÓN
-- =============================================
DECLARE @TargetLeadCount INT = 1500000;
DECLARE @MaxPromptAdsCampaigns INT = 1000; -- Limitar campañas utilizadas
DECLARE @BatchSize INT = 50000;
DECLARE @TotalBatches INT = @TargetLeadCount / @BatchSize;
DECLARE @CurrentBatch INT = 1;
DECLARE @LeadsGenerated BIGINT = 0;
DECLARE @BatchStartTime DATETIME2;
DECLARE @BatchSeconds INT;

-- Probabilidades de completitud de datos (%)
DECLARE @ProbCompleteData DECIMAL(5,2) = 0.05; -- 5% datos completos
DECLARE @ProbHasFirstName DECIMAL(5,2) = 0.60;
DECLARE @ProbHasLastName DECIMAL(5,2) = 0.55;
DECLARE @ProbHasEmail DECIMAL(5,2) = 0.40;
DECLARE @ProbHasPhone DECIMAL(5,2) = 0.25;
DECLARE @ProbHasGender DECIMAL(5,2) = 0.30;
-- ★ Demographics probabilities
DECLARE @ProbHasRace DECIMAL(5,2) = 0.50;       -- 50% tienen race
DECLARE @ProbHasEthnicity DECIMAL(5,2) = 0.45;  -- 45% tienen ethnicity
-- ★ Geography probabilities (buckets)
-- 40% City+State+Country, 20% State+Country, 20% Country, 20% NULL
DECLARE @LeadStatusActiveId INT;

-- =============================================
-- CARGAR CATÁLOGOS EN MEMORIA
-- =============================================
PRINT 'Cargando catálogos en memoria...';

-- Tabla temporal para Subscribers con distribución de peso
CREATE TABLE #SubscriberWeights (
    SubscriberId INT,
    Weight DECIMAL(5,2),
    CumulativeWeight DECIMAL(5,2)
);

-- Asignar pesos aleatorios pero razonables a cada subscriber
INSERT INTO #SubscriberWeights (SubscriberId, Weight)
SELECT
    subscriberId,
    CASE
        WHEN subscriberId <= 3 THEN 0.15  -- Primeros 3: 15% cada uno
        WHEN subscriberId <= 6 THEN 0.10  -- Siguientes 3: 10% cada uno
        ELSE 0.05  -- Resto: 5% cada uno
    END
FROM [crm].[Subscribers]
WHERE status = 'ACTIVE';

-- Fallback: si no hay ACTIVE, usar todos los subscribers habilitados
DECLARE @SubscriberCount INT = (SELECT COUNT(*) FROM #SubscriberWeights);
IF @SubscriberCount = 0
BEGIN
    INSERT INTO #SubscriberWeights (SubscriberId, Weight)
    SELECT subscriberId, 1.0
    FROM [crm].[Subscribers];
    SET @SubscriberCount = (SELECT COUNT(*) FROM #SubscriberWeights);
END

IF @SubscriberCount = 0
BEGIN
    RAISERROR('No hay subscribers disponibles para generar leads.', 16, 1);
    RETURN;
END

-- Calcular pesos acumulativos para sampling
DECLARE @TotalWeight DECIMAL(10,2);
SELECT @TotalWeight = SUM(Weight) FROM #SubscriberWeights;

IF ISNULL(@TotalWeight, 0) = 0
BEGIN
    RAISERROR('No se pudieron calcular pesos de subscribers.', 16, 1);
    RETURN;
END

UPDATE #SubscriberWeights
SET Weight = Weight / @TotalWeight;  -- Normalizar a suma = 1.0

WITH CumulativeCalc AS (
    SELECT
        SubscriberId,
        Weight,
        SUM(Weight) OVER (ORDER BY SubscriberId) AS CumulativeWeight
    FROM #SubscriberWeights
)
UPDATE sw
SET sw.CumulativeWeight = c.CumulativeWeight
FROM #SubscriberWeights sw
INNER JOIN CumulativeCalc c ON sw.SubscriberId = c.SubscriberId;

PRINT '  ✓ ' + CAST(@SubscriberCount AS VARCHAR(10)) + ' subscribers cargados';

-- Tabla temporal para Countries
CREATE TABLE #CountryIds (
    CountryId INT PRIMARY KEY
);

INSERT INTO #CountryIds (CountryId)
SELECT countryId FROM [crm].[Countries] WHERE enabled = 1;

DECLARE @CountryCount INT = (SELECT COUNT(*) FROM #CountryIds);
PRINT '  ✓ ' + CAST(@CountryCount AS VARCHAR(10)) + ' países disponibles';

-- Catálogos para LeadSources (coherencia semántica)
CREATE TABLE #SourceTypes (SourceTypeId INT, SourceTypeName VARCHAR(60));
CREATE TABLE #Systems (SystemId INT, SystemName VARCHAR(60));
CREATE TABLE #Mediums (MediumId INT, MediumName VARCHAR(60));
CREATE TABLE #Channels (ChannelId INT, ChannelName VARCHAR(60));
CREATE TABLE #Devices (DeviceId INT, DeviceName VARCHAR(60));
CREATE TABLE #Platforms (PlatformId INT, PlatformName VARCHAR(60));
CREATE TABLE #Browsers (BrowserId INT, BrowserName VARCHAR(60));

INSERT INTO #SourceTypes SELECT leadSourceTypeId, sourceTypeName FROM [crm].[LeadSourceTypes] WHERE enabled = 1;
INSERT INTO #Systems SELECT leadSourceSystemId, systemName FROM [crm].[LeadSourceSystems] WHERE enabled = 1;
INSERT INTO #Mediums SELECT leadMediumId, leadMediumName FROM [crm].[LeadMediums] WHERE enabled = 1;
INSERT INTO #Channels SELECT leadOriginChannelId, leadOriginChannelName FROM [crm].[LeadOriginChannels] WHERE enabled = 1;
INSERT INTO #Devices SELECT deviceTypeId, deviceTypeName FROM [crm].[DeviceTypes] WHERE enabled = 1;
INSERT INTO #Platforms SELECT devicePlatformId, devicePlatformName FROM [crm].[DevicePlatforms] WHERE enabled = 1;
INSERT INTO #Browsers SELECT browserId, browserName FROM [crm].[Browsers] WHERE enabled = 1;

-- ★ Demographic catalogs (gender, race, ethnicity)
CREATE TABLE #GenderIds (GenderId INT PRIMARY KEY);
INSERT INTO #GenderIds (GenderId)
SELECT demographicGenderId FROM [crm].[DemographicGenders] WHERE enabled = 1;

CREATE TABLE #RaceIds (RaceId INT PRIMARY KEY);
INSERT INTO #RaceIds (RaceId)
SELECT demographicRaceId FROM [crm].[DemographicRaces] WHERE enabled = 1;

CREATE TABLE #EthnicityIds (EthnicityId INT PRIMARY KEY);
INSERT INTO #EthnicityIds (EthnicityId)
SELECT demographicEthnicityId FROM [crm].[DemographicEthnicities] WHERE enabled = 1;

-- ★ Geography catalogs (states, cities with coherence)
CREATE TABLE #StateIds (StateId INT PRIMARY KEY, CountryId INT);
INSERT INTO #StateIds (StateId, CountryId)
SELECT stateId, countryId FROM [crm].[States] WHERE enabled = 1;

CREATE TABLE #CityIds (CityId INT PRIMARY KEY, StateId INT, CountryId INT);
INSERT INTO #CityIds (CityId, StateId, CountryId)
SELECT c.cityId, c.stateId, s.countryId
FROM [crm].[Cities] c
INNER JOIN [crm].[States] s ON s.stateId = c.stateId AND s.enabled = 1
WHERE c.enabled = 1;

-- Lead status activo (usar uno coherente y fijo para todos)
SELECT TOP 1 @LeadStatusActiveId = leadStatusId
FROM [crm].[LeadStatus]
WHERE enabled = 1
ORDER BY leadStatusId;

IF @LeadStatusActiveId IS NULL
BEGIN
    RAISERROR('No hay LeadStatus habilitados en crm.LeadStatus.', 16, 1);
    RETURN;
END

PRINT '  ✓ Catálogos de LeadSource cargados';

-- =============================================
-- CARGAR CAMPAÑAS REALES DE PROMPTADS
-- ★ v3.1: INCLUYE FECHAS PARA TEMPORALIDAD
-- =============================================
PRINT '  Cargando campañas de PromptAds con fechas (Julio 2024 - Enero 2026)...';

CREATE TABLE #PromptAdsCampaigns (
    RowNum INT IDENTITY(1,1),
    CampaignId BIGINT,
    CampaignKey VARCHAR(255),
    StartDate DATETIME2,          -- ★ NUEVO: Fecha inicio de campaña
    EndDate DATETIME2,            -- ★ NUEVO: Fecha fin de campaña
    DurationDays INT,             -- ★ NUEVO: Duración en días
    LeadsToGenerate INT DEFAULT 0 -- ★ NUEVO: Leads a asignar a esta campaña
);

-- Obtener campañas de PromptAds CON FECHAS dentro del período Julio 2024 - Enero 2026
-- Límite: @MaxPromptAdsCampaigns = 1000 campañas ALEATORIAS (no secuenciales)
INSERT INTO #PromptAdsCampaigns (CampaignId, CampaignKey, StartDate, EndDate, DurationDays)
SELECT TOP (@MaxPromptAdsCampaigns)
    CampaignId,
    'CAMP-' + CAST(CampaignId AS VARCHAR(20)),
    startDate,
    endDate,
    DATEDIFF(DAY, startDate, endDate)
FROM OPENQUERY([PromptAds_LinkedServer],
    'SELECT CampaignId, startDate, endDate
     FROM PromptAds.dbo.Campaigns
     WHERE startDate >= ''2024-07-01''
       AND endDate <= ''2026-01-31''')
ORDER BY NEWID();  -- Selección aleatoria para mejor distribución

DECLARE @CampaignCount INT = (SELECT COUNT(*) FROM #PromptAdsCampaigns);

IF @CampaignCount = 0
BEGIN
    PRINT '  ⚠️  ERROR: No se pudieron cargar campañas de PromptAds.';
    PRINT '  ⚠️  Verifique que el Linked Server [PromptAds_LinkedServer] esté configurado.';
    RAISERROR('No se pueden generar leads sin campañas de PromptAds', 16, 1);
    RETURN;
END

PRINT '  ✓ ' + CAST(@CampaignCount AS VARCHAR(10)) + ' campañas cargadas desde PromptAds (con fechas)';

-- ★ DISTRIBUIR 1.5M LEADS ENTRE CAMPAÑAS
-- Campañas largas obtienen más leads que campañas cortas (realista)
UPDATE #PromptAdsCampaigns
SET LeadsToGenerate =
    CASE
        -- Campañas largas (>60 días): 1400-1799 leads
        WHEN DurationDays > 60 THEN 1400 + (ABS(CHECKSUM(NEWID())) % 400)
        -- Campañas medianas (30-60 días): 1200-1499 leads
        WHEN DurationDays > 30 THEN 1200 + (ABS(CHECKSUM(NEWID())) % 300)
        -- Campañas cortas (<=30 días): 1000-1299 leads
        ELSE 1000 + (ABS(CHECKSUM(NEWID())) % 300)
    END;

DECLARE @ActualLeadsDistributed INT = (SELECT SUM(LeadsToGenerate) FROM #PromptAdsCampaigns);
DECLARE @ScaleFactor DECIMAL(18,8) = CAST(@TargetLeadCount AS DECIMAL(18,8)) / NULLIF(@ActualLeadsDistributed, 0);

-- Reescalar para aproximar al target total
UPDATE #PromptAdsCampaigns
SET LeadsToGenerate = CAST(ROUND(LeadsToGenerate * @ScaleFactor, 0) AS INT);

-- Ajuste fino por residuo
DECLARE @Residual INT = @TargetLeadCount - (SELECT SUM(LeadsToGenerate) FROM #PromptAdsCampaigns);
IF @Residual <> 0
BEGIN
    WITH cte AS (
        SELECT TOP (ABS(@Residual)) RowNum
        FROM #PromptAdsCampaigns
        ORDER BY NEWID()
    )
    UPDATE c
    SET LeadsToGenerate = LeadsToGenerate + CASE WHEN @Residual > 0 THEN 1 ELSE -1 END
    FROM #PromptAdsCampaigns c
    JOIN cte ON c.RowNum = cte.RowNum;
END

SET @ActualLeadsDistributed = (SELECT SUM(LeadsToGenerate) FROM #PromptAdsCampaigns);
PRINT '  ✓ Distribución planificada: ' + FORMAT(@ActualLeadsDistributed, 'N0') + ' leads (~' + CAST(@ActualLeadsDistributed / @CampaignCount AS VARCHAR(10)) + ' leads/campaña)';

-- Expandir slots de leads por campaña para asignación determinística (exacta)
-- Generar tabla de números hasta @TargetLeadCount de forma más liviana
;WITH Tally AS (
    SELECT TOP (@TargetLeadCount)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b  -- ~4M filas, suficiente para 1.5M
)
SELECT n AS n
INTO #Numbers
FROM Tally;

-- Rango acumulado por campaña
;WITH CampaignRanges AS (
    SELECT CampaignId, CampaignKey, StartDate, EndDate, DurationDays, LeadsToGenerate,
           SUM(LeadsToGenerate) OVER (ORDER BY CampaignId) AS CumEnd,
           SUM(LeadsToGenerate) OVER (ORDER BY CampaignId) - LeadsToGenerate + 1 AS CumStart
    FROM #PromptAdsCampaigns
)
SELECT n.n AS RowNum,
       c.CampaignId,
       c.CampaignKey,
       c.StartDate,
       c.EndDate,
       c.DurationDays
INTO #CampaignLeadSlots
FROM #Numbers n
JOIN CampaignRanges c
  ON n.n BETWEEN c.CumStart AND c.CumEnd
ORDER BY n.n;

CREATE CLUSTERED INDEX IX_CampaignLeadSlots_RowNum ON #CampaignLeadSlots(RowNum);

DROP TABLE #Numbers;

-- Arrays de nombres y apellidos para generación
CREATE TABLE #FirstNames (RowNum INT IDENTITY(1,1), FirstName VARCHAR(60));
CREATE TABLE #LastNames (RowNum INT IDENTITY(1,1), LastName VARCHAR(60));

INSERT INTO #FirstNames (FirstName) VALUES
('John'),('Maria'),('James'),('Jennifer'),('Robert'),('Linda'),('Michael'),('Patricia'),
('William'),('Elizabeth'),('David'),('Sarah'),('Richard'),('Jessica'),('Joseph'),('Karen'),
('Thomas'),('Nancy'),('Charles'),('Lisa'),('Christopher'),('Betty'),('Daniel'),('Margaret'),
('Matthew'),('Sandra'),('Anthony'),('Ashley'),('Mark'),('Dorothy'),('Donald'),('Kimberly'),
('Steven'),('Emily'),('Paul'),('Donna'),('Andrew'),('Michelle'),('Joshua'),('Carol'),
('Kenneth'),('Amanda'),('Kevin'),('Melissa'),('Brian'),('Deborah'),('George'),('Stephanie'),
('Edward'),('Rebecca'),('Ronald'),('Sharon'),('Timothy'),('Laura'),('Jason'),('Cynthia'),
('Jeffrey'),('Kathleen'),('Ryan'),('Amy'),('Jacob'),('Shirley'),('Gary'),('Angela'),
('Nicholas'),('Helen'),('Eric'),('Anna'),('Jonathan'),('Brenda'),('Stephen'),('Pamela'),
('Larry'),('Nicole'),('Justin'),('Emma'),('Scott'),('Samantha'),('Brandon'),('Katherine'),
('Benjamin'),('Christine'),('Samuel'),('Debra'),('Raymond'),('Rachel'),('Gregory'),('Catherine'),
('Frank'),('Carolyn'),('Alexander'),('Janet'),('Patrick'),('Ruth'),('Raymond'),('Maria'),
('Jack'),('Heather'),('Dennis'),('Diane'),('Jerry'),('Virginia'),('Tyler'),('Julie'),
('Aaron'),('Joyce'),('Jose'),('Victoria'),('Adam'),('Olivia'),('Henry'),('Kelly'),
('Nathan'),('Christina'),('Douglas'),('Lauren'),('Zachary'),('Joan'),('Peter'),('Evelyn'),
('Kyle'),('Judith'),('Walter'),('Megan'),('Ethan'),('Cheryl'),('Jeremy'),('Andrea'),
('Harold'),('Hannah'),('Keith'),('Jacqueline'),('Christian'),('Martha'),('Roger'),('Gloria'),
('Noah'),('Teresa'),('Gerald'),('Ann'),('Carl'),('Sara'),('Terry'),('Madison'),
('Sean'),('Frances'),('Austin'),('Kathryn'),('Arthur'),('Janice'),('Lawrence'),('Jean');

INSERT INTO #LastNames (LastName) VALUES
('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),
('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),('Thomas'),
('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),('White'),
('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson'),('Walker'),('Young'),
('Allen'),('King'),('Wright'),('Scott'),('Torres'),('Nguyen'),('Hill'),('Flores'),
('Green'),('Adams'),('Nelson'),('Baker'),('Hall'),('Rivera'),('Campbell'),('Mitchell'),
('Carter'),('Roberts'),('Gomez'),('Phillips'),('Evans'),('Turner'),('Diaz'),('Parker'),
('Cruz'),('Edwards'),('Collins'),('Reyes'),('Stewart'),('Morris'),('Morales'),('Murphy'),
('Cook'),('Rogers'),('Gutierrez'),('Ortiz'),('Morgan'),('Cooper'),('Peterson'),('Bailey'),
('Reed'),('Kelly'),('Howard'),('Ramos'),('Kim'),('Cox'),('Ward'),('Richardson'),
('Watson'),('Brooks'),('Chavez'),('Wood'),('James'),('Bennett'),('Gray'),('Mendoza'),
('Ruiz'),('Hughes'),('Price'),('Alvarez'),('Castillo'),('Sanders'),('Patel'),('Myers'),
('Long'),('Ross'),('Foster'),('Jimenez'),('Powell'),('Jenkins'),('Perry'),('Russell'),
('Sullivan'),('Bell'),('Coleman'),('Butler'),('Henderson'),('Barnes'),('Gonzales'),('Fisher'),
('Vasquez'),('Simmons'),('Romero'),('Jordan'),('Patterson'),('Alexander'),('Hamilton'),('Graham'),
('Reynolds'),('Griffin'),('Wallace'),('Moreno'),('West'),('Cole'),('Hayes'),('Bryant'),
('Herrera'),('Gibson'),('Ellis'),('Tran'),('Medina'),('Aguilar'),('Stevens'),('Murray'),
('Ford'),('Castro'),('Marshall'),('Owens'),('Harrison'),('Fernandez'),('McDonald'),('Woods'),
('Washington'),('Kennedy'),('Wells'),('Vargas'),('Henry'),('Chen'),('Freeman'),('Webb');

DECLARE @FirstNameCount INT = (SELECT COUNT(*) FROM #FirstNames);
DECLARE @LastNameCount INT = (SELECT COUNT(*) FROM #LastNames);

PRINT '  ✓ ' + CAST(@FirstNameCount AS VARCHAR(10)) + ' nombres, ' + CAST(@LastNameCount AS VARCHAR(10)) + ' apellidos';
PRINT '';

-- =============================================
-- GENERACIÓN EN BATCHES
-- =============================================
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Iniciando generación de ' + CAST(@TotalBatches AS VARCHAR(10)) + ' batches de ' + FORMAT(@BatchSize, 'N0') + ' leads';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

WHILE @CurrentBatch <= @TotalBatches
BEGIN
    SET @BatchStartTime = GETUTCDATE();

    PRINT 'Batch ' + CAST(@CurrentBatch AS VARCHAR(5)) + '/' + CAST(@TotalBatches AS VARCHAR(5)) + ' - Generando ' + FORMAT(@BatchSize, 'N0') + ' leads + sources...';

    -- Crear tabla temporal para este batch
    CREATE TABLE #BatchLeads (
        RowNum INT IDENTITY(1,1),
        FirstName VARCHAR(60),
        LastName VARCHAR(60),
        Email VARCHAR(255),
        PhoneNumber VARCHAR(18),
        LeadToken UNIQUEIDENTIFIER DEFAULT NEWID(),
        LeadStatusId INT DEFAULT 1,  -- NEW
        LeadTierId INT DEFAULT 1,    -- COLD
        SubscriberId INT,
        CountryId INT,
        StateId INT,                      -- ★ NUEVO: Geography
        CityId INT,                       -- ★ NUEVO: Geography
        DemographicGenderId INT,
        DemographicRaceId INT,            -- ★ NUEVO: Demographics
        DemographicEthnicityId INT,       -- ★ NUEVO: Demographics
        CreatedAt DATETIME2,
        -- LeadSource fields
        CampaignKey VARCHAR(255),
        SourceTypeId INT,
        SystemId INT,
        MediumId INT,
        ChannelId INT,
        DeviceId INT,
        PlatformId INT,
        BrowserId INT
    );

    -- Generar datos base para el batch
    DECLARE @i INT = 1;
    DECLARE @RandomVal DECIMAL(10,8);
    DECLARE @SelectedSubscriberId INT;
    DECLARE @SelectedCountryId INT;
    DECLARE @SelectedStateId INT;            -- ★ NUEVO: Geography
    DECLARE @SelectedCityId INT;             -- ★ NUEVO: Geography
    DECLARE @GeneratedFirstName VARCHAR(60);
    DECLARE @GeneratedLastName VARCHAR(60);
    DECLARE @GeneratedEmail VARCHAR(255);
    DECLARE @GeneratedPhone VARCHAR(18);
    DECLARE @GeneratedGender INT;
    DECLARE @GeneratedRace INT;              -- ★ NUEVO: Demographics
    DECLARE @GeneratedEthnicity INT;         -- ★ NUEVO: Demographics
    DECLARE @GeneratedLeadStatusId INT;
    DECLARE @CreatedDate DATETIME2;
    DECLARE @DaysAgo INT;
    DECLARE @GeoBucket INT;                  -- ★ NUEVO: Geography bucket (0-100)

    -- LeadSource variables
    DECLARE @CampaignKey VARCHAR(255);
    DECLARE @CampaignStartDate DATETIME2;  -- ★ NUEVO v3.1
    DECLARE @CampaignEndDate DATETIME2;    -- ★ NUEVO v3.1
    DECLARE @CampaignDurationDays INT;     -- ★ NUEVO v3.1
    DECLARE @SelectedSourceTypeId INT;
    DECLARE @SelectedSystemId INT;
    DECLARE @SelectedMediumId INT;
    DECLARE @SelectedChannelId INT;
    DECLARE @SelectedDeviceId INT;
    DECLARE @SelectedPlatformId INT;
    DECLARE @SelectedBrowserId INT;
    DECLARE @DeviceName VARCHAR(60);
    DECLARE @PlatformName VARCHAR(60);
    DECLARE @SlotRowNum INT;

    WHILE @i <= @BatchSize
    BEGIN
        -- Determinar slot global de lead para asignación exacta de campaña
        SET @SlotRowNum = ((@CurrentBatch - 1) * @BatchSize) + @i;

        -- Seleccionar subscriber basado en distribución de pesos
        SET @RandomVal = RAND();
        SELECT TOP 1 @SelectedSubscriberId = SubscriberId
        FROM #SubscriberWeights
        WHERE CumulativeWeight >= @RandomVal
        ORDER BY CumulativeWeight;

        -- LeadStatus fijo (activo)
        SET @GeneratedLeadStatusId = @LeadStatusActiveId;

        -- Seleccionar Country aleatorio
        SELECT TOP 1 @SelectedCountryId = CountryId
        FROM #CountryIds
        ORDER BY NEWID();

        -- ★ v3.1: Seleccionar campaña según slot (exacto a LeadsToGenerate)
        SELECT
            @CampaignKey = CampaignKey,
            @CampaignStartDate = StartDate,
            @CampaignEndDate = EndDate,
            @CampaignDurationDays = DurationDays
        FROM #CampaignLeadSlots
        WHERE RowNum = @SlotRowNum;

        -- ★ v3.1: Fecha creación aleatoria DENTRO del período de la campaña
        IF @CampaignDurationDays > 0
        BEGIN
            SET @DaysAgo = ABS(CHECKSUM(NEWID()) % (@CampaignDurationDays + 1));
            SET @CreatedDate = DATEADD(DAY, @DaysAgo, @CampaignStartDate);
            -- Agregar hora aleatoria (0-23h)
            SET @CreatedDate = DATEADD(HOUR, ABS(CHECKSUM(NEWID()) % 24), @CreatedDate);
        END
        ELSE
        BEGIN
            -- Si campaña de 1 día, usar startDate + hora aleatoria
            SET @CreatedDate = DATEADD(HOUR, ABS(CHECKSUM(NEWID()) % 24), @CampaignStartDate);
        END

        -- Decidir si tiene datos completos (5% probabilidad)
        IF RAND() < @ProbCompleteData
        BEGIN
            -- Lead con datos COMPLETOS
            SELECT TOP 1 @GeneratedFirstName = FirstName FROM #FirstNames ORDER BY NEWID();
            SELECT TOP 1 @GeneratedLastName = LastName FROM #LastNames ORDER BY NEWID();
            SET @GeneratedEmail = LOWER(@GeneratedFirstName) + '.' + LOWER(@GeneratedLastName) + '@example.com';
            SET @GeneratedPhone = '+1' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID()) % 1000000000) AS VARCHAR(10)), 10);
            IF EXISTS (SELECT 1 FROM #GenderIds)
                SELECT TOP 1 @GeneratedGender = GenderId FROM #GenderIds ORDER BY NEWID();
            ELSE
                SET @GeneratedGender = NULL;
        END
        ELSE
        BEGIN
            -- Lead con datos PARCIALES (realista)
            IF RAND() < @ProbHasFirstName
                SELECT TOP 1 @GeneratedFirstName = FirstName FROM #FirstNames ORDER BY NEWID();
            ELSE
                SET @GeneratedFirstName = NULL;

            IF RAND() < @ProbHasLastName
                SELECT TOP 1 @GeneratedLastName = LastName FROM #LastNames ORDER BY NEWID();
            ELSE
                SET @GeneratedLastName = NULL;

            IF RAND() < @ProbHasEmail
                SET @GeneratedEmail = 'lead' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(20)) + '@temp.com';
            ELSE
                SET @GeneratedEmail = NULL;

            IF RAND() < @ProbHasPhone
                SET @GeneratedPhone = '+1' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID()) % 1000000000) AS VARCHAR(10)), 10);
            ELSE
                SET @GeneratedPhone = NULL;

            IF RAND() < @ProbHasGender AND EXISTS (SELECT 1 FROM #GenderIds)
                SELECT TOP 1 @GeneratedGender = GenderId FROM #GenderIds ORDER BY NEWID();
            ELSE
                SET @GeneratedGender = NULL;
        END

        -- =========================================
        -- ★ DEMOGRAPHICS: Race / Ethnicity (parciales)
        -- =========================================
        IF RAND() < @ProbHasRace AND EXISTS (SELECT 1 FROM #RaceIds)
            SELECT TOP 1 @GeneratedRace = RaceId FROM #RaceIds ORDER BY NEWID();
        ELSE
            SET @GeneratedRace = NULL;

        IF RAND() < @ProbHasEthnicity AND EXISTS (SELECT 1 FROM #EthnicityIds)
            SELECT TOP 1 @GeneratedEthnicity = EthnicityId FROM #EthnicityIds ORDER BY NEWID();
        ELSE
            SET @GeneratedEthnicity = NULL;

        -- =========================================
        -- ★ GEOGRAPHY: Country/State/City (jerárquico con buckets)
        -- Buckets: 40% City+State+Country, 20% State+Country, 20% Country, 20% NULL
        -- =========================================
        SET @GeoBucket = ABS(CHECKSUM(NEWID()) % 100); -- 0-99

        IF @GeoBucket < 40 AND EXISTS (SELECT 1 FROM #CityIds)
        BEGIN
            -- 40%: City + State + Country coherentes
            SELECT TOP 1
                @SelectedCityId = CityId,
                @SelectedStateId = StateId,
                @SelectedCountryId = CountryId
            FROM #CityIds
            ORDER BY NEWID();
        END
        ELSE IF @GeoBucket < 60 AND EXISTS (SELECT 1 FROM #StateIds)
        BEGIN
            -- 20%: State + Country coherentes (City NULL)
            SELECT TOP 1
                @SelectedStateId = StateId,
                @SelectedCountryId = CountryId
            FROM #StateIds
            ORDER BY NEWID();
            SET @SelectedCityId = NULL;
        END
        ELSE IF @GeoBucket < 80 AND EXISTS (SELECT 1 FROM #CountryIds)
        BEGIN
            -- 20%: Solo Country (State y City NULL)
            SELECT TOP 1 @SelectedCountryId = CountryId
            FROM #CountryIds
            ORDER BY NEWID();
            SET @SelectedStateId = NULL;
            SET @SelectedCityId = NULL;
        END
        ELSE
        BEGIN
            -- 20%: Sin ubicación (todo NULL)
            SET @SelectedCountryId = NULL;
            SET @SelectedStateId = NULL;
            SET @SelectedCityId = NULL;
        END

        -- =========================================
        -- GENERAR LEADSOURCE (coherencia semántica)
        -- ★ v3.1: CampaignKey ya seleccionado arriba (líneas 309-316)
        -- =========================================

        -- Seleccionar tipo de fuente
        SELECT TOP 1 @SelectedSourceTypeId = SourceTypeId FROM #SourceTypes ORDER BY NEWID();

        -- Seleccionar sistema, medium, channel aleatorios
        SELECT TOP 1 @SelectedSystemId = SystemId FROM #Systems ORDER BY NEWID();
        SELECT TOP 1 @SelectedMediumId = MediumId FROM #Mediums ORDER BY NEWID();
        SELECT TOP 1 @SelectedChannelId = ChannelId FROM #Channels ORDER BY NEWID();

        -- Seleccionar device type
        SELECT TOP 1 @SelectedDeviceId = DeviceId, @DeviceName = DeviceName
        FROM #Devices
        ORDER BY NEWID();

        -- Seleccionar platform COHERENTE con device
        IF @DeviceName = 'Mobile'
        BEGIN
            -- Mobile → Android, iOS
            SELECT TOP 1 @SelectedPlatformId = PlatformId, @PlatformName = PlatformName
            FROM #Platforms
            WHERE PlatformName IN ('Android', 'iOS')
            ORDER BY NEWID();
        END
        ELSE IF @DeviceName = 'Desktop'
        BEGIN
            -- Desktop → Windows, macOS, Linux
            SELECT TOP 1 @SelectedPlatformId = PlatformId, @PlatformName = PlatformName
            FROM #Platforms
            WHERE PlatformName IN ('Windows', 'macOS', 'Linux')
            ORDER BY NEWID();
        END
        ELSE IF @DeviceName = 'Tablet'
        BEGIN
            -- Tablet → Android, iOS, iPadOS
            SELECT TOP 1 @SelectedPlatformId = PlatformId, @PlatformName = PlatformName
            FROM #Platforms
            WHERE PlatformName IN ('Android', 'iOS', 'iPadOS')
            ORDER BY NEWID();
        END
        ELSE
        BEGIN
            -- Other → cualquier platform
            SELECT TOP 1 @SelectedPlatformId = PlatformId, @PlatformName = PlatformName
            FROM #Platforms
            ORDER BY NEWID();
        END

        -- Seleccionar browser COHERENTE con platform
        IF @PlatformName IN ('iOS', 'iPadOS')
        BEGIN
            -- iOS → Safari, Chrome
            SELECT TOP 1 @SelectedBrowserId = BrowserId
            FROM #Browsers
            WHERE BrowserName IN ('Safari', 'Chrome')
            ORDER BY NEWID();
        END
        ELSE IF @PlatformName = 'Android'
        BEGIN
            -- Android → Chrome, Firefox, Samsung Internet
            SELECT TOP 1 @SelectedBrowserId = BrowserId
            FROM #Browsers
            WHERE BrowserName IN ('Chrome', 'Firefox', 'Samsung Internet')
            ORDER BY NEWID();
        END
        ELSE
        BEGIN
            -- Windows/macOS/Linux → cualquier browser moderno
            SELECT TOP 1 @SelectedBrowserId = BrowserId
            FROM #Browsers
            WHERE BrowserName IN ('Chrome', 'Firefox', 'Edge', 'Safari', 'Opera')
            ORDER BY NEWID();
        END

        INSERT INTO #BatchLeads
            (FirstName, LastName, Email, PhoneNumber, LeadStatusId, LeadTierId,
             SubscriberId, CountryId, StateId, CityId,
             DemographicGenderId, DemographicRaceId, DemographicEthnicityId,
             CreatedAt, CampaignKey, SourceTypeId, SystemId,
             MediumId, ChannelId, DeviceId, PlatformId, BrowserId)
        VALUES
            (@GeneratedFirstName, @GeneratedLastName, @GeneratedEmail, @GeneratedPhone,
             @GeneratedLeadStatusId, 1,
             @SelectedSubscriberId, @SelectedCountryId, @SelectedStateId, @SelectedCityId,
             @GeneratedGender, @GeneratedRace, @GeneratedEthnicity,
             @CreatedDate,
             @CampaignKey, @SelectedSourceTypeId, @SelectedSystemId, @SelectedMediumId,
             @SelectedChannelId, @SelectedDeviceId, @SelectedPlatformId, @SelectedBrowserId);

        SET @i = @i + 1;
    END

    -- =========================================
    -- INSERT MASIVO: LEADS + LEADSOURCES
    -- =========================================

    -- Primero insertar Leads
    INSERT INTO [crm].[Leads] WITH (TABLOCK)
        (firstName, lastName, email, phoneNumber, leadToken, leadStatusId,
         leadTierId, subscriberId, countryId, stateId, cityId,
         demographicGenderId, demographicRaceId, demographicEthnicityId, createdAt)
    SELECT
        FirstName, LastName, Email, PhoneNumber, LeadToken, LeadStatusId,
        LeadTierId, SubscriberId, CountryId, StateId, CityId,
        DemographicGenderId, DemographicRaceId, DemographicEthnicityId, CreatedAt
    FROM #BatchLeads
    ORDER BY RowNum;

    DECLARE @FirstLeadId INT = SCOPE_IDENTITY() - @BatchSize + 1;

    -- Luego insertar LeadSources con los leadId correspondientes
    INSERT INTO [crm].[LeadSources] WITH (TABLOCK)
        (leadId, campaignKey, leadSourceTypeId, leadSourceSystemId, leadMediumId,
         leadOriginChannelId, deviceTypeId, devicePlatformId, browserId, enabled)
    SELECT
        @FirstLeadId + RowNum - 1 AS leadId,
        CampaignKey,
        SourceTypeId,
        SystemId,
        MediumId,
        ChannelId,
        DeviceId,
        PlatformId,
        BrowserId,
        1 AS enabled
    FROM #BatchLeads
    ORDER BY RowNum;

    SET @LeadsGenerated = @LeadsGenerated + @BatchSize;

    DROP TABLE #BatchLeads;

    SET @BatchSeconds = DATEDIFF(SECOND, @BatchStartTime, GETUTCDATE());
    PRINT '  ✓ Batch completado en ' + CAST(@BatchSeconds AS VARCHAR(10)) + 's | Total: ' + FORMAT(@LeadsGenerated, 'N0') + ' leads + sources';
    PRINT '';

    SET @CurrentBatch = @CurrentBatch + 1;
END

-- Cleanup: Dropear TODAS las tablas temporales creadas
IF OBJECT_ID('tempdb..#SubscriberWeights') IS NOT NULL DROP TABLE #SubscriberWeights;
IF OBJECT_ID('tempdb..#CountryIds') IS NOT NULL DROP TABLE #CountryIds;
IF OBJECT_ID('tempdb..#SourceTypes') IS NOT NULL DROP TABLE #SourceTypes;
IF OBJECT_ID('tempdb..#Systems') IS NOT NULL DROP TABLE #Systems;
IF OBJECT_ID('tempdb..#Mediums') IS NOT NULL DROP TABLE #Mediums;
IF OBJECT_ID('tempdb..#Channels') IS NOT NULL DROP TABLE #Channels;
IF OBJECT_ID('tempdb..#Devices') IS NOT NULL DROP TABLE #Devices;
IF OBJECT_ID('tempdb..#Platforms') IS NOT NULL DROP TABLE #Platforms;
IF OBJECT_ID('tempdb..#Browsers') IS NOT NULL DROP TABLE #Browsers;
IF OBJECT_ID('tempdb..#GenderIds') IS NOT NULL DROP TABLE #GenderIds;
IF OBJECT_ID('tempdb..#RaceIds') IS NOT NULL DROP TABLE #RaceIds;
IF OBJECT_ID('tempdb..#EthnicityIds') IS NOT NULL DROP TABLE #EthnicityIds;
IF OBJECT_ID('tempdb..#StateIds') IS NOT NULL DROP TABLE #StateIds;
IF OBJECT_ID('tempdb..#CityIds') IS NOT NULL DROP TABLE #CityIds;
IF OBJECT_ID('tempdb..#PromptAdsCampaigns') IS NOT NULL DROP TABLE #PromptAdsCampaigns;
IF OBJECT_ID('tempdb..#CampaignLeadSlots') IS NOT NULL DROP TABLE #CampaignLeadSlots;
IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
IF OBJECT_ID('tempdb..#BatchLeads') IS NOT NULL DROP TABLE #BatchLeads;

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ GENERACIÓN DE LEADS + LEADSOURCES COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '  Total generado: ' + FORMAT(@LeadsGenerated, 'N0') + ' leads + ' + FORMAT(@LeadsGenerated, 'N0') + ' lead sources (1:1)';
PRINT '';

-- Estadísticas de completitud
PRINT '  Estadísticas de completitud de datos:';
DECLARE @RecentLeadCount BIGINT = @LeadsGenerated;
SELECT
    'Con firstName' AS Campo,
    FORMAT(COUNT(*), 'N0') AS Total,
    FORMAT((CAST(COUNT(*) AS DECIMAL(18,2)) / @RecentLeadCount) * 100, 'N2') + '%' AS Porcentaje
FROM [crm].[Leads]
WHERE firstName IS NOT NULL
  AND leadId > (SELECT MAX(leadId) FROM [crm].[Leads]) - @RecentLeadCount
UNION ALL
SELECT
    'Con email',
    FORMAT(COUNT(*), 'N0'),
    FORMAT((CAST(COUNT(*) AS DECIMAL(18,2)) / @RecentLeadCount) * 100, 'N2') + '%'
FROM [crm].[Leads]
WHERE email IS NOT NULL
  AND leadId > (SELECT MAX(leadId) FROM [crm].[Leads]) - @RecentLeadCount
UNION ALL
SELECT
    'Con phone',
    FORMAT(COUNT(*), 'N0'),
    FORMAT((CAST(COUNT(*) AS DECIMAL(18,2)) / @RecentLeadCount) * 100, 'N2') + '%'
FROM [crm].[Leads]
WHERE phoneNumber IS NOT NULL
  AND leadId > (SELECT MAX(leadId) FROM [crm].[Leads]) - @RecentLeadCount;

PRINT '';
