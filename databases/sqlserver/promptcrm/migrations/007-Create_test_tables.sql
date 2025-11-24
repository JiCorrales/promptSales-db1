USE PromptCRM;
GO

PRINT '=== CREATING SUBSCRIBER WALLETS (WITH CURRENCY) ===';

-- 1. Crear la tabla si no existe
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[SubscriberWallets]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[SubscriberWallets](
        [walletId] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [subscriberId] [int] NOT NULL,
        
        -- MONEDA BASE DE LA BILLETERA (Nuevo)
        [currencyId] [int] NOT NULL DEFAULT 1, -- Por defecto USD (1)
        
        -- Para Dirty Read (Saldo volátil)
        [creditsBalance] [decimal](18, 4) NOT NULL DEFAULT 0.00,
        
        -- Para Lost Update (Acumulador histórico)
        [totalRevenue] [decimal](18, 4) NOT NULL DEFAULT 0.00,
        
        [lastUpdated] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
        [rowVersion] [rowversion] NOT NULL
    );

    -- Constraint de Unicidad
    ALTER TABLE [crm].[SubscriberWallets]
    ADD CONSTRAINT [UQ_SubscriberWallets_SubscriberId] UNIQUE ([subscriberId]);

    -- FK a Subscribers
    ALTER TABLE [crm].[SubscriberWallets]
    ADD CONSTRAINT [FK_SubscriberWallets_Subscribers] 
    FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId]);

    -- FK a Currencies (Nuevo)
    ALTER TABLE [crm].[SubscriberWallets]
    ADD CONSTRAINT [FK_SubscriberWallets_Currencies] 
    FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId]);

    PRINT '  ✓ Table [crm].[SubscriberWallets] created with Currency support.';
END

-- 2. Poblar con datos iniciales para los 10 subscribers existentes
IF NOT EXISTS (SELECT 1 FROM [crm].[SubscriberWallets])
BEGIN
    INSERT INTO [crm].[SubscriberWallets] (subscriberId, currencyId, creditsBalance, totalRevenue)
    SELECT 
        subscriberId, 
        1,            -- currencyId = 1 (USD) para todos los demos
        1000.00,      -- Saldo inicial
        5000.00       -- Revenue inicial
    FROM [crm].[Subscribers];
    
    PRINT '  ✓ Wallets seeded for ' + CAST(@@ROWCOUNT AS VARCHAR) + ' subscribers.';
END
ELSE
BEGIN
    PRINT '  ✓ Wallets already exist. Skipping seed.';
END
GO