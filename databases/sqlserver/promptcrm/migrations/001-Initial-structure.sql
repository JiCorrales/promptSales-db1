
-- Create database if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'PromptCRM')
BEGIN
    CREATE DATABASE [PromptCRM];
    PRINT N'Database [PromptCRM] created';
END
ELSE
BEGIN
    PRINT N'Database [PromptCRM] already exists';
END
GO

-- Use the database
USE [PromptCRM];
GO

-- Create schema crm if it does not exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'crm')
BEGIN
    EXEC(N'CREATE SCHEMA [crm]');
    PRINT N'Schema [crm] created';
END
ELSE
BEGIN
    PRINT N'Schema [crm] already exists';
END
GO

-- -----------------------------------------------------
-- Table [crm].[Payment_status_catalog]
-- Payment Status Catalog
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Payment_status_catalog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Payment_status_catalog] (
        [payment_status_id] INT IDENTITY(1,1) NOT NULL,
        [status_code] VARCHAR(20) NOT NULL,
        [status_name] VARCHAR(60) NOT NULL,
        [status_description] NVARCHAR(255) NULL,
        [is_final_status] BIT DEFAULT 0,
        [display_order] INT NULL,
        CONSTRAINT [PK_Payment_status_catalog] PRIMARY KEY CLUSTERED ([payment_status_id] ASC),
        CONSTRAINT [UQ_Payment_status_code] UNIQUE ([status_code])
    );
END
GO

-- -----------------------------------------------------
-- Table [crm].[Subscription_status_catalog]
-- Subscription Status Catalog
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscription_status_catalog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscription_status_catalog] (
        [subscription_status_id] INT IDENTITY(1,1) NOT NULL,
        [status_code] VARCHAR(20) NOT NULL,
        [status_name] VARCHAR(60) NOT NULL,
        [status_description] NVARCHAR(255) NULL,
        [allows_access] BIT DEFAULT 0,
        [display_order] INT NULL,
        CONSTRAINT [PK_Subscription_status_catalog] PRIMARY KEY CLUSTERED ([subscription_status_id] ASC),
        CONSTRAINT [UQ_Subscription_status_code] UNIQUE ([status_code])
    );
END
GO

-- -----------------------------------------------------
-- Table [crm].[Lead_status_catalog]
-- Lead Status Catalog
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Lead_status_catalog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Lead_status_catalog] (
        [lead_status_id] INT IDENTITY(1,1) NOT NULL,
        [status_code] VARCHAR(20) NOT NULL,
        [status_name] VARCHAR(60) NOT NULL,
        [status_description] NVARCHAR(255) NULL,
        [is_active_status] BIT DEFAULT 1,
        [display_order] INT NULL,
        [status_color] VARCHAR(7) NULL,
        CONSTRAINT [PK_Lead_status_catalog] PRIMARY KEY CLUSTERED ([lead_status_id] ASC),
        CONSTRAINT [UQ_Lead_status_code] UNIQUE ([status_code])
    );
END
GO

