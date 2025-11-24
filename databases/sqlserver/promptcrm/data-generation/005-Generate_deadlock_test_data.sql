-- =============================================
-- PromptCRM - Seed Data: Deadlock Test Scenarios
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-22
-- Purpose: Create test data for deadlock simulations
-- Scenario: Payment processing, client updates, and subscription management
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT '========================================';
PRINT 'SEEDING DEADLOCK TEST DATA';
PRINT '========================================';
PRINT '';

-- =============================================
-- PREREQUISITE CHECK
-- =============================================
PRINT 'Checking prerequisites...';

-- Verify that seed 006 (Subscribers) has been executed
IF NOT EXISTS (SELECT 1 FROM [crm].[Subscribers] WHERE subscriberId = 1)
BEGIN
    RAISERROR('ERROR: Seed 006-Seed_subscribers.sql must be executed first!', 16, 1);
    RETURN;
END

PRINT '  ✓ Prerequisites verified';
PRINT '';

-- =============================================
-- TEST CLIENTS FOR DEADLOCK SCENARIOS
-- =============================================
-- IMPORTANT: Using IDs 1000000+ to avoid conflicts with 989K generated clients
PRINT 'Inserting Test Clients...';

SET IDENTITY_INSERT [crm].[Clients] ON;

DECLARE @Now datetime2 = GETUTCDATE();

-- Cifrar nationalIds usando SP de MASTER
DECLARE @Client1000000NationalId VARBINARY(255);
DECLARE @Client1000001NationalId VARBINARY(255);
DECLARE @Client1000002NationalId VARBINARY(255);
DECLARE @Client1000003NationalId VARBINARY(255);

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0001', @EncryptedData = @Client1000000NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0002', @EncryptedData = @Client1000001NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0003', @EncryptedData = @Client1000002NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '555-99-0004', @EncryptedData = @Client1000003NationalId OUTPUT;

INSERT INTO [crm].[Clients]
    (clientId, firstName, lastName, email, phoneNumber, nationalId,
     lifetimeValue, firstPurchaseAt, lastPurchaseAt,
     clientStatusId, subscriberId, leadId, currencyId)
VALUES
    -- Client 1000000: TechVision customer (High Value)
    (1000000,
     'Robert',
     'Johnson',
     'robert.johnson@techcorp.com',
     '+14155551234',
     @Client1000000NationalId,
     15000.00,
     DATEADD(MONTH, -6, @Now),
     DATEADD(DAY, -5, @Now),
     2, -- ACTIVE
     1, -- TechVision
     9999001, -- Dummy lead ID (high range)
     1), -- USD

    -- Client 1000001: TechVision customer (Medium Value)
    (1000001,
     'Maria',
     'Garcia',
     'maria.garcia@innovate.com',
     '+14155551235',
     @Client1000001NationalId,
     8500.00,
     DATEADD(MONTH, -4, @Now),
     DATEADD(DAY, -3, @Now),
     2, -- ACTIVE
     1, -- TechVision
     9999002, -- Dummy lead ID (high range)
     1), -- USD

    -- Client 1000002: GreenLeaf customer (VIP)
    (1000002,
     'James',
     'Wilson',
     'james.wilson@healthfoods.com',
     '+15035552000',
     @Client1000002NationalId,
     25000.00,
     DATEADD(MONTH, -12, @Now),
     DATEADD(DAY, -1, @Now),
     3, -- VIP
     2, -- GreenLeaf
     9999003, -- Dummy lead ID (high range)
     1), -- USD

    -- Client 1000003: FinanceFlow customer (Active)
    (1000003,
     'Linda',
     'Martinez',
     'linda.m@financepro.com',
     '+13125554000',
     @Client1000003NationalId,
     12000.00,
     DATEADD(MONTH, -8, @Now),
     DATEADD(DAY, -2, @Now),
     2, -- ACTIVE
     4, -- FinanceFlow
     9999004, -- Dummy lead ID (high range)
     1); -- USD

SET IDENTITY_INSERT [crm].[Clients] OFF;

PRINT '  ✓ Inserted 4 test clients';

