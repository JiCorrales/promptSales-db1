-- =============================================
-- STEP 5: Generar Clients desde conversiones
-- Objetivos:
--   - Crear clientes solo de leads con conversiones (al menos 1)
--   - Clientes por campana deben reflejar TargetClients de las conversiones (400-1000 por campana, total >= 500k)
--   - Sin cifrado (pendiente)
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT 'Generando Clients desde conversiones...';
PRINT '';

-- Limpieza defensiva
IF OBJECT_ID('tempdb..#LeadsWithConversions') IS NOT NULL DROP TABLE #LeadsWithConversions;
IF OBJECT_ID('tempdb..#ClientPlan') IS NOT NULL DROP TABLE #ClientPlan;
IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
IF OBJECT_ID('tempdb..#BatchLeads') IS NOT NULL DROP TABLE #BatchLeads;
IF OBJECT_ID('tempdb..#LeadNames') IS NOT NULL DROP TABLE #LeadNames;

-- Configuracion
DECLARE @BatchSize INT = 25000;
DECLARE @GeneratedClients BIGINT = 0;
DECLARE @CurrentBatch INT = 1;
DECLARE @BatchStartTime DATETIME2;
DECLARE @BatchSeconds INT;

-- Catalogos
DECLARE @USDCurrencyId INT;
SELECT TOP 1 @USDCurrencyId = currencyId FROM [crm].[Currencies] WHERE currencyCode = 'USD' AND enabled = 1;
IF @USDCurrencyId IS NULL SET @USDCurrencyId = 1;

DECLARE @ActiveStatusId INT;
SELECT TOP 1 @ActiveStatusId = clientStatusId FROM [crm].[ClientStatuses] WHERE clientStatusName = 'ACTIVE' AND enabled = 1;
IF @ActiveStatusId IS NULL SET @ActiveStatusId = 1;

PRINT '>> Catalogos cargados:';
PRINT '  - USD Currency ID: ' + CAST(@USDCurrencyId AS VARCHAR(10));
PRINT '  - ACTIVE Status ID: ' + CAST(@ActiveStatusId AS VARCHAR(10));
PRINT '';

-- Leads con conversiones sin cliente
PRINT '>> Identificando leads con conversiones (sin cliente aun)...';
IF OBJECT_ID('tempdb..#LeadsWithConversions') IS NOT NULL DROP TABLE #LeadsWithConversions;

SELECT
    lc.leadId,
    l.subscriberId,
    MIN(lc.createdAt) AS firstPurchaseAt,
    MAX(lc.createdAt) AS lastPurchaseAt,
    SUM(lc.conversionValue) AS lifetimeValue,
    COUNT(*) AS conversions,
    ls.campaignKey
INTO #LeadsWithConversions
FROM [crm].[LeadConversions] lc
JOIN [crm].[LeadEvents] le ON le.leadEventId = lc.leadEventId
JOIN [crm].[LeadSources] ls ON ls.leadId = le.leadId
JOIN [crm].[Leads] l ON l.leadId = le.leadId
WHERE NOT EXISTS (SELECT 1 FROM [crm].[Clients] c WHERE c.leadId = lc.leadId)
GROUP BY lc.leadId, l.subscriberId, ls.campaignKey;

-- Snapshot para validaciones finales
SELECT * INTO #ClientPlan FROM #LeadsWithConversions;

