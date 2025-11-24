-----------------------------------------------------------
-- Seed: Test Data for Deadlock Scenarios
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-23
-- Proposito: Crear datos de prueba para demos de deadlock
--
-- IDs Usados (por encima de data generada):
--   - Leads: 9999001-9999004 (hay 1,500,000 generados)
--   - Clients: 1000000-1000003 (hay 989,151 generados)
--   - Payment Methods: 9000-9001
--   - Transactions: 9500000-9500002
--   - TestAccountBalances: 1000000-1000003
-----------------------------------------------------------

USE PromptCRM;
GO

PRINT ''
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT '🔧 Seed 007: Test Data for Deadlock Scenarios'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT ''

DECLARE @Now DATETIME2 = GETUTCDATE();

-----------------------------------------------------------
-- 0. CREAR LEADS DE PRUEBA (IDs 9999001-9999004)
-----------------------------------------------------------
PRINT '0️⃣  Inserting test Leads (IDs 9999001-9999004)...'

SET IDENTITY_INSERT [crm].[Leads] ON;

INSERT INTO [crm].[Leads]
    (leadId, leadToken, email, phoneNumber, firstName, lastName, age,
     createdAt, updatedAt, lead_score, subscriberId, leadStatusId, leadTierId)
VALUES
    (9999001, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'LEAD-TEST-9999001'), 2),
     'robert.test@example.com', '+14155551234', 'Robert', 'Johnson', 35,
     @Now, @Now, 85.00, 1, 3, 4), -- TechVision, CONVERTED, HOT (85 score)

    (9999002, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'LEAD-TEST-9999002'), 2),
     'maria.test@example.com', '+14155555678', 'Maria', 'Garcia', 42,
     @Now, @Now, 90.00, 2, 3, 5), -- GreenLeaf, CONVERTED, BLAZING (90 score)

    (9999003, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'LEAD-TEST-9999003'), 2),
     'john.test@example.com', '+14155559012', 'John', 'Smith', 28,
     @Now, @Now, 75.00, 3, 3, 3), -- FinanceFlow, CONVERTED, WARM (75 score)

    (9999004, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'LEAD-TEST-9999004'), 2),
     'lisa.test@example.com', '+14155553456', 'Lisa', 'Chen', 31,
     @Now, @Now, 82.00, 1, 3, 4); -- TechVision, CONVERTED, HOT (82 score)

SET IDENTITY_INSERT [crm].[Leads] OFF;

PRINT '   ✓ Created 4 test Leads (9999001-9999004)'
GO

-----------------------------------------------------------
-- 1. CREAR CLIENTS DE PRUEBA (IDs 1000000-1000003)
-----------------------------------------------------------
PRINT '1️⃣  Inserting test Clients (IDs 1000000-1000003)...'

DECLARE @Now DATETIME2 = GETUTCDATE();

-- Encriptar National IDs usando el bridge SP
DECLARE @Client1000000NationalId VARBINARY(255);
DECLARE @Client1000001NationalId VARBINARY(255);
DECLARE @Client1000002NationalId VARBINARY(255);
DECLARE @Client1000003NationalId VARBINARY(255);

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0001', @EncryptedData = @Client1000000NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0002', @EncryptedData = @Client1000001NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0003', @EncryptedData = @Client1000002NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0004', @EncryptedData = @Client1000003NationalId OUTPUT;

-- Insertar Clients con IDs explícitos
SET IDENTITY_INSERT [crm].[Clients] ON;

INSERT INTO [crm].[Clients]
    (clientId, firstName, lastName, email, phoneNumber, nationalId,
     lifetimeValue, firstPurchaseAt, lastPurchaseAt,
     clientStatusId, subscriberId, leadId, currencyId)
