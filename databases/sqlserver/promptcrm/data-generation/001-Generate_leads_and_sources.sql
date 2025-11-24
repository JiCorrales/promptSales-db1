-- =============================================
-- STEP 2: Generar 1.5M Leads + LeadSources (1:1)
-- =============================================
-- Genera leads y sus lead sources simultáneamente con:
--   - Distribución multi-tenant inteligente
--   - Tokens únicos (GUID)
--   - Datos personales realistas (95% incompletos, 5% completos)
--   - LeadSource coherente por cada Lead (1:1)
--   - Tier = 1 (COLD) para todos
--   - Combinaciones semánticas coherentes (Mobile→Android/iOS)
-- Target: 1,500,000 Leads + 1,500,000 LeadSources
-- =============================================

SET NOCOUNT ON;

PRINT 'Generando 1.5 millones de Leads + LeadSources en batches...';
PRINT '';

-- =============================================
-- CONFIGURACIÓN
-- =============================================
DECLARE @TargetLeadCount INT = 1500000;
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

-- Calcular pesos acumulativos para sampling
DECLARE @TotalWeight DECIMAL(10,2);
SELECT @TotalWeight = SUM(Weight) FROM #SubscriberWeights;

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

DECLARE @SubscriberCount INT = (SELECT COUNT(*) FROM #SubscriberWeights);
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

PRINT '  ✓ Catálogos de LeadSource cargados';

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
        DemographicGenderId INT,
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
    DECLARE @GeneratedFirstName VARCHAR(60);
    DECLARE @GeneratedLastName VARCHAR(60);
    DECLARE @GeneratedEmail VARCHAR(255);
    DECLARE @GeneratedPhone VARCHAR(18);
    DECLARE @GeneratedGender INT;
    DECLARE @CreatedDate DATETIME2;
    DECLARE @DaysAgo INT;

    -- LeadSource variables
    DECLARE @CampaignKey VARCHAR(255);
    DECLARE @SelectedSourceTypeId INT;
    DECLARE @SelectedSystemId INT;
    DECLARE @SelectedMediumId INT;
    DECLARE @SelectedChannelId INT;
    DECLARE @SelectedDeviceId INT;
    DECLARE @SelectedPlatformId INT;
    DECLARE @SelectedBrowserId INT;
    DECLARE @DeviceName VARCHAR(60);
    DECLARE @PlatformName VARCHAR(60);

    WHILE @i <= @BatchSize
    BEGIN
        -- Seleccionar subscriber basado en distribución de pesos
        SET @RandomVal = RAND();
        SELECT TOP 1 @SelectedSubscriberId = SubscriberId
        FROM #SubscriberWeights
        WHERE CumulativeWeight >= @RandomVal
        ORDER BY CumulativeWeight;

        -- Seleccionar Country aleatorio
        SELECT TOP 1 @SelectedCountryId = CountryId
        FROM #CountryIds
        ORDER BY NEWID();

        -- Fecha creación aleatoria en últimos 18 meses
        SET @DaysAgo = ABS(CHECKSUM(NEWID()) % 540); -- 0-540 días
        SET @CreatedDate = DATEADD(DAY, -@DaysAgo, GETUTCDATE());

        -- Decidir si tiene datos completos (5% probabilidad)
        IF RAND() < @ProbCompleteData
        BEGIN
            -- Lead con datos COMPLETOS
            SELECT TOP 1 @GeneratedFirstName = FirstName FROM #FirstNames ORDER BY NEWID();
            SELECT TOP 1 @GeneratedLastName = LastName FROM #LastNames ORDER BY NEWID();
            SET @GeneratedEmail = LOWER(@GeneratedFirstName) + '.' + LOWER(@GeneratedLastName) + '@example.com';
            SET @GeneratedPhone = '+1' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID()) % 1000000000) AS VARCHAR(10)), 10);
            SET @GeneratedGender = (ABS(CHECKSUM(NEWID()) % 3) + 1); -- 1, 2, o 3
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

            IF RAND() < @ProbHasGender
                SET @GeneratedGender = (ABS(CHECKSUM(NEWID()) % 3) + 1);
            ELSE
                SET @GeneratedGender = NULL;
        END

        -- =========================================
        -- GENERAR LEADSOURCE (coherencia semántica)
        -- =========================================

        -- Campaign Key único
        SET @CampaignKey = 'CMP-' + CAST(@CurrentBatch AS VARCHAR(5)) + '-' + CAST(@i AS VARCHAR(10));

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
            (FirstName, LastName, Email, PhoneNumber, SubscriberId, CountryId,
             DemographicGenderId, CreatedAt, CampaignKey, SourceTypeId, SystemId,
             MediumId, ChannelId, DeviceId, PlatformId, BrowserId)
        VALUES
            (@GeneratedFirstName, @GeneratedLastName, @GeneratedEmail, @GeneratedPhone,
             @SelectedSubscriberId, @SelectedCountryId, @GeneratedGender, @CreatedDate,
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
         leadTierId, subscriberId, countryId, demographicGenderId, createdAt)
    SELECT
        FirstName, LastName, Email, PhoneNumber, LeadToken, LeadStatusId,
        LeadTierId, SubscriberId, CountryId, DemographicGenderId, CreatedAt
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

-- Cleanup
DROP TABLE #SubscriberWeights;
DROP TABLE #CountryIds;
DROP TABLE #SourceTypes;
DROP TABLE #Systems;
DROP TABLE #Mediums;
DROP TABLE #Channels;
DROP TABLE #Devices;
DROP TABLE #Platforms;
DROP TABLE #Browsers;
DROP TABLE #FirstNames;
DROP TABLE #LastNames;

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