DECLARE @TotalConvertedLeads BIGINT = (SELECT COUNT(*) FROM #LeadsWithConversions);
DECLARE @TotalConversionsForClients BIGINT = (SELECT SUM(conversions) FROM #LeadsWithConversions);
DECLARE @TotalLTVForClients DECIMAL(18,2) = (SELECT SUM(lifetimeValue) FROM #LeadsWithConversions);
PRINT '  - Leads convertidos (sin cliente): ' + FORMAT(@TotalConvertedLeads, 'N0');
PRINT '  - Total conversiones: ' + FORMAT(@TotalConversionsForClients, 'N0');
PRINT '  - Lifetime Value total: $' + FORMAT(@TotalLTVForClients, 'N2');
PRINT '  - LTV promedio/cliente: $' + FORMAT(@TotalLTVForClients / NULLIF(@TotalConvertedLeads,1), 'N2');
PRINT '';

IF @TotalConvertedLeads = 0
BEGIN
    PRINT '  ERROR: No hay leads convertidos pendientes de cliente.';
    GOTO SkipClientGeneration;
END

DECLARE @TotalBatches INT = CEILING(CAST(@TotalConvertedLeads AS DECIMAL(18,2)) / @BatchSize);
PRINT '  Batches: ' + CAST(@TotalBatches AS VARCHAR(10)) + ' de ' + FORMAT(@BatchSize, 'N0');
PRINT '';

-- Catalogos de nombres
CREATE TABLE #FirstNames (FirstName VARCHAR(60));
CREATE TABLE #LastNames (LastName VARCHAR(60));

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
('Frank'),('Carolyn'),('Alexander'),('Janet'),('Patrick'),('Ruth'),('Jack'),('Heather'),
('Dennis'),('Diane'),('Jerry'),('Virginia'),('Tyler'),('Julie'),('Aaron'),('Joyce'),
('Jose'),('Victoria'),('Adam'),('Olivia'),('Henry'),('Kelly'),('Nathan'),('Christina'),
('Douglas'),('Lauren'),('Zachary'),('Joan'),('Peter'),('Evelyn'),('Kyle'),('Judith'),
('Walter'),('Megan'),('Ethan'),('Cheryl'),('Jeremy'),('Andrea'),('Harold'),('Hannah'),
('Keith'),('Jacqueline'),('Christian'),('Martha'),('Roger'),('Gloria'),('Noah'),('Teresa'),
('Gerald'),('Ann'),('Carl'),('Sara'),('Terry'),('Madison'),('Sean'),('Frances'),
('Austin'),('Kathryn'),('Arthur'),('Janice'),('Lawrence'),('Jean');

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

PRINT '  - Catalogos de nombres cargados';
PRINT '';

-- Procesar en batches
WHILE EXISTS (SELECT 1 FROM #LeadsWithConversions)
BEGIN
    SET @BatchStartTime = GETUTCDATE();

    IF OBJECT_ID('tempdb..#BatchLeads') IS NOT NULL DROP TABLE #BatchLeads;

    SELECT TOP (@BatchSize)
        leadId,
        subscriberId,
        firstPurchaseAt,
        lastPurchaseAt,
        lifetimeValue,
        conversions,
        campaignKey
    INTO #BatchLeads
    FROM #LeadsWithConversions
    ORDER BY leadId;

    -- Generar nombres faltantes desde catalogos
    IF OBJECT_ID('tempdb..#LeadNames') IS NOT NULL DROP TABLE #LeadNames;
    SELECT
        bl.leadId,
        COALESCE(l.firstName,
                 (SELECT TOP 1 FirstName FROM #FirstNames ORDER BY NEWID())) AS firstName,
        COALESCE(l.lastName,
                 (SELECT TOP 1 LastName FROM #LastNames ORDER BY NEWID())) AS lastName,
        COALESCE(l.email, 'lead' + CAST(bl.leadId AS VARCHAR(20)) + '@temp.com') AS email,
        COALESCE(l.phoneNumber, '+1' + RIGHT('000000000' + CAST(ABS(CHECKSUM(NEWID()) % 1000000000) AS VARCHAR(10)), 10)) AS phoneNumber,
        l.subscriberId
    INTO #LeadNames
    FROM #BatchLeads bl
    JOIN [crm].[Leads] l ON l.leadId = bl.leadId;

    -- Insertar clientes
    INSERT INTO [crm].[Clients] WITH (TABLOCK)
        (firstName, lastName, email, phoneNumber, nationalId, firstPurchaseAt, lastPurchaseAt,
         lifetimeValue, clientStatusId, subscriberId, leadId, currencyId)
    SELECT
        ln.firstName,
        ln.lastName,
        ln.email,
        ln.phoneNumber,
        CONVERT(varbinary(255), CAST(ln.leadId AS VARCHAR(20))), -- placeholder sin cifrar
        bl.firstPurchaseAt,
        bl.lastPurchaseAt,
        bl.lifetimeValue,
        @ActiveStatusId,
        ln.subscriberId,
        bl.leadId,
        @USDCurrencyId
    FROM #BatchLeads bl
    JOIN #LeadNames ln ON ln.leadId = bl.leadId;

    SET @GeneratedClients = @GeneratedClients + @@ROWCOUNT;

    -- Eliminar procesados
    DELETE FROM #LeadsWithConversions WHERE leadId IN (SELECT leadId FROM #BatchLeads);

    SET @BatchSeconds = DATEDIFF(SECOND, @BatchStartTime, GETUTCDATE());
    PRINT '  - Batch ' + CAST(@CurrentBatch AS VARCHAR(10)) + ' completado en ' + CAST(@BatchSeconds AS VARCHAR(10)) + 's | Total clientes: ' + FORMAT(@GeneratedClients, 'N0');
    SET @CurrentBatch = @CurrentBatch + 1;
END


PRINT '';
PRINT 'Validacion de clientes por campana (rango 400-1000, total >= 500k):';
WITH CampaignClients AS (
    SELECT
        cp.campaignKey,
        COUNT(*) AS Clients
    FROM #ClientPlan cp
    JOIN [crm].[Clients] c ON c.leadId = cp.leadId
    GROUP BY cp.campaignKey
)
SELECT
    campaignKey,
    Clients,
    CASE WHEN Clients < 400 OR Clients > 1000 THEN 'WARN: fuera de rango' ELSE '' END AS Flag
FROM CampaignClients
ORDER BY campaignKey;

DECLARE @TotalClients BIGINT = (
    SELECT COUNT(*) FROM #ClientPlan cp
    JOIN [crm].[Clients] c ON c.leadId = cp.leadId
);

PRINT '  Total clientes generados: ' + FORMAT(@TotalClients, 'N0');
IF @TotalClients < 500000
    PRINT '  WARN: total clientes < 500,000';

SkipClientGeneration:

-- Limpieza
IF OBJECT_ID('tempdb..#LeadsWithConversions') IS NOT NULL DROP TABLE #LeadsWithConversions;
IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
IF OBJECT_ID('tempdb..#ClientPlan') IS NOT NULL DROP TABLE #ClientPlan;
IF OBJECT_ID('tempdb..#BatchLeads') IS NOT NULL DROP TABLE #BatchLeads;
IF OBJECT_ID('tempdb..#LeadNames') IS NOT NULL DROP TABLE #LeadNames;

PRINT '';
PRINT '=============================================';
PRINT 'STEP 5 COMPLETADO';
PRINT '=============================================';
GO