-- -----------------------------------------------------
-- Table [crm].[User_status_catalog]
-- User Status Catalog
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[User_status_catalog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[User_status_catalog] (
        [user_status_id] INT IDENTITY(1,1) NOT NULL,
        [status_code] VARCHAR(20) NOT NULL,
        [status_name] VARCHAR(60) NOT NULL,
        [status_description] NVARCHAR(255) NULL,
        [allows_login] BIT DEFAULT 0,
        [display_order] INT NULL,
        CONSTRAINT [PK_User_status_catalog] PRIMARY KEY CLUSTERED ([user_status_id] ASC),
        CONSTRAINT [UQ_User_status_code] UNIQUE ([status_code])
    );
END
GO

-- -----------------------------------------------------
-- Table [crm].[Status_catalog]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Status_catalog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Status_catalog] (
        [status_catalog_id] INT IDENTITY(1,1) NOT NULL,
        [status_name] VARCHAR(30) NOT NULL,
        CONSTRAINT [PK_Status_catalog] PRIMARY KEY CLUSTERED ([status_catalog_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Users]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Users]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Users] (
        [user_id] INT IDENTITY(1,1) NOT NULL,
        [first_name] VARCHAR(60) NOT NULL,
        [last_name] VARCHAR(60) NOT NULL,
        [email] VARCHAR(255) NOT NULL,
        [password] VARBINARY(255) NULL,
        [phone_number] VARCHAR(18) NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [last_login_at] DATETIME2 NULL,
        [last_login_ip] VARCHAR(45) NULL,
        [failed_login_attempts] INT DEFAULT 0,
        [locked_until] DATETIME2 NULL,
        [password_changed_at] DATETIME2 NULL,
        [two_factor_enabled] BIT DEFAULT 0,
        [email_verified_at] DATETIME2 NULL,
        [phone_verified_at] DATETIME2 NULL,
        [timezone] VARCHAR(50) NULL,
        [locale] VARCHAR(10) NULL,
        [external_id] VARCHAR(100) NULL,
        [auth0_user_id] VARCHAR(100) NULL,
        [hubspot_contact_id] VARCHAR(100) NULL,
        [manager_id] INT NULL,
        [department] VARCHAR(60) NULL,
        [job_title] VARCHAR(100) NULL,
        [preferences] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED ([user_id] ASC),
        CONSTRAINT [FK_Users_Status_catalog1] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Users_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Users_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Users_manager] FOREIGN KEY ([manager_id])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Users_status_catalog_id] ON [crm].[Users] ([status_catalog_id]);
    CREATE INDEX [idx_Users_deleted_at] ON [crm].[Users] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE INDEX [idx_Users_manager_id] ON [crm].[Users] ([manager_id]);
    CREATE INDEX [idx_Users_last_login_at] ON [crm].[Users] ([last_login_at]);
    CREATE UNIQUE INDEX [UQ_Users_email] ON [crm].[Users] ([email]) WHERE [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Users_external_id] ON [crm].[Users] ([external_id]) WHERE [external_id] IS NOT NULL;
    CREATE INDEX [idx_Users_email_password] ON [crm].[Users] ([email], [password]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[User_roles]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[User_roles]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[User_roles] (
        [user_role_id] INT IDENTITY(1,1) NOT NULL,
        [user_role] VARCHAR(60) NOT NULL,
        [enabled] BIT NOT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_User_roles] PRIMARY KEY CLUSTERED ([user_role_id] ASC),
        CONSTRAINT [FK_User_roles_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_User_roles_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_User_roles_deleted_at] ON [crm].[User_roles] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Roles_per_user]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Roles_per_user]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Roles_per_user] (
        [user_id] INT NOT NULL,
        [user_role_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Roles_per_user] PRIMARY KEY CLUSTERED ([user_id] ASC, [user_role_id] ASC),
        CONSTRAINT [FK_Roles_per_user_Users] FOREIGN KEY ([user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Roles_per_user_User_roles] FOREIGN KEY ([user_role_id])
            REFERENCES [crm].[User_roles] ([user_role_id]),
        CONSTRAINT [FK_Roles_per_user_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Roles_per_user_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Roles_per_user_user_id] ON [crm].[Roles_per_user] ([user_id]);
    CREATE INDEX [idx_Roles_per_user_user_role_id] ON [crm].[Roles_per_user] ([user_role_id]);
    CREATE INDEX [idx_Roles_per_user_deleted_at] ON [crm].[Roles_per_user] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Permissions]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Permissions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Permissions] (
        [permission_id] INT IDENTITY(1,1) NOT NULL,
        [permission_code] VARCHAR(8) NOT NULL,
        [permission_description] NVARCHAR(MAX) NULL,
        [enabled] BIT NOT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Permissions] PRIMARY KEY CLUSTERED ([permission_id] ASC),
        CONSTRAINT [FK_Permissions_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Permissions_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Permissions_deleted_at] ON [crm].[Permissions] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Permission_per_role]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Permission_per_role]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Permission_per_role] (
        [user_role_id] INT NOT NULL,
        [permission_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Permission_per_role] PRIMARY KEY CLUSTERED ([user_role_id] ASC, [permission_id] ASC),
        CONSTRAINT [FK_Permission_per_role_User_roles] FOREIGN KEY ([user_role_id])
            REFERENCES [crm].[User_roles] ([user_role_id]),
        CONSTRAINT [FK_Permission_per_role_Permissions] FOREIGN KEY ([permission_id])
            REFERENCES [crm].[Permissions] ([permission_id]),
        CONSTRAINT [FK_Permission_per_role_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Permission_per_role_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Permission_per_role_user_role_id] ON [crm].[Permission_per_role] ([user_role_id]);
    CREATE INDEX [idx_Permission_per_role_permission_id] ON [crm].[Permission_per_role] ([permission_id]);
    CREATE INDEX [idx_Permission_per_role_deleted_at] ON [crm].[Permission_per_role] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Permissions_per_user]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Permissions_per_user]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Permissions_per_user] (
        [user_id] INT NOT NULL,
        [permission_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Permissions_per_user] PRIMARY KEY CLUSTERED ([user_id] ASC, [permission_id] ASC),
        CONSTRAINT [FK_Permissions_per_user_Users] FOREIGN KEY ([user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Permissions_per_user_Permissions] FOREIGN KEY ([permission_id])
            REFERENCES [crm].[Permissions] ([permission_id]),
        CONSTRAINT [FK_Permissions_per_user_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Permissions_per_user_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Permissions_per_user_user_id] ON [crm].[Permissions_per_user] ([user_id]);
    CREATE INDEX [idx_Permissions_per_user_permission_id] ON [crm].[Permissions_per_user] ([permission_id]);
    CREATE INDEX [idx_Permissions_per_user_deleted_at] ON [crm].[Permissions_per_user] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Countries]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Countries]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Countries] (
        [country_id] INT IDENTITY(1,1) NOT NULL,
        [country_name] VARCHAR(60) NOT NULL,
        [country_code] VARCHAR(3) NOT NULL,
        CONSTRAINT [PK_Countries] PRIMARY KEY CLUSTERED ([country_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[States]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[States]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[States] (
        [state_id] INT IDENTITY(1,1) NOT NULL,
        [state_name] VARCHAR(60) NOT NULL,
        [country_id] INT NOT NULL,
        CONSTRAINT [PK_States] PRIMARY KEY CLUSTERED ([state_id] ASC),
        CONSTRAINT [FK_States_Countries] FOREIGN KEY ([country_id])
            REFERENCES [crm].[Countries] ([country_id])
    );
    CREATE INDEX [idx_States_country_id] ON [crm].[States] ([country_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Cities]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Cities]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Cities] (
        [city_id] INT IDENTITY(1,1) NOT NULL,
        [city_name] VARCHAR(60) NOT NULL,
        [state_id] INT NOT NULL,
        CONSTRAINT [PK_Cities] PRIMARY KEY CLUSTERED ([city_id] ASC),
        CONSTRAINT [FK_Cities_States] FOREIGN KEY ([state_id])
            REFERENCES [crm].[States] ([state_id])
    );
    CREATE INDEX [idx_Cities_state_id] ON [crm].[Cities] ([state_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Addresses]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Addresses]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Addresses] (
        [address_id] INT IDENTITY(1,1) NOT NULL,
        [address1] VARCHAR(100) NOT NULL,
        [address2] VARCHAR(100) NULL,
        [zipcode] VARCHAR(10) NULL,
        [geolocation] GEOGRAPHY NULL,
        [city_id] INT NOT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Addresses] PRIMARY KEY CLUSTERED ([address_id] ASC),
        CONSTRAINT [FK_Addresses_Cities] FOREIGN KEY ([city_id])
            REFERENCES [crm].[Cities] ([city_id]),
        CONSTRAINT [FK_Addresses_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Addresses_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Addresses_city_id] ON [crm].[Addresses] ([city_id]);
    CREATE INDEX [idx_Addresses_deleted_at] ON [crm].[Addresses] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Log_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Log_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Log_types] (
        [log_type_id] INT IDENTITY(1,1) NOT NULL,
        [log_type] VARCHAR(60) NULL,
        CONSTRAINT [PK_Log_types] PRIMARY KEY CLUSTERED ([log_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Log_levels]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Log_levels]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Log_levels] (
        [log_level_id] INT IDENTITY(1,1) NOT NULL,
        [log_level] VARCHAR(60) NULL,
        CONSTRAINT [PK_Log_levels] PRIMARY KEY CLUSTERED ([log_level_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[log_sources]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[log_sources]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[log_sources] (
        [log_source_id] INT IDENTITY(1,1) NOT NULL,
        [log_source] VARCHAR(45) NULL,
        CONSTRAINT [PK_log_sources] PRIMARY KEY CLUSTERED ([log_source_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Logs]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Logs]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Logs] (
        [system_log_id] INT IDENTITY(1,1) NOT NULL,
        [log_description] VARCHAR(255) NULL,
        [source_device] VARCHAR(60) NULL,
        [checksum] VARCHAR(64) NULL,
        [created_at] DATETIME2 NULL,
        [user_id] INT NULL,
        [log_type_id] INT NOT NULL,
        [log_level_id] INT NOT NULL,
        [log_source_id] INT NOT NULL,
        CONSTRAINT [PK_Logs] PRIMARY KEY CLUSTERED ([system_log_id] ASC),
        CONSTRAINT [FK_Logs_Users] FOREIGN KEY ([user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Logs_Log_types] FOREIGN KEY ([log_type_id])
            REFERENCES [crm].[Log_types] ([log_type_id]),
        CONSTRAINT [FK_Logs_Log_levels] FOREIGN KEY ([log_level_id])
            REFERENCES [crm].[Log_levels] ([log_level_id]),
        CONSTRAINT [FK_Logs_log_sources] FOREIGN KEY ([log_source_id])
            REFERENCES [crm].[log_sources] ([log_source_id])
    );
    CREATE INDEX [idx_Logs_user_id] ON [crm].[Logs] ([user_id]);
    CREATE INDEX [idx_Logs_log_type_id] ON [crm].[Logs] ([log_type_id]);
    CREATE INDEX [idx_Logs_log_level_id] ON [crm].[Logs] ([log_level_id]);
    CREATE INDEX [idx_Logs_log_source_id] ON [crm].[Logs] ([log_source_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscribers]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscribers]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscribers] (
        [subscriber_id] INT IDENTITY(1,1) NOT NULL,
        [legal_name] VARCHAR(80) NOT NULL,
        [comercial_name] VARCHAR(80) NULL,
        [legal_id] VARCHAR(40) NULL,
        [website_url] VARCHAR(255) NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [tax_id] VARCHAR(40) NULL,
        [industry] VARCHAR(100) NULL,
        [company_size] VARCHAR(20) NULL,
        [timezone] VARCHAR(50) NULL,
        [locale] VARCHAR(10) NULL,
        [logo_url] VARCHAR(500) NULL,
        [external_id] VARCHAR(100) NULL,
        [stripe_customer_id] VARCHAR(100) NULL,
        [hubspot_company_id] VARCHAR(100) NULL,
        [metadata] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Subscribers] PRIMARY KEY CLUSTERED ([subscriber_id] ASC),
        CONSTRAINT [FK_Subscribers_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [CK_Subscribers_metadata_json] CHECK ([metadata] IS NULL OR ISJSON([metadata]) = 1),
        CONSTRAINT [CK_Subscribers_website_url_format] CHECK ([website_url] IS NULL OR [website_url] LIKE 'http%://%')
    );
    CREATE INDEX [idx_Subscribers_status_catalog_id] ON [crm].[Subscribers] ([status_catalog_id]);
    CREATE INDEX [idx_Subscribers_deleted_at] ON [crm].[Subscribers] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Subscribers_legal_id] ON [crm].[Subscribers] ([legal_id]) WHERE [legal_id] IS NOT NULL AND [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Subscribers_external_id] ON [crm].[Subscribers] ([external_id]) WHERE [external_id] IS NOT NULL;
    CREATE UNIQUE INDEX [UQ_Subscribers_stripe_customer_id] ON [crm].[Subscribers] ([stripe_customer_id]) WHERE [stripe_customer_id] IS NOT NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Users_per_subscription]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Users_per_subscription]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Users_per_subscription] (
        [user_id] INT NOT NULL,
        [subscriber_id] INT NOT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        CONSTRAINT [PK_Users_per_subscription] PRIMARY KEY CLUSTERED ([user_id] ASC, [subscriber_id] ASC),
        CONSTRAINT [FK_Users_per_subscription_Users] FOREIGN KEY ([user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Users_per_subscription_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Users_per_subscription_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id])
    );
    CREATE INDEX [idx_Users_per_subscription_user_id] ON [crm].[Users_per_subscription] ([user_id]);
    CREATE INDEX [idx_Users_per_subscription_subscriber_id] ON [crm].[Users_per_subscription] ([subscriber_id]);
    CREATE INDEX [idx_Users_per_subscription_status_catalog_id] ON [crm].[Users_per_subscription] ([status_catalog_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscription_plans]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscription_plans]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscription_plans] (
        [suscription_plan_id] INT IDENTITY(1,1) NOT NULL,
        [plan_name] VARCHAR(30) NOT NULL,
        [plan_description] NVARCHAR(MAX) NULL,
        [monthly_price] DECIMAL(10,2) NULL,
        [annual_price] DECIMAL(10,2) NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Subscription_plans] PRIMARY KEY CLUSTERED ([suscription_plan_id] ASC),
        CONSTRAINT [FK_Subscription_plans_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Subscription_plans_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Subscription_plans_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Subscription_plans_status_catalog_id] ON [crm].[Subscription_plans] ([status_catalog_id]);
    CREATE INDEX [idx_Subscription_plans_deleted_at] ON [crm].[Subscription_plans] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Addresses_per_suscriber]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Addresses_per_suscriber]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Addresses_per_suscriber] (
        [subscriber_id] INT NOT NULL,
        [address_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        CONSTRAINT [PK_Addresses_per_suscriber] PRIMARY KEY CLUSTERED ([subscriber_id] ASC, [address_id] ASC),
        CONSTRAINT [FK_Addresses_per_suscriber_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Addresses_per_suscriber_Addresses] FOREIGN KEY ([address_id])
            REFERENCES [crm].[Addresses] ([address_id]),
        CONSTRAINT [FK_Addresses_per_suscriber_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id])
    );
    CREATE INDEX [idx_Addresses_per_suscriber_subscriber_id] ON [crm].[Addresses_per_suscriber] ([subscriber_id]);
    CREATE INDEX [idx_Addresses_per_suscriber_address_id] ON [crm].[Addresses_per_suscriber] ([address_id]);
    CREATE INDEX [idx_Addresses_per_suscriber_status_catalog_id] ON [crm].[Addresses_per_suscriber] ([status_catalog_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscription_feature_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscription_feature_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscription_feature_types] (
        [subscription_feature_type_id] INT IDENTITY(1,1) NOT NULL,
        [feature_type_name] VARCHAR(20) NULL,
        CONSTRAINT [PK_Subscription_feature_types] PRIMARY KEY CLUSTERED ([subscription_feature_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscription_features]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscription_features]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscription_features] (
        [subscription_feature_id] INT IDENTITY(1,1) NOT NULL,
        [feature_code] VARCHAR(40) NULL,
        [feature_name] VARCHAR(80) NULL,
        [default_value] VARCHAR(20) NULL,
        [feature_description] NVARCHAR(MAX) NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [subscription_feature_type_id] INT NOT NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Subscription_features] PRIMARY KEY CLUSTERED ([subscription_feature_id] ASC),
        CONSTRAINT [FK_Subscription_features_Subscription_feature_types] FOREIGN KEY ([subscription_feature_type_id])
            REFERENCES [crm].[Subscription_feature_types] ([subscription_feature_type_id]),
        CONSTRAINT [FK_Subscription_features_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Subscription_features_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Subscription_features_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Subscription_features_subscription_feature_type_id] ON [crm].[Subscription_features] ([subscription_feature_type_id]);
    CREATE INDEX [idx_Subscription_features_status_catalog_id] ON [crm].[Subscription_features] ([status_catalog_id]);
    CREATE INDEX [idx_Subscription_features_deleted_at] ON [crm].[Subscription_features] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Features_per_plan]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Features_per_plan]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Features_per_plan] (
        [suscription_plan_id] INT NOT NULL,
        [subscription_feature_id] INT NOT NULL,
        [feature_value] VARCHAR(20) NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Features_per_plan] PRIMARY KEY CLUSTERED ([suscription_plan_id] ASC, [subscription_feature_id] ASC),
        CONSTRAINT [FK_Features_per_plan_Subscription_plans] FOREIGN KEY ([suscription_plan_id])
            REFERENCES [crm].[Subscription_plans] ([suscription_plan_id]),
        CONSTRAINT [FK_Features_per_plan_Subscription_features] FOREIGN KEY ([subscription_feature_id])
            REFERENCES [crm].[Subscription_features] ([subscription_feature_id]),
        CONSTRAINT [FK_Features_per_plan_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Features_per_plan_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Features_per_plan_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Features_per_plan_suscription_plan_id] ON [crm].[Features_per_plan] ([suscription_plan_id]);
    CREATE INDEX [idx_Features_per_plan_subscription_feature_id] ON [crm].[Features_per_plan] ([subscription_feature_id]);
    CREATE INDEX [idx_Features_per_plan_status_catalog_id] ON [crm].[Features_per_plan] ([status_catalog_id]);
    CREATE INDEX [idx_Features_per_plan_deleted_at] ON [crm].[Features_per_plan] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Currencies]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Currencies]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Currencies] (
        [currency_id] INT IDENTITY(1,1) NOT NULL,
        [currency_name] VARCHAR(40) NOT NULL,
        [currency_code] VARCHAR(3) NOT NULL,
        [enabled] BIT NOT NULL,
        [created_at] DATETIME2 NULL,
        CONSTRAINT [PK_Currencies] PRIMARY KEY CLUSTERED ([currency_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Payment_schedule_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Payment_schedule_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Payment_schedule_types] (
        [payment_schedule_type_id] INT IDENTITY(1,1) NOT NULL,
        [schedule_type_name] VARCHAR(30) NULL,
        [billing_frequency_days] INT NULL,
        CONSTRAINT [PK_Payment_schedule_types] PRIMARY KEY CLUSTERED ([payment_schedule_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Payment_schedules_per_plan]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Payment_schedules_per_plan]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Payment_schedules_per_plan] (
        [suscription_plan_id] INT NOT NULL,
        [payment_schedule_type_id] INT NOT NULL,
        [price] DECIMAL(10,2) NULL,
        [discount_percentage] DECIMAL(5,2) NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Payment_schedules_per_plan] PRIMARY KEY CLUSTERED ([suscription_plan_id] ASC, [payment_schedule_type_id] ASC),
        CONSTRAINT [FK_Payment_schedules_per_plan_Subscription_plans] FOREIGN KEY ([suscription_plan_id])
            REFERENCES [crm].[Subscription_plans] ([suscription_plan_id]),
        CONSTRAINT [FK_Payment_schedules_per_plan_Payment_schedule_types] FOREIGN KEY ([payment_schedule_type_id])
            REFERENCES [crm].[Payment_schedule_types] ([payment_schedule_type_id]),
        CONSTRAINT [FK_Payment_schedules_per_plan_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Payment_schedules_per_plan_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Payment_schedules_per_plan_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Payment_schedules_per_plan_suscription_plan_id] ON [crm].[Payment_schedules_per_plan] ([suscription_plan_id]);
    CREATE INDEX [idx_Payment_schedules_per_plan_payment_schedule_type_id] ON [crm].[Payment_schedules_per_plan] ([payment_schedule_type_id]);
    CREATE INDEX [idx_Payment_schedules_per_plan_status_catalog_id] ON [crm].[Payment_schedules_per_plan] ([status_catalog_id]);
    CREATE INDEX [idx_Payment_schedules_per_plan_deleted_at] ON [crm].[Payment_schedules_per_plan] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Payment_method_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Payment_method_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Payment_method_types] (
        [payment_method_type_id] INT IDENTITY(1,1) NOT NULL,
        [method_type_name] VARCHAR(40) NULL,
        CONSTRAINT [PK_Payment_method_types] PRIMARY KEY CLUSTERED ([payment_method_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Payment_methods]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Payment_methods]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Payment_methods] (
        [payment_method_id] INT IDENTITY(1,1) NOT NULL,
        [subscriber_id] INT NOT NULL,
        [payment_method_type_id] INT NOT NULL,
        [card_last_four] VARCHAR(4) NULL,
        [card_brand] VARCHAR(20) NULL,
        [expiry_month] TINYINT NULL,
        [expiry_year] SMALLINT NULL,
        [billing_address_id] INT NULL,
        [is_default] BIT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [checksum] VARCHAR(64) NULL,
        [verification_status] VARCHAR(20) NULL,
        [verified_at] DATETIME2 NULL,
        [last_used_at] DATETIME2 NULL,
        [fingerprint] VARCHAR(64) NULL,
        [stripe_payment_method_id] VARCHAR(100) NULL,
        [paypal_billing_agreement_id] VARCHAR(100) NULL,
        CONSTRAINT [PK_Payment_methods] PRIMARY KEY CLUSTERED ([payment_method_id] ASC),
        CONSTRAINT [FK_Payment_methods_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Payment_methods_Payment_method_types] FOREIGN KEY ([payment_method_type_id])
            REFERENCES [crm].[Payment_method_types] ([payment_method_type_id]),
        CONSTRAINT [FK_Payment_methods_Addresses] FOREIGN KEY ([billing_address_id])
            REFERENCES [crm].[Addresses] ([address_id]),
        CONSTRAINT [FK_Payment_methods_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Payment_methods_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [CK_Payment_methods_card_last_four_length] CHECK ([card_last_four] IS NULL OR LEN([card_last_four]) = 4),
        CONSTRAINT [CK_Payment_methods_expiry_month_range] CHECK ([expiry_month] IS NULL OR ([expiry_month] >= 1 AND [expiry_month] <= 12))
    );
    CREATE INDEX [idx_Payment_methods_subscriber_id] ON [crm].[Payment_methods] ([subscriber_id]);
    CREATE INDEX [idx_Payment_methods_payment_method_type_id] ON [crm].[Payment_methods] ([payment_method_type_id]);
    CREATE INDEX [idx_Payment_methods_billing_address_id] ON [crm].[Payment_methods] ([billing_address_id]);
    CREATE INDEX [idx_Payment_methods_status_catalog_id] ON [crm].[Payment_methods] ([status_catalog_id]);
    CREATE INDEX [idx_Payment_methods_deleted_at] ON [crm].[Payment_methods] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Payment_methods_one_default_per_subscriber] ON [crm].[Payment_methods] ([subscriber_id]) WHERE [is_default] = 1 AND [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Payment_methods_stripe_payment_method_id] ON [crm].[Payment_methods] ([stripe_payment_method_id]) WHERE [stripe_payment_method_id] IS NOT NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscriptions]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscriptions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscriptions] (
        [subscription_id] INT IDENTITY(1,1) NOT NULL,
        [subscriber_id] INT NOT NULL,
        [suscription_plan_id] INT NOT NULL,
        [payment_schedule_type_id] INT NOT NULL,
        [payment_method_id] INT NULL,
        [start_date] DATETIME2 NULL,
        [end_date] DATETIME2 NULL,
        [next_billing_date] DATETIME2 NULL,
        [auto_renew] BIT NULL,
        [is_recurring] BIT NULL,
        [recurrence_count] INT NULL,
        [is_trial] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [trial_start_date] DATETIME2 NULL,
        [trial_end_date] DATETIME2 NULL,
        [cancelled_at] DATETIME2 NULL,
        [cancelled_by] INT NULL,
        [cancellation_reason] NVARCHAR(500) NULL,
        [grace_period_end_date] DATETIME2 NULL,
        [stripe_subscription_id] VARCHAR(100) NULL,
        [chargebee_subscription_id] VARCHAR(100) NULL,
        [metadata] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Subscriptions] PRIMARY KEY CLUSTERED ([subscription_id] ASC),
        CONSTRAINT [FK_Subscriptions_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Subscriptions_Subscription_plans] FOREIGN KEY ([suscription_plan_id])
            REFERENCES [crm].[Subscription_plans] ([suscription_plan_id]),
        CONSTRAINT [FK_Subscriptions_Payment_schedule_types] FOREIGN KEY ([payment_schedule_type_id])
            REFERENCES [crm].[Payment_schedule_types] ([payment_schedule_type_id]),
        CONSTRAINT [FK_Subscriptions_Payment_methods] FOREIGN KEY ([payment_method_id])
            REFERENCES [crm].[Payment_methods] ([payment_method_id]),
        CONSTRAINT [FK_Subscriptions_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Subscriptions_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Subscriptions_cancelled_by] FOREIGN KEY ([cancelled_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [CK_Subscriptions_end_date_after_start] CHECK ([end_date] IS NULL OR [end_date] >= [start_date]),
        CONSTRAINT [CK_Subscriptions_trial_dates] CHECK ([trial_end_date] IS NULL OR [trial_start_date] IS NULL OR [trial_end_date] >= [trial_start_date]),
        CONSTRAINT [CK_Subscriptions_recurrence_count_positive] CHECK ([recurrence_count] IS NULL OR [recurrence_count] >= 0)
    );
    CREATE INDEX [idx_Subscriptions_subscriber_id] ON [crm].[Subscriptions] ([subscriber_id]);
    CREATE INDEX [idx_Subscriptions_suscription_plan_id] ON [crm].[Subscriptions] ([suscription_plan_id]);
    CREATE INDEX [idx_Subscriptions_payment_schedule_type_id] ON [crm].[Subscriptions] ([payment_schedule_type_id]);
    CREATE INDEX [idx_Subscriptions_payment_method_id] ON [crm].[Subscriptions] ([payment_method_id]);
    CREATE INDEX [idx_Subscriptions_status_catalog_id] ON [crm].[Subscriptions] ([status_catalog_id]);
    CREATE INDEX [idx_Subscriptions_deleted_at] ON [crm].[Subscriptions] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE INDEX [idx_Subscriptions_next_billing_date] ON [crm].[Subscriptions] ([next_billing_date]) WHERE [auto_renew] = 1;
    CREATE INDEX [idx_Subscriptions_trial_end_date] ON [crm].[Subscriptions] ([trial_end_date]) WHERE [is_trial] = 1;
    CREATE UNIQUE INDEX [UQ_Subscriptions_stripe_subscription_id] ON [crm].[Subscriptions] ([stripe_subscription_id]) WHERE [stripe_subscription_id] IS NOT NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Subscription_feature_usage]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Subscription_feature_usage]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Subscription_feature_usage] (
        [subscription_id] INT NOT NULL,
        [subscription_feature_id] INT NOT NULL,
        [usage_count] INT NULL,
        [last_used_at] DATETIME2 NULL,
        [reset_at] DATETIME2 NULL,
        [checksum] VARCHAR(64) NULL,
        CONSTRAINT [PK_Subscription_feature_usage] PRIMARY KEY CLUSTERED ([subscription_id] ASC, [subscription_feature_id] ASC),
        CONSTRAINT [FK_Subscription_feature_usage_Subscriptions] FOREIGN KEY ([subscription_id])
            REFERENCES [crm].[Subscriptions] ([subscription_id]),
        CONSTRAINT [FK_Subscription_feature_usage_Subscription_features] FOREIGN KEY ([subscription_feature_id])
            REFERENCES [crm].[Subscription_features] ([subscription_feature_id])
    );
    CREATE INDEX [idx_Subscription_feature_usage_subscription_id] ON [crm].[Subscription_feature_usage] ([subscription_id]);
    CREATE INDEX [idx_Subscription_feature_usage_subscription_feature_id] ON [crm].[Subscription_feature_usage] ([subscription_feature_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Transaction_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Transaction_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Transaction_types] (
        [transaction_type_id] INT IDENTITY(1,1) NOT NULL,
        [transaction_type_name] VARCHAR(40) NULL,
        CONSTRAINT [PK_Transaction_types] PRIMARY KEY CLUSTERED ([transaction_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Transactions]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Transactions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Transactions] (
        [transaction_id] INT IDENTITY(1,1) NOT NULL,
        [subscription_id] INT NOT NULL,
        [transaction_type_id] INT NOT NULL,
        [amount] DECIMAL(10,2) NULL,
        [currency_id] INT NOT NULL,
        [payment_method_id] INT NULL,
        [transaction_reference] VARCHAR(100) NULL,
        [external_transaction_id] VARCHAR(100) NULL,
        [description] NVARCHAR(MAX) NULL,
        [processed_at] DATETIME2 NULL,
        [created_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [checksum] VARCHAR(64) NULL,
        [reconciled_at] DATETIME2 NULL,
        [reconciled_by] INT NULL,
        [settlement_date] DATETIME2 NULL,
        [refunded_at] DATETIME2 NULL,
        [refund_amount] DECIMAL(10,2) NULL,
        [refund_reason] NVARCHAR(500) NULL,
        [invoice_number] VARCHAR(50) NULL,
        [receipt_url] VARCHAR(500) NULL,
        [stripe_payment_intent_id] VARCHAR(100) NULL,
        [stripe_charge_id] VARCHAR(100) NULL,
        CONSTRAINT [PK_Transactions] PRIMARY KEY CLUSTERED ([transaction_id] ASC),
        CONSTRAINT [FK_Transactions_Subscriptions] FOREIGN KEY ([subscription_id])
            REFERENCES [crm].[Subscriptions] ([subscription_id]),
        CONSTRAINT [FK_Transactions_Transaction_types] FOREIGN KEY ([transaction_type_id])
            REFERENCES [crm].[Transaction_types] ([transaction_type_id]),
        CONSTRAINT [FK_Transactions_Currencies] FOREIGN KEY ([currency_id])
            REFERENCES [crm].[Currencies] ([currency_id]),
        CONSTRAINT [FK_Transactions_Payment_methods] FOREIGN KEY ([payment_method_id])
            REFERENCES [crm].[Payment_methods] ([payment_method_id]),
        CONSTRAINT [FK_Transactions_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Transactions_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Transactions_reconciled_by] FOREIGN KEY ([reconciled_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [CK_Transactions_amount_positive] CHECK ([amount] >= 0),
        CONSTRAINT [CK_Transactions_refund_amount] CHECK ([refund_amount] IS NULL OR ([refund_amount] >= 0 AND [refund_amount] <= [amount]))
    );
    CREATE INDEX [idx_Transactions_subscription_id] ON [crm].[Transactions] ([subscription_id]);
    CREATE INDEX [idx_Transactions_transaction_type_id] ON [crm].[Transactions] ([transaction_type_id]);
    CREATE INDEX [idx_Transactions_currency_id] ON [crm].[Transactions] ([currency_id]);
    CREATE INDEX [idx_Transactions_payment_method_id] ON [crm].[Transactions] ([payment_method_id]);
    CREATE INDEX [idx_Transactions_status_catalog_id] ON [crm].[Transactions] ([status_catalog_id]);
    CREATE INDEX [idx_Transactions_deleted_at] ON [crm].[Transactions] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE INDEX [idx_Transactions_created_at_amount] ON [crm].[Transactions] ([created_at] DESC, [amount]);
    CREATE UNIQUE INDEX [UQ_Transactions_external_transaction_id] ON [crm].[Transactions] ([external_transaction_id]) WHERE [external_transaction_id] IS NOT NULL;
    CREATE UNIQUE INDEX [UQ_Transactions_invoice_number] ON [crm].[Transactions] ([invoice_number]) WHERE [invoice_number] IS NOT NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[AI_models]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[AI_models]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[AI_models] (
        [ai_model_id] INT IDENTITY(1,1) NOT NULL,
        [model_name] VARCHAR(80) NULL,
        [model_version] VARCHAR(20) NULL,
        [model_description] NVARCHAR(MAX) NULL,
        [model_provider] VARCHAR(60) NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_AI_models] PRIMARY KEY CLUSTERED ([ai_model_id] ASC),
        CONSTRAINT [FK_AI_models_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_AI_models_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_AI_models_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_AI_models_status_catalog_id] ON [crm].[AI_models] ([status_catalog_id]);
    CREATE INDEX [idx_AI_models_deleted_at] ON [crm].[AI_models] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[AI_model_parameters]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[AI_model_parameters]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[AI_model_parameters] (
        [parameter_id] INT IDENTITY(1,1) NOT NULL,
        [ai_model_id] INT NOT NULL,
        [parameter_name] VARCHAR(60) NULL,
        [parameter_type] VARCHAR(20) NULL,
        [default_value] VARCHAR(255) NULL,
        [min_value] VARCHAR(20) NULL,
        [max_value] VARCHAR(20) NULL,
        [description] NVARCHAR(MAX) NULL,
        [is_required] BIT NULL,
        [created_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_AI_model_parameters] PRIMARY KEY CLUSTERED ([parameter_id] ASC),
        CONSTRAINT [FK_AI_model_parameters_AI_models] FOREIGN KEY ([ai_model_id])
            REFERENCES [crm].[AI_models] ([ai_model_id]),
        CONSTRAINT [FK_AI_model_parameters_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_AI_model_parameters_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_AI_model_parameters_ai_model_id] ON [crm].[AI_model_parameters] ([ai_model_id]);
    CREATE INDEX [idx_AI_model_parameters_deleted_at] ON [crm].[AI_model_parameters] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[AI_model_usage_logs]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[AI_model_usage_logs]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[AI_model_usage_logs] (
        [usage_log_id] INT IDENTITY(1,1) NOT NULL,
        [ai_model_id] INT NOT NULL,
        [user_id] INT NULL,
        [subscriber_id] INT NOT NULL,
        [prompt_text] NVARCHAR(MAX) NULL,
        [response_text] NVARCHAR(MAX) NULL,
        [parameters_used] NVARCHAR(MAX) NULL,
        [tokens_input] INT NULL,
        [tokens_output] INT NULL,
        [processing_time_ms] INT NULL,
        [cost_amount] DECIMAL(10,4) NULL,
        [error_message] NVARCHAR(MAX) NULL,
        [created_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [checksum] VARCHAR(64) NULL,
        CONSTRAINT [PK_AI_model_usage_logs] PRIMARY KEY CLUSTERED ([usage_log_id] ASC),
        CONSTRAINT [FK_AI_model_usage_logs_AI_models] FOREIGN KEY ([ai_model_id])
            REFERENCES [crm].[AI_models] ([ai_model_id]),
        CONSTRAINT [FK_AI_model_usage_logs_Users] FOREIGN KEY ([user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_AI_model_usage_logs_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_AI_model_usage_logs_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [CK_AI_model_usage_logs_tokens_positive] CHECK ([tokens_input] IS NULL OR [tokens_input] >= 0),
        CONSTRAINT [CK_AI_model_usage_logs_tokens_output_positive] CHECK ([tokens_output] IS NULL OR [tokens_output] >= 0),
        CONSTRAINT [CK_AI_model_usage_logs_cost_positive] CHECK ([cost_amount] IS NULL OR [cost_amount] >= 0)
    );
    CREATE INDEX [idx_AI_model_usage_logs_ai_model_id] ON [crm].[AI_model_usage_logs] ([ai_model_id]);
    CREATE INDEX [idx_AI_model_usage_logs_user_id] ON [crm].[AI_model_usage_logs] ([user_id]);
    CREATE INDEX [idx_AI_model_usage_logs_subscriber_id] ON [crm].[AI_model_usage_logs] ([subscriber_id]);
    CREATE INDEX [idx_AI_model_usage_logs_status_catalog_id] ON [crm].[AI_model_usage_logs] ([status_catalog_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Marketing_channel_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Marketing_channel_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Marketing_channel_types] (
        [channel_type_id] INT IDENTITY(1,1) NOT NULL,
        [channel_type_name] VARCHAR(40) NULL,
        CONSTRAINT [PK_Marketing_channel_types] PRIMARY KEY CLUSTERED ([channel_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Marketing_channels]
-- Marketing channels are also lead sources (merged concept)
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Marketing_channels]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Marketing_channels] (
        [marketing_channel_id] INT IDENTITY(1,1) NOT NULL,
        [channel_name] VARCHAR(80) NULL,
        [channel_description] NVARCHAR(MAX) NULL,
        [channel_type_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Marketing_channels] PRIMARY KEY CLUSTERED ([marketing_channel_id] ASC),
        CONSTRAINT [FK_Marketing_channels_Marketing_channel_types] FOREIGN KEY ([channel_type_id])
            REFERENCES [crm].[Marketing_channel_types] ([channel_type_id]),
        CONSTRAINT [FK_Marketing_channels_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Marketing_channels_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Marketing_channels_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Marketing_channels_channel_type_id] ON [crm].[Marketing_channels] ([channel_type_id]);
    CREATE INDEX [idx_Marketing_channels_status_catalog_id] ON [crm].[Marketing_channels] ([status_catalog_id]);
    CREATE INDEX [idx_Marketing_channels_deleted_at] ON [crm].[Marketing_channels] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Leads]
-- Anonymous lead tracking: only UTM, ad IDs, events
-- No personal info unless authorized via campaign
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Leads]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Leads] (
        [lead_id] INT IDENTITY(1,1) NOT NULL,
        [subscriber_id] INT NOT NULL,
        [lead_token] VARCHAR(100) NOT NULL,
        [utm_source] VARCHAR(100) NULL,
        [utm_medium] VARCHAR(100) NULL,
        [utm_campaign] VARCHAR(100) NULL,
        [utm_term] VARCHAR(100) NULL,
        [utm_content] VARCHAR(100) NULL,
        [ad_id] VARCHAR(100) NULL,
        [external_campaign_id] VARCHAR(100) NULL,
        [first_name] VARCHAR(60) NULL,
        [last_name] VARCHAR(60) NULL,
        [email] VARCHAR(255) NULL,
        [phone_number] VARCHAR(18) NULL,
        [device_type] VARCHAR(40) NULL,
        [browser_type] VARCHAR(40) NULL,
        [operating_system] VARCHAR(40) NULL,
        [ip_address] VARCHAR(45) NULL,
        [country_id] INT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [marketing_channel_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [lead_score] INT NULL,
        [assigned_to_user_id] INT NULL,
        [assigned_at] DATETIME2 NULL,
        [last_contacted_at] DATETIME2 NULL,
        [next_followup_date] DATETIME2 NULL,
        [qualification_date] DATETIME2 NULL,
        [qualified_by] INT NULL,
        [converted_to_customer_at] DATETIME2 NULL,
        [conversion_value] DECIMAL(12,2) NULL,
        [time_to_conversion_hours] INT NULL,
        [referrer_url] VARCHAR(500) NULL,
        [landing_page_url] VARCHAR(500) NULL,
        [last_activity_at] DATETIME2 NULL,
        [hubspot_deal_id] VARCHAR(100) NULL,
        [salesforce_lead_id] VARCHAR(100) NULL,
        [custom_fields] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Leads] PRIMARY KEY CLUSTERED ([lead_id] ASC),
        CONSTRAINT [FK_Leads_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Leads_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Leads_Marketing_channels] FOREIGN KEY ([marketing_channel_id])
            REFERENCES [crm].[Marketing_channels] ([marketing_channel_id]),
        CONSTRAINT [FK_Leads_Countries] FOREIGN KEY ([country_id])
            REFERENCES [crm].[Countries] ([country_id]),
        CONSTRAINT [FK_Leads_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Leads_assigned_to] FOREIGN KEY ([assigned_to_user_id])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Leads_qualified_by] FOREIGN KEY ([qualified_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [CK_Leads_lead_score_range] CHECK ([lead_score] IS NULL OR ([lead_score] >= 0 AND [lead_score] <= 100)),
        CONSTRAINT [CK_Leads_email_format] CHECK ([email] IS NULL OR [email] LIKE '%_@_%.__%')
    );
    CREATE INDEX [idx_Leads_subscriber_id] ON [crm].[Leads] ([subscriber_id]);
    CREATE INDEX [idx_Leads_status_catalog_id] ON [crm].[Leads] ([status_catalog_id]);
    CREATE INDEX [idx_Leads_marketing_channel_id] ON [crm].[Leads] ([marketing_channel_id]);
    CREATE INDEX [idx_Leads_country_id] ON [crm].[Leads] ([country_id]);
    CREATE INDEX [idx_Leads_deleted_at] ON [crm].[Leads] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE INDEX [idx_Leads_lead_score] ON [crm].[Leads] ([lead_score] DESC);
    CREATE INDEX [idx_Leads_assigned_to_user_id] ON [crm].[Leads] ([assigned_to_user_id]);
    CREATE INDEX [idx_Leads_next_followup_date] ON [crm].[Leads] ([next_followup_date]);
    CREATE INDEX [idx_Leads_created_at] ON [crm].[Leads] ([created_at] DESC);
    CREATE UNIQUE INDEX [UQ_Leads_lead_token] ON [crm].[Leads] ([lead_token]) WHERE [lead_token] IS NOT NULL;
    CREATE UNIQUE INDEX [UQ_Leads_email_per_subscriber] ON [crm].[Leads] ([subscriber_id], [email]) WHERE [email] IS NOT NULL AND [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Lead_event_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Lead_event_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Lead_event_types] (
        [event_type_id] INT IDENTITY(1,1) NOT NULL,
        [event_type_name] VARCHAR(40) NULL,
        CONSTRAINT [PK_Lead_event_types] PRIMARY KEY CLUSTERED ([event_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Lead_events]
-- Track anonymous events: views, clicks, conversions
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Lead_events]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Lead_events] (
        [lead_event_id] INT IDENTITY(1,1) NOT NULL,
        [lead_id] INT NOT NULL,
        [event_type_id] INT NOT NULL,
        [conversion_amount] DECIMAL(12,2) NULL,
        [currency_id] INT NULL,
        [event_metadata] NVARCHAR(MAX) NULL,
        [occurred_at] DATETIME2 NULL,
        [checksum] VARCHAR(64) NULL,
        CONSTRAINT [PK_Lead_events] PRIMARY KEY CLUSTERED ([lead_event_id] ASC),
        CONSTRAINT [FK_Lead_events_Leads] FOREIGN KEY ([lead_id])
            REFERENCES [crm].[Leads] ([lead_id]),
        CONSTRAINT [FK_Lead_events_Lead_event_types] FOREIGN KEY ([event_type_id])
            REFERENCES [crm].[Lead_event_types] ([event_type_id]),
        CONSTRAINT [FK_Lead_events_Currencies] FOREIGN KEY ([currency_id])
            REFERENCES [crm].[Currencies] ([currency_id]),
        CONSTRAINT [CK_Lead_events_conversion_amount_positive] CHECK ([conversion_amount] IS NULL OR [conversion_amount] >= 0)
    );
    CREATE INDEX [idx_Lead_events_lead_id] ON [crm].[Lead_events] ([lead_id]);
    CREATE INDEX [idx_Lead_events_event_type_id] ON [crm].[Lead_events] ([event_type_id]);
    CREATE INDEX [idx_Lead_events_currency_id] ON [crm].[Lead_events] ([currency_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Sales_funnel_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Sales_funnel_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Sales_funnel_types] (
        [funnel_type_id] INT IDENTITY(1,1) NOT NULL,
        [funnel_type_name] VARCHAR(60) NULL,
        [funnel_type_description] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_Sales_funnel_types] PRIMARY KEY CLUSTERED ([funnel_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Sales_funnels]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Sales_funnels]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Sales_funnels] (
        [sales_funnel_id] INT IDENTITY(1,1) NOT NULL,
        [subscriber_id] INT NOT NULL,
        [funnel_name] VARCHAR(100) NULL,
        [funnel_description] NVARCHAR(MAX) NULL,
        [funnel_type_id] INT NOT NULL,
        [enabled] BIT NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Sales_funnels] PRIMARY KEY CLUSTERED ([sales_funnel_id] ASC),
        CONSTRAINT [FK_Sales_funnels_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Sales_funnels_Sales_funnel_types] FOREIGN KEY ([funnel_type_id])
            REFERENCES [crm].[Sales_funnel_types] ([funnel_type_id]),
        CONSTRAINT [FK_Sales_funnels_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Sales_funnels_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Sales_funnels_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Sales_funnels_subscriber_id] ON [crm].[Sales_funnels] ([subscriber_id]);
    CREATE INDEX [idx_Sales_funnels_funnel_type_id] ON [crm].[Sales_funnels] ([funnel_type_id]);
    CREATE INDEX [idx_Sales_funnels_status_catalog_id] ON [crm].[Sales_funnels] ([status_catalog_id]);
    CREATE INDEX [idx_Sales_funnels_deleted_at] ON [crm].[Sales_funnels] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Funnel_stages]
-- Each stage calls a HubSpot workflow
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Funnel_stages]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Funnel_stages] (
        [funnel_stage_id] INT IDENTITY(1,1) NOT NULL,
        [sales_funnel_id] INT NOT NULL,
        [stage_name] VARCHAR(60) NULL,
        [stage_order] INT NULL,
        [stage_description] NVARCHAR(MAX) NULL,
        [hubspot_workflow_id] VARCHAR(100) NULL,
        [expected_duration_hours] INT NULL,
        [created_at] DATETIME2 NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Funnel_stages] PRIMARY KEY CLUSTERED ([funnel_stage_id] ASC),
        CONSTRAINT [FK_Funnel_stages_Sales_funnels] FOREIGN KEY ([sales_funnel_id])
            REFERENCES [crm].[Sales_funnels] ([sales_funnel_id]),
        CONSTRAINT [FK_Funnel_stages_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Funnel_stages_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Funnel_stages_sales_funnel_id] ON [crm].[Funnel_stages] ([sales_funnel_id]);
    CREATE INDEX [idx_Funnel_stages_deleted_at] ON [crm].[Funnel_stages] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Leads_in_funnel]
-- Track leads through funnel stages
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Leads_in_funnel]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Leads_in_funnel] (
        [lead_in_funnel_id] INT IDENTITY(1,1) NOT NULL,
        [lead_id] INT NOT NULL,
        [sales_funnel_id] INT NOT NULL,
        [funnel_stage_id] INT NOT NULL,
        [entered_at] DATETIME2 NULL,
        [exited_at] DATETIME2 NULL,
        [is_active] BIT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Leads_in_funnel] PRIMARY KEY CLUSTERED ([lead_in_funnel_id] ASC),
        CONSTRAINT [FK_Leads_in_funnel_Leads] FOREIGN KEY ([lead_id])
            REFERENCES [crm].[Leads] ([lead_id]),
        CONSTRAINT [FK_Leads_in_funnel_Sales_funnels] FOREIGN KEY ([sales_funnel_id])
            REFERENCES [crm].[Sales_funnels] ([sales_funnel_id]),
        CONSTRAINT [FK_Leads_in_funnel_Funnel_stages] FOREIGN KEY ([funnel_stage_id])
            REFERENCES [crm].[Funnel_stages] ([funnel_stage_id]),
        CONSTRAINT [FK_Leads_in_funnel_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Leads_in_funnel_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Leads_in_funnel_lead_id] ON [crm].[Leads_in_funnel] ([lead_id]);
    CREATE INDEX [idx_Leads_in_funnel_sales_funnel_id] ON [crm].[Leads_in_funnel] ([sales_funnel_id]);
    CREATE INDEX [idx_Leads_in_funnel_funnel_stage_id] ON [crm].[Leads_in_funnel] ([funnel_stage_id]);
    CREATE INDEX [idx_Leads_in_funnel_deleted_at] ON [crm].[Leads_in_funnel] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Workflow_execution_logs]
-- Log HubSpot workflow calls per funnel stage
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Workflow_execution_logs]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Workflow_execution_logs] (
        [execution_log_id] INT IDENTITY(1,1) NOT NULL,
        [lead_in_funnel_id] INT NOT NULL,
        [funnel_stage_id] INT NOT NULL,
        [hubspot_workflow_id] VARCHAR(100) NULL,
        [execution_status] VARCHAR(40) NULL,
        [request_payload] NVARCHAR(MAX) NULL,
        [response_payload] NVARCHAR(MAX) NULL,
        [error_message] NVARCHAR(MAX) NULL,
        [executed_at] DATETIME2 NULL,
        CONSTRAINT [PK_Workflow_execution_logs] PRIMARY KEY CLUSTERED ([execution_log_id] ASC),
        CONSTRAINT [FK_Workflow_execution_logs_Leads_in_funnel] FOREIGN KEY ([lead_in_funnel_id])
            REFERENCES [crm].[Leads_in_funnel] ([lead_in_funnel_id]),
        CONSTRAINT [FK_Workflow_execution_logs_Funnel_stages] FOREIGN KEY ([funnel_stage_id])
            REFERENCES [crm].[Funnel_stages] ([funnel_stage_id])
    );
    CREATE INDEX [idx_Workflow_execution_logs_lead_in_funnel_id] ON [crm].[Workflow_execution_logs] ([lead_in_funnel_id]);
    CREATE INDEX [idx_Workflow_execution_logs_funnel_stage_id] ON [crm].[Workflow_execution_logs] ([funnel_stage_id]);
