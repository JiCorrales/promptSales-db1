-- =============================================
-- STEP 5: Generar Clients desde Leads Convertidos v4.0 - OPTIMIZED
-- =============================================
-- Genera clientes desde leads que tienen conversiones:
--   - firstName NOT NULL (generar si Lead no lo tiene)
--   - lastName NOT NULL (generar si Lead no lo tiene)
--   - email VARCHAR (texto plano heredado del Lead)
--   - phoneNumber VARCHAR (texto plano heredado del Lead)
--   - nationalId VARBINARY CIFRADO usando ENCRYPTBYKEY en batch (OPTIMIZADO)
--   - firstPurchaseAt NOT NULL (fecha primera conversión)
--   - lastPurchaseAt NOT NULL (fecha última conversión)
--   - clientStatusId NOT NULL (ACTIVE por defecto)
--   - subscriberId NOT NULL (heredado del Lead)
--   - leadId NOT NULL y UNIQUE
--   - currencyId NOT NULL (USD por defecto)
--   - lifetimeValue calculado desde conversiones
-- OPTIMIZACIÓN v4.0:
--   • Cifrado vectorizado (ENCRYPTBYKEY batch)
--   • Sin SP calls individuales
--   • Apertura única de symmetric key por batch
-- Target: 500K+ clientes
-- =============================================

PRINT 'Generando Clients desde leads convertidos (v4.0 OPTIMIZED)...';
PRINT '';

SET NOCOUNT ON;

-- =============================================
-- CONFIGURACIÓN
-- =============================================
DECLARE @BatchSize INT = 25000;
DECLARE @TotalConvertedLeads BIGINT;
DECLARE @GeneratedClients BIGINT = 0;
DECLARE @CurrentBatch INT = 1;
DECLARE @BatchStartTime DATETIME2;
DECLARE @BatchSeconds INT;

-- Obtener currency USD
DECLARE @USDCurrencyId INT;
SELECT TOP 1 @USDCurrencyId = currencyId
FROM [crm].[Currencies]
WHERE currencyCode = 'USD' AND enabled = 1;

IF @USDCurrencyId IS NULL
BEGIN
    PRINT '  ⚠️  No se encontró currency USD habilitada. Usando currencyId = 1 por defecto.';
    SET @USDCurrencyId = 1;
END

-- Obtener status ACTIVE para clientes
DECLARE @ActiveStatusId INT;
SELECT TOP 1 @ActiveStatusId = clientStatusId
FROM [crm].[ClientStatuses]
WHERE clientStatusName = 'ACTIVE' AND enabled = 1;

IF @ActiveStatusId IS NULL
BEGIN
    PRINT '  ⚠️  No se encontró status ACTIVE. Usando clientStatusId = 1 por defecto.';
    SET @ActiveStatusId = 1;
END

-- Contar leads únicos con conversiones (que aún no son clientes)
SELECT @TotalConvertedLeads = COUNT(DISTINCT lc.leadId)
FROM [crm].[LeadConversions] lc
WHERE NOT EXISTS (
    SELECT 1
    FROM [crm].[Clients] c
    WHERE c.leadId = lc.leadId
);

IF @TotalConvertedLeads = 0
BEGIN
    PRINT '  ⚠️  No hay leads convertidos sin cliente asociado.';
    DECLARE @TotalLeadsWithConversions BIGINT = (SELECT COUNT(DISTINCT leadId) FROM [crm].[LeadConversions]);
    DECLARE @TotalClientsExisting BIGINT = (SELECT COUNT(*) FROM [crm].[Clients]);
    PRINT '     Total leads con conversiones: ' + FORMAT(@TotalLeadsWithConversions, 'N0');
    PRINT '     Total clientes existentes: ' + FORMAT(@TotalClientsExisting, 'N0');
    GOTO SkipClientGeneration;
END

DECLARE @TotalBatches INT = CEILING(CAST(@TotalConvertedLeads AS DECIMAL(18,2)) / @BatchSize);

PRINT '  Leads convertidos a procesar: ' + FORMAT(@TotalConvertedLeads, 'N0');
PRINT '  Batches: ' + CAST(@TotalBatches AS VARCHAR(10)) + ' de ' + FORMAT(@BatchSize, 'N0') + ' leads';
PRINT '  Currency: ' + CAST(@USDCurrencyId AS VARCHAR(10)) + ' (USD)';
PRINT '  Client Status: ' + CAST(@ActiveStatusId AS VARCHAR(10)) + ' (ACTIVE)';
PRINT '';