-- =============================================
-- CLIENT PROFILES (for deadlock scenario)
-- =============================================
PRINT 'Inserting Client Profiles...';

INSERT INTO [crm].[ClientProfiles]
    (clientId, recencyScore, frequencyScore, monetaryScore, rfmSegment,
     totalPurchases, totalSpent, averageOrderValue, daysSinceLastPurchase,
     preferredContactTimeKey, calculatedAt)
VALUES
    (1000000, 4, 5, 5, 'Champions', 25, 15000.00, 600.00, 5, 'MORNING', @Now),
    (1000001, 4, 4, 4, 'Loyal Customers', 18, 8500.00, 472.22, 3, 'AFTERNOON', @Now),
    (1000002, 5, 5, 5, 'Champions', 45, 25000.00, 555.56, 1, 'EVENING', @Now),
    (1000003, 4, 4, 5, 'Loyal Customers', 22, 12000.00, 545.45, 2, 'MORNING', @Now);

PRINT '  ✓ Inserted 4 client profiles';

-- =============================================
-- ADDITIONAL PAYMENT METHODS FOR TESTING
-- =============================================
-- IMPORTANT: Using high IDs (9000-9001) to avoid conflicts with mass-generated data
PRINT 'Inserting Additional Payment Methods...';

SET IDENTITY_INSERT [crm].[PaymentMethods] ON;

-- Cifrar payment method 9000 usando SP de MASTER
DECLARE @PM9000Card VARBINARY(255), @PM9000Brand VARBINARY(255), @PM9000Month VARBINARY(255), @PM9000Year VARBINARY(255);
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '4242', @EncryptedData = @PM9000Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM9000Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '12', @EncryptedData = @PM9000Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2027', @EncryptedData = @PM9000Year OUTPUT;

-- Cifrar payment method 9001 usando SP de MASTER
DECLARE @PM9001Card VARBINARY(255), @PM9001Brand VARBINARY(255), @PM9001Month VARBINARY(255), @PM9001Year VARBINARY(255);
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '8888', @EncryptedData = @PM9001Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'MASTERCARD', @EncryptedData = @PM9001Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '06', @EncryptedData = @PM9001Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2028', @EncryptedData = @PM9001Year OUTPUT;

INSERT INTO [crm].[PaymentMethods]
    (paymentMethodId, cardLastFour, cardBrand, expiryMonth, expiryYear,
     fingerprint, status, paymentMethodTypeId, verifiedAt)
VALUES
    (9000,
     @PM9000Card,
     @PM9000Brand,
     @PM9000Month,
     @PM9000Year,
     'fp_test_card_9000',
     'ACTIVE', 1, @Now),

    (9001,
     @PM9001Card,
     @PM9001Brand,
     @PM9001Month,
     @PM9001Year,
     'fp_test_card_9001',
     'ACTIVE', 1, @Now);

SET IDENTITY_INSERT [crm].[PaymentMethods] OFF;

PRINT '  ✓ Inserted 2 payment methods';

-- =============================================
-- INITIAL TRANSACTIONS FOR TESTING
-- =============================================
-- IMPORTANT: Using high IDs (9500000-9500002) to avoid conflicts with mass-generated data
PRINT 'Inserting Initial Transactions...';

SET IDENTITY_INSERT [crm].[Transactions] ON;

INSERT INTO [crm].[Transactions]
    (transactionId, transactionReference, amount, createdAt, updatedAt,
     processedAt, settledAt, checksum,
     transactionTypeId, paymentMethodId, currencyId, subscriberId, transactionStatusId, clientId)