VALUES
    (1000000, 'Robert', 'Johnson', 'robert.johnson@techcorp.com', '+14155551234',
     @Client1000000NationalId, 15000.00, DATEADD(MONTH, -6, @Now), DATEADD(DAY, -5, @Now),
     2, 1, 9999001, 1), -- TechVision, USD

    (1000001, 'Maria', 'Garcia', 'maria.garcia@greenleaf.com', '+14155555678',
     @Client1000001NationalId, 22500.00, DATEADD(MONTH, -12, @Now), DATEADD(DAY, -3, @Now),
     2, 2, 9999002, 1), -- GreenLeaf, USD

    (1000002, 'John', 'Smith', 'john.smith@financeflow.com', '+14155559012',
     @Client1000002NationalId, 8500.00, DATEADD(MONTH, -3, @Now), DATEADD(DAY, -10, @Now),
     2, 3, 9999003, 1), -- FinanceFlow, USD

    (1000003, 'Lisa', 'Chen', 'lisa.chen@techcorp.com', '+14155553456',
     @Client1000003NationalId, 5000.00, DATEADD(MONTH, -1, @Now), DATEADD(DAY, -2, @Now),
     2, 1, 9999004, 1); -- TechVision, USD

SET IDENTITY_INSERT [crm].[Clients] OFF;

PRINT '   ✓ Created 4 test Clients (1000000-1000003)'
GO

-----------------------------------------------------------
-- 2. CREAR PAYMENT METHODS DE PRUEBA (IDs 9000-9001)
-----------------------------------------------------------
PRINT '2️⃣  Inserting test Payment Methods (IDs 9000-9001)...'

DECLARE @Now DATETIME2 = GETUTCDATE();

-- Encriptar datos de tarjetas de prueba
DECLARE @CardLastFour_9000 VARBINARY(255);
DECLARE @CardBrand_9000 VARBINARY(255);
DECLARE @ExpiryMonth_9000 VARBINARY(255);
DECLARE @ExpiryYear_9000 VARBINARY(255);

DECLARE @CardLastFour_9001 VARBINARY(255);
DECLARE @CardBrand_9001 VARBINARY(255);
DECLARE @ExpiryMonth_9001 VARBINARY(255);
DECLARE @ExpiryYear_9001 VARBINARY(255);

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '4242', @EncryptedData = @CardLastFour_9000 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'Visa', @EncryptedData = @CardBrand_9000 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '12', @EncryptedData = @ExpiryMonth_9000 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2025', @EncryptedData = @ExpiryYear_9000 OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '5555', @EncryptedData = @CardLastFour_9001 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'Mastercard', @EncryptedData = @CardBrand_9001 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '06', @EncryptedData = @ExpiryMonth_9001 OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2026', @EncryptedData = @ExpiryYear_9001 OUTPUT;

SET IDENTITY_INSERT [crm].[PaymentMethods] ON;

INSERT INTO [crm].[PaymentMethods]
    (paymentMethodId, cardLastFour, cardBrand, expiryMonth, expiryYear,
     verifiedAt, lastUsedAt, fingerprint, createdAt, updatedAt, status, paymentMethodTypeId)
VALUES
    (9000, @CardLastFour_9000, @CardBrand_9000, @ExpiryMonth_9000, @ExpiryYear_9000,
     @Now, @Now, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TEST-CARD-9000'), 2),
     @Now, @Now, 'ACTIVE', 1), -- CREDIT_CARD

    (9001, @CardLastFour_9001, @CardBrand_9001, @ExpiryMonth_9001, @ExpiryYear_9001,
     @Now, @Now, CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TEST-CARD-9001'), 2),
     @Now, @Now, 'ACTIVE', 1); -- CREDIT_CARD

SET IDENTITY_INSERT [crm].[PaymentMethods] OFF;

PRINT '   ✓ Created 2 test Payment Methods (9000-9001)'
GO

-----------------------------------------------------------
-- 3. CREAR TRANSACTIONS DE PRUEBA (IDs 9500000-9500002)
-----------------------------------------------------------
PRINT '3️⃣  Inserting test Transactions (IDs 9500000-9500002)...'

DECLARE @Now DATETIME2 = GETUTCDATE();

SET IDENTITY_INSERT [crm].[Transactions] ON;

-- Transactions son para Subscribers pagando su subscripción a PromptCRM
-- NO tienen clientId, solo subscriberId
INSERT INTO [crm].[Transactions]
    (transactionId, transactionReference, amount, createdAt, updatedAt,
     processedAt, settledAt, checksum,
     transactionTypeId, paymentMethodId, currencyId, subscriberId, transactionStatusId)