-- =============================================
-- CARGAR CATÁLOGOS PARA NOMBRES
-- =============================================
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
('Larry'),('Nicole'),('Justin'),('Emma'),('Scott'),('Samantha'),('Brandon'),('Katherine');

INSERT INTO #LastNames (LastName) VALUES
('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),
('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),('Thomas'),
('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),('White'),
('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson'),('Walker'),('Young'),
('Allen'),('King'),('Wright'),('Scott'),('Torres'),('Nguyen'),('Hill'),('Flores'),
('Green'),('Adams'),('Nelson'),('Baker'),('Hall'),('Rivera'),('Campbell'),('Mitchell'),
('Carter'),('Roberts'),('Gomez'),('Phillips'),('Evans'),('Turner'),('Diaz'),('Parker');

PRINT 'Catálogos de nombres cargados';
PRINT '';

-- =============================================
-- GENERAR CLIENTES EN BATCHES
-- =============================================
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Iniciando generación de clientes...';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

-- Tabla temporal para datos agregados de conversiones por lead
CREATE TABLE #LeadConversionData (
    LeadId INT PRIMARY KEY,
    FirstPurchaseAt DATETIME2 NOT NULL,
    LastPurchaseAt DATETIME2 NOT NULL,
    LifetimeValue DECIMAL(18,4) NOT NULL,
    SubscriberId INT NOT NULL
);

-- Calcular datos de conversión para cada lead convertido
INSERT INTO #LeadConversionData (LeadId, FirstPurchaseAt, LastPurchaseAt, LifetimeValue, SubscriberId)
SELECT
    lc.leadId,
    MIN(lc.createdAt) AS FirstPurchaseAt,
    MAX(lc.createdAt) AS LastPurchaseAt,
    SUM(lc.conversionValue) AS LifetimeValue,
    l.subscriberId
FROM [crm].[LeadConversions] lc
INNER JOIN [crm].[Leads] l ON lc.leadId = l.leadId
WHERE NOT EXISTS (
    SELECT 1
    FROM [crm].[Clients] c
    WHERE c.leadId = lc.leadId
)
GROUP BY lc.leadId, l.subscriberId;

DECLARE @LeadConversionDataCount BIGINT = (SELECT COUNT(*) FROM #LeadConversionData);
PRINT '  ✓ Datos de conversión agregados para ' + FORMAT(@LeadConversionDataCount, 'N0') + ' leads';
PRINT '';

-- Procesar en batches
WHILE @GeneratedClients < @TotalConvertedLeads
BEGIN
    SET @BatchStartTime = GETUTCDATE();

    PRINT 'Batch ' + CAST(@CurrentBatch AS VARCHAR(5)) + '/' + CAST(@TotalBatches AS VARCHAR(5)) + ' - Generando hasta ' + FORMAT(@BatchSize, 'N0') + ' clientes...';

    -- Tabla temporal para este batch
    -- OPTIMIZACIÓN: nationalId en texto plano primero, cifrar después en batch
    CREATE TABLE #BatchClients (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        LeadId INT NOT NULL,
        FirstName VARCHAR(60) NOT NULL,
        LastName VARCHAR(60) NOT NULL,
        Email VARCHAR(255),
        PhoneNumber VARCHAR(18),
        NationalIdClearText VARCHAR(11),  -- Texto plano temporal
        NationalIdEncrypted VARBINARY(255),  -- Cifrado después
        FirstPurchaseAt DATETIME2 NOT NULL,
        LastPurchaseAt DATETIME2 NOT NULL,
        LifetimeValue DECIMAL(18,4) NOT NULL,
        ClientStatusId INT NOT NULL,
        SubscriberId INT NOT NULL,
        CurrencyId INT NOT NULL
    );

    -- Seleccionar siguiente batch de leads convertidos
    -- PASO 1: Obtener leads y sus datos
    DECLARE @TempLeadData TABLE (
        LeadId INT,
        ExistingFirstName VARCHAR(60),
        ExistingLastName VARCHAR(60),
        Email VARCHAR(255),
        PhoneNumber VARCHAR(18),
        FirstPurchaseAt DATETIME2,
        LastPurchaseAt DATETIME2,
        LifetimeValue DECIMAL(18,4),
        SubscriberId INT
    );

    INSERT INTO @TempLeadData
    SELECT TOP (@BatchSize)
        lcd.LeadId,
        l.firstName,
        l.lastName,
        l.email,
        l.phoneNumber,
        lcd.FirstPurchaseAt,
        lcd.LastPurchaseAt,
        lcd.LifetimeValue,
        lcd.SubscriberId
    FROM #LeadConversionData lcd
    INNER JOIN [crm].[Leads] l ON lcd.LeadId = l.leadId
    WHERE NOT EXISTS (
        SELECT 1
        FROM [crm].[Clients] c
        WHERE c.leadId = lcd.LeadId
    )
    ORDER BY lcd.LeadId;

    -- PASO 2: Insertar con nombres (existentes o generados con cursor)
    DECLARE @CurrentLeadId INT;
    DECLARE @CurrentFirstName VARCHAR(60);
    DECLARE @CurrentLastName VARCHAR(60);
    DECLARE @CurrentEmail VARCHAR(255);
    DECLARE @CurrentPhone VARCHAR(18);
    DECLARE @CurrentFirstPurchase DATETIME2;
    DECLARE @CurrentLastPurchase DATETIME2;
    DECLARE @CurrentLTV DECIMAL(18,4);
    DECLARE @CurrentSubId INT;
    DECLARE @GeneratedFirstName VARCHAR(60);
    DECLARE @GeneratedLastName VARCHAR(60);
    DECLARE @GeneratedNationalId VARCHAR(11);  -- Solo texto plano

    DECLARE client_cursor CURSOR FAST_FORWARD FOR
    SELECT LeadId, ExistingFirstName, ExistingLastName, Email, PhoneNumber,
           FirstPurchaseAt, LastPurchaseAt, LifetimeValue, SubscriberId
    FROM @TempLeadData;

    OPEN client_cursor;
    FETCH NEXT FROM client_cursor INTO @CurrentLeadId, @CurrentFirstName, @CurrentLastName,
                                        @CurrentEmail, @CurrentPhone, @CurrentFirstPurchase,
                                        @CurrentLastPurchase, @CurrentLTV, @CurrentSubId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generar firstName si no existe
        IF @CurrentFirstName IS NULL
            SELECT TOP 1 @GeneratedFirstName = FirstName FROM #FirstNames ORDER BY NEWID();
        ELSE
            SET @GeneratedFirstName = @CurrentFirstName;

        -- Generar lastName si no existe
        IF @CurrentLastName IS NULL
            SELECT TOP 1 @GeneratedLastName = LastName FROM #LastNames ORDER BY NEWID();
        ELSE
            SET @GeneratedLastName = @CurrentLastName;

        -- Generar nationalId en texto plano (cifrar después en batch)
        -- Formato: XXX-XX-XXXX (simulado con CHECKSUM para unicidad)
        SET @GeneratedNationalId =
            RIGHT('000' + CAST(ABS(CHECKSUM(NEWID()) % 1000) AS VARCHAR(3)), 3) + '-' +
            RIGHT('00' + CAST(ABS(CHECKSUM(NEWID()) % 100) AS VARCHAR(2)), 2) + '-' +
            RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID()) % 10000) AS VARCHAR(4)), 4);

        -- Insertar cliente (nationalId sin cifrar aún)
        INSERT INTO #BatchClients (LeadId, FirstName, LastName, Email, PhoneNumber,
                                    NationalIdClearText, FirstPurchaseAt, LastPurchaseAt,
                                    LifetimeValue, ClientStatusId, SubscriberId, CurrencyId)
        VALUES (@CurrentLeadId, @GeneratedFirstName, @GeneratedLastName, @CurrentEmail,
                @CurrentPhone, @GeneratedNationalId, @CurrentFirstPurchase,
                @CurrentLastPurchase, @CurrentLTV, @ActiveStatusId, @CurrentSubId, @USDCurrencyId);

        FETCH NEXT FROM client_cursor INTO @CurrentLeadId, @CurrentFirstName, @CurrentLastName,
                                            @CurrentEmail, @CurrentPhone, @CurrentFirstPurchase,
                                            @CurrentLastPurchase, @CurrentLTV, @CurrentSubId;
    END

    CLOSE client_cursor;
    DEALLOCATE client_cursor;

    DECLARE @ClientsInBatch INT = (SELECT COUNT(*) FROM #BatchClients);

    IF @ClientsInBatch = 0
        BREAK;

    -- =============================================
    -- CIFRADO BATCH DE nationalIds (OPTIMIZACIÓN v4.0)
    -- =============================================
    DECLARE @ClientsToEncrypt INT = (SELECT COUNT(*) FROM #BatchClients WHERE NationalIdClearText IS NOT NULL);

    IF @ClientsToEncrypt > 0
    BEGIN
        PRINT '  → Cifrando ' + FORMAT(@ClientsToEncrypt, 'N0') + ' nationalIds en batch...';

        -- Abrir llave simétrica UNA SOLA VEZ para todo el batch
        EXEC sp_executesql N'
            EXEC master.sys.sp_executesql N''
                OPEN SYMMETRIC KEY SK_PromptCRM_Master_Key
                DECRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;
            ''
        ';

        -- Cifrar TODOS los nationalIds del batch de una sola vez
        UPDATE #BatchClients
        SET NationalIdEncrypted = ENCRYPTBYKEY(KEY_GUID('SK_PromptCRM_Master_Key'), NationalIdClearText)
        WHERE NationalIdClearText IS NOT NULL;

        -- Cerrar llave simétrica
        EXEC sp_executesql N'
            EXEC master.sys.sp_executesql N''
                CLOSE SYMMETRIC KEY SK_PromptCRM_Master_Key;
            ''
        ';
    END

    -- INSERT MASIVO en Clients (con nationalId cifrado)
    INSERT INTO [crm].[Clients] WITH (TABLOCK)
        (firstName, lastName, email, phoneNumber, nationalId, firstPurchaseAt, lastPurchaseAt,
         lifetimeValue, clientStatusId, subscriberId, leadId, currencyId)
    SELECT
        bc.FirstName, bc.LastName, bc.Email, bc.PhoneNumber, bc.NationalIdEncrypted,
        bc.FirstPurchaseAt, bc.LastPurchaseAt,
        bc.LifetimeValue, bc.ClientStatusId, bc.SubscriberId,
        bc.LeadId, bc.CurrencyId
    FROM #BatchClients bc
    WHERE NOT EXISTS (
        SELECT 1
        FROM [crm].[Clients] c
        WHERE c.leadId = bc.LeadId
    );

    SET @GeneratedClients = @GeneratedClients + @@ROWCOUNT;

    DROP TABLE #BatchClients;

    SET @BatchSeconds = DATEDIFF(SECOND, @BatchStartTime, GETUTCDATE());
    PRINT '  ✓ Batch completado en ' + CAST(@BatchSeconds AS VARCHAR(10)) + 's';
    PRINT '    • Clientes generados: ' + FORMAT(@ClientsInBatch, 'N0');
    PRINT '    • Total acumulado: ' + FORMAT(@GeneratedClients, 'N0') + ' clientes';
    PRINT '';

    SET @CurrentBatch = @CurrentBatch + 1;
END

-- Cleanup
DROP TABLE #LeadConversionData;
DROP TABLE #FirstNames;
DROP TABLE #LastNames;

SkipClientGeneration:

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ GENERACIÓN DE CLIENTS COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '  Total generado: ' + FORMAT(@GeneratedClients, 'N0') + ' clientes';
PRINT '';

-- Estadísticas
PRINT '  Estadísticas de clientes generados:';

DECLARE @AvgLifetimeValue DECIMAL(18,2);
DECLARE @TotalLifetimeValue DECIMAL(18,2);
DECLARE @MaxLifetimeValue DECIMAL(18,2);

SELECT
    @AvgLifetimeValue = AVG(lifetimeValue),
    @TotalLifetimeValue = SUM(lifetimeValue),
    @MaxLifetimeValue = MAX(lifetimeValue)
FROM [crm].[Clients];

PRINT '    • Lifetime Value Promedio: ' + FORMAT(@AvgLifetimeValue, 'C2');
PRINT '    • Lifetime Value Total: ' + FORMAT(@TotalLifetimeValue, 'C2');
PRINT '    • Lifetime Value Máximo: ' + FORMAT(@MaxLifetimeValue, 'C2');
PRINT '';

-- Verificar que NO hay NULLs en campos requeridos
DECLARE @ClientsWithNullFirstName INT;
DECLARE @ClientsWithNullLastName INT;

SELECT @ClientsWithNullFirstName = COUNT(*)
FROM [crm].[Clients]
WHERE firstName IS NULL;

SELECT @ClientsWithNullLastName = COUNT(*)
FROM [crm].[Clients]
WHERE lastName IS NULL;

IF @ClientsWithNullFirstName > 0 OR @ClientsWithNullLastName > 0
BEGIN
    PRINT '  ⚠️  ADVERTENCIA: Se encontraron clientes con nombres NULL:';
    PRINT '    • firstName NULL: ' + CAST(@ClientsWithNullFirstName AS VARCHAR(10));
    PRINT '    • lastName NULL: ' + CAST(@ClientsWithNullLastName AS VARCHAR(10));
END
ELSE
BEGIN
    PRINT '  ✓ Validación: Todos los clientes tienen firstName y lastName';
END

PRINT '';