END
GO


-- -----------------------------------------------------
-- Table [crm].[Lead_nurturing_action_types]
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Lead_nurturing_action_types]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Lead_nurturing_action_types] (
        [action_type_id] INT IDENTITY(1,1) NOT NULL,
        [action_type_name] VARCHAR(60) NULL,
        CONSTRAINT [PK_Lead_nurturing_action_types] PRIMARY KEY CLUSTERED ([action_type_id] ASC)
    );
END
GO


-- -----------------------------------------------------
-- Table [crm].[Lead_nurturing_actions]
-- Actions to "bombard" leads to convert them to clients
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Lead_nurturing_actions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Lead_nurturing_actions] (
        [nurturing_action_id] INT IDENTITY(1,1) NOT NULL,
        [lead_id] INT NOT NULL,
        [funnel_stage_id] INT NULL,
        [action_type_id] INT NOT NULL,
        [action_description] NVARCHAR(MAX) NULL,
        [scheduled_at] DATETIME2 NULL,
        [executed_at] DATETIME2 NULL,
        [execution_result] VARCHAR(100) NULL,
        [notes] NVARCHAR(MAX) NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        CONSTRAINT [PK_Lead_nurturing_actions] PRIMARY KEY CLUSTERED ([nurturing_action_id] ASC),
        CONSTRAINT [FK_Lead_nurturing_actions_Leads] FOREIGN KEY ([lead_id])
            REFERENCES [crm].[Leads] ([lead_id]),
        CONSTRAINT [FK_Lead_nurturing_actions_Funnel_stages] FOREIGN KEY ([funnel_stage_id])
            REFERENCES [crm].[Funnel_stages] ([funnel_stage_id]),
        CONSTRAINT [FK_Lead_nurturing_actions_Lead_nurturing_action_types] FOREIGN KEY ([action_type_id])
            REFERENCES [crm].[Lead_nurturing_action_types] ([action_type_id]),
        CONSTRAINT [FK_Lead_nurturing_actions_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Lead_nurturing_actions_created_by] FOREIGN KEY ([created_by])
            REFERENCES [crm].[Users] ([user_id]),
        CONSTRAINT [FK_Lead_nurturing_actions_updated_by] FOREIGN KEY ([updated_by])
            REFERENCES [crm].[Users] ([user_id])
    );
    CREATE INDEX [idx_Lead_nurturing_actions_lead_id] ON [crm].[Lead_nurturing_actions] ([lead_id]);
    CREATE INDEX [idx_Lead_nurturing_actions_funnel_stage_id] ON [crm].[Lead_nurturing_actions] ([funnel_stage_id]);
    CREATE INDEX [idx_Lead_nurturing_actions_action_type_id] ON [crm].[Lead_nurturing_actions] ([action_type_id]);
    CREATE INDEX [idx_Lead_nurturing_actions_status_catalog_id] ON [crm].[Lead_nurturing_actions] ([status_catalog_id]);
    CREATE INDEX [idx_Lead_nurturing_actions_deleted_at] ON [crm].[Lead_nurturing_actions] ([deleted_at]) WHERE [deleted_at] IS NULL;