VALUES
    (9500000,
     'TXN-TEST-9500000-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now)),
     500.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500000'), 2),
     1, -- SUBSCRIPTION_PAYMENT
     9000, -- Test Credit Card
     1, -- USD
     1, -- TechVision (subscriberId)
     1), -- PENDING

    (9500001,
     'TXN-TEST-9500001-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now)),
     750.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500001'), 2),
     1, -- SUBSCRIPTION_PAYMENT
     9000, -- Test Credit Card
     1, -- USD
     2, -- GreenLeaf (subscriberId)
     1), -- PENDING

    (9500002,
     'TXN-TEST-9500002-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now)),
     1000.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500002'), 2),
     1, -- SUBSCRIPTION_PAYMENT
     9001, -- Test Bank Transfer
     1, -- USD
     3, -- FinanceFlow (subscriberId)
     1); -- PENDING

SET IDENTITY_INSERT [crm].[Transactions] OFF;

PRINT '   ✓ Created 3 test Transactions (9500000-9500002) for Subscribers'
GO

-----------------------------------------------------------
-- 4. CREAR CLIENT PROFILES DE PRUEBA
-----------------------------------------------------------
PRINT '4️⃣  Inserting test Client Profiles...'

INSERT INTO [crm].[ClientProfiles]
    (clientId, recencyScore, frequencyScore, monetaryScore, rfmSegment,
     totalPurchases, totalSpent, averageOrderValue, daysSinceLastPurchase,
     calculatedAt, updatedAt)
VALUES
    (1000000, 5, 4, 5, 'Champions', 25, 15000.00, 600.00, 5, GETUTCDATE(), GETUTCDATE()),
    (1000001, 4, 5, 5, 'Loyal Customers', 40, 22500.00, 562.50, 3, GETUTCDATE(), GETUTCDATE()),
    (1000002, 3, 3, 3, 'Potential Loyalists', 12, 8500.00, 708.33, 10, GETUTCDATE(), GETUTCDATE()),
    (1000003, 5, 2, 2, 'Recent Customers', 5, 5000.00, 1000.00, 2, GETUTCDATE(), GETUTCDATE());

PRINT '   ✓ Created 4 test Client Profiles'
GO

-----------------------------------------------------------
-- 5. CREAR TEST ACCOUNT BALANCES
-----------------------------------------------------------
PRINT '5️⃣  Inserting test Account Balances...'

INSERT INTO [crm].[TestAccountBalances]
    (clientId, balance, pendingAmount, lastTransactionId, lastUpdatedAt, updatedCount, metadata)
VALUES
    (1000000, 1000.00, 0.00, NULL, GETUTCDATE(), 0, '{}'),
    (1000001, 1000.00, 0.00, NULL, GETUTCDATE(), 0, '{}'),
    (1000002, 500.00, 0.00, NULL, GETUTCDATE(), 0, '{}'),
    (1000003, 250.00, 0.00, NULL, GETUTCDATE(), 0, '{}');

PRINT '   ✓ Created 4 test Account Balances'
GO

-----------------------------------------------------------
-- VERIFICACIÓN
-----------------------------------------------------------
PRINT ''
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT '📊 VERIFICATION: Test Data Created'
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
PRINT ''

-- Verificar Leads
SELECT 'Leads' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[Leads]
WHERE leadId BETWEEN 9999001 AND 9999004;

-- Verificar Clients
SELECT 'Clients' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[Clients]
WHERE clientId BETWEEN 1000000 AND 1000003;

-- Verificar Payment Methods
SELECT 'PaymentMethods' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[PaymentMethods]
WHERE paymentMethodId BETWEEN 9000 AND 9001;

-- Verificar Transactions
SELECT 'Transactions' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[Transactions]
WHERE transactionId BETWEEN 9500000 AND 9500002;

-- Verificar Client Profiles
SELECT 'ClientProfiles' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[ClientProfiles]
WHERE clientId BETWEEN 1000000 AND 1000003;

-- Verificar Test Account Balances
SELECT 'TestAccountBalances' AS TableName, COUNT(*) AS RecordCount
FROM [crm].[TestAccountBalances]
WHERE clientId BETWEEN 1000000 AND 1000003;

PRINT ''
PRINT '✅ Seed 007 completed successfully!'
PRINT ''
PRINT 'Test data created:'
PRINT '  - Leads: 9999001-9999004 (above 1,500,000 generated)'
PRINT '  - Clients: 1000000-1000003 (above 989,151 generated)'
PRINT '  - No conflicts with mass-generated data!'
PRINT ''
GO