VALUES
    -- Transaction 9500000: Client 1000000 - Pending
    (9500000,
     'TXN-TEST-9500000-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now)),
     500.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500000'), 2),
     1, -- SUBSCRIPTION_PAYMENT
     9000, -- Payment Method
     1, -- USD
     1, -- TechVision
     1, -- PENDING
     1000000), -- Client

    -- Transaction 9500001: Client 1000001 - Processing
    (9500001,
     'TXN-TEST-9500001-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now) + 1),
     750.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500001'), 2),
     2, -- ONE_TIME_PAYMENT
     9001, -- Payment Method
     1, -- USD
     1, -- TechVision
     2, -- PROCESSING
     1000001), -- Client

    -- Transaction 9500002: Client 1000002 - Pending
    (9500002,
     'TXN-TEST-9500002-' + CONVERT(VARCHAR(20), DATEPART(MILLISECOND, @Now) + 2),
     1200.00,
     @Now, @Now, @Now, @Now,
     CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'TXN-9500002'), 2),
     1, -- SUBSCRIPTION_PAYMENT
     9000, -- Payment Method
     1, -- USD
     2, -- GreenLeaf
     1, -- PENDING
     1000002); -- Client

SET IDENTITY_INSERT [crm].[Transactions] OFF;

PRINT '  ✓ Inserted 3 initial transactions';

-- =============================================
-- TEST ACCOUNT BALANCES TABLE (for deadlock simulation)
-- =============================================
-- This table will be used to simulate balance updates during transactions
PRINT 'Creating Account Balances table for testing...';

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TestAccountBalances' AND schema_id = SCHEMA_ID('crm'))
BEGIN
    CREATE TABLE [crm].[TestAccountBalances] (
        [accountId] int PRIMARY KEY IDENTITY(1, 1),
        [subscriberId] int NOT NULL,
        [clientId] bigint NOT NULL,
        [balance] decimal(18,4) NOT NULL DEFAULT (0),
        [pendingAmount] decimal(18,4) NOT NULL DEFAULT (0),
        [lastTransactionId] int NULL,
        [lastUpdatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
        [updatedCount] int NOT NULL DEFAULT (0),
        [metadata] nvarchar(max),
        CONSTRAINT FK_TestAccountBalances_Subscriber FOREIGN KEY (subscriberId)
            REFERENCES [crm].[Subscribers](subscriberId),
        CONSTRAINT FK_TestAccountBalances_Client FOREIGN KEY (clientId)
            REFERENCES [crm].[Clients](clientId)
    );

    CREATE INDEX IX_TestAccountBalances_SubscriberId ON [crm].[TestAccountBalances](subscriberId);
    CREATE INDEX IX_TestAccountBalances_ClientId ON [crm].[TestAccountBalances](clientId);

    PRINT '  ✓ Created TestAccountBalances table';
END
ELSE
BEGIN
    PRINT '  ⚠ TestAccountBalances table already exists';
END

-- Insert initial balances
PRINT 'Inserting Account Balances...';

IF NOT EXISTS (SELECT 1 FROM [crm].[TestAccountBalances] WHERE clientId = 1000000)
BEGIN
    INSERT INTO [crm].[TestAccountBalances]
        (subscriberId, clientId, balance, pendingAmount, lastUpdatedAt)
    VALUES
        (1, 1000000, 5000.00, 0.00, @Now),
        (1, 1000001, 3000.00, 0.00, @Now),
        (2, 1000002, 10000.00, 0.00, @Now),
        (4, 1000003, 6000.00, 0.00, @Now);

    PRINT '  ✓ Inserted 4 account balances';
END
ELSE
BEGIN
    PRINT '  ⚠ Account balances already exist';
END

PRINT '';
PRINT '========================================';
PRINT 'DEADLOCK TEST DATA SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT 'Summary:';
PRINT '  - Test Clients: 4';
PRINT '  - Client Profiles: 4';
PRINT '  - Payment Methods: 2';
PRINT '  - Initial Transactions: 3';
PRINT '  - Account Balances: 4';
PRINT '';
PRINT 'Test Entities Created:';
PRINT '  • Clients: 1000000-1000003 (above 989K generated clients)';
PRINT '  • Payment Methods: 9000-9001';
PRINT '  • Transactions: 9500000-9500002';
PRINT '  • Account Balances: Ready for concurrent updates';
PRINT '';
PRINT 'IMPORTANT: Client IDs 1000000+ avoid conflicts with 989,151 generated clients';
PRINT '';
PRINT 'Ready for deadlock simulation scenarios!';
PRINT '';

GO