END
GO


-- -----------------------------------------------------
-- Table [crm].[Customers]
-- Converted leads become customers
-- Still minimal info unless authorized
-- -----------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[crm].[Customers]') AND type in (N'U'))
BEGIN
    CREATE TABLE [crm].[Customers] (
        [customer_id] INT IDENTITY(1,1) NOT NULL,
        [lead_id] INT NOT NULL,
        [subscriber_id] INT NOT NULL,
        [customer_since] DATETIME2 NULL,
        [total_conversions] INT NULL,
        [total_conversion_value] DECIMAL(12,2) NULL,
        [last_conversion_date] DATETIME2 NULL,
        [created_at] DATETIME2 NULL,
        [updated_at] DATETIME2 NULL,
        [status_catalog_id] INT NOT NULL,
        [created_by] INT NULL,
        [updated_by] INT NULL,
        [deleted_at] DATETIME2 NULL,
        [lifetime_value] DECIMAL(12,2) NULL,
        [average_order_value] DECIMAL(12,2) NULL,
        [churn_risk_score] INT NULL,
        [last_purchase_date] DATETIME2 NULL,
        [preferred_contact_method] VARCHAR(20) NULL,
        [customer_tier] VARCHAR(20) NULL,
        [referral_code] VARCHAR(20) NULL,
        [referred_by_customer_id] INT NULL,
        CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([customer_id] ASC),
        CONSTRAINT [FK_Customers_Leads] FOREIGN KEY ([lead_id])
            REFERENCES [crm].[Leads] ([lead_id]),
        CONSTRAINT [FK_Customers_Subscribers] FOREIGN KEY ([subscriber_id])
            REFERENCES [crm].[Subscribers] ([subscriber_id]),
        CONSTRAINT [FK_Customers_Status_catalog] FOREIGN KEY ([status_catalog_id])
            REFERENCES [crm].[Status_catalog] ([status_catalog_id]),
        CONSTRAINT [FK_Customers_referred_by] FOREIGN KEY ([referred_by_customer_id])
            REFERENCES [crm].[Customers] ([customer_id]),
        CONSTRAINT [CK_Customers_churn_risk_score_range] CHECK ([churn_risk_score] IS NULL OR ([churn_risk_score] >= 0 AND [churn_risk_score] <= 100))
    );
    CREATE INDEX [idx_Customers_lead_id] ON [crm].[Customers] ([lead_id]);
    CREATE INDEX [idx_Customers_subscriber_id] ON [crm].[Customers] ([subscriber_id]);
    CREATE INDEX [idx_Customers_status_catalog_id] ON [crm].[Customers] ([status_catalog_id]);
    CREATE INDEX [idx_Customers_deleted_at] ON [crm].[Customers] ([deleted_at]) WHERE [deleted_at] IS NULL;
    CREATE INDEX [idx_Customers_lifetime_value] ON [crm].[Customers] ([lifetime_value] DESC) WHERE [lifetime_value] IS NOT NULL;
    CREATE INDEX [idx_Customers_churn_risk] ON [crm].[Customers] ([churn_risk_score] DESC) WHERE [churn_risk_score] IS NOT NULL;
    CREATE UNIQUE INDEX [UQ_Customers_lead_id] ON [crm].[Customers] ([lead_id]) WHERE [deleted_at] IS NULL;
    CREATE UNIQUE INDEX [UQ_Customers_referral_code] ON [crm].[Customers] ([referral_code]) WHERE [referral_code] IS NOT NULL;
END
GO

