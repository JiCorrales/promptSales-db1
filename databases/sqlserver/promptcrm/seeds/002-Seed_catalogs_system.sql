-- =============================================
-- PromptCRM - Seed Data: System Catalogs
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Populate system-level catalogs (statuses, types, etc.)
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'SEEDING SYSTEM CATALOGS';
PRINT '========================================';
PRINT '';

-- =============================================
-- USER STATUSES
-- =============================================
PRINT 'Inserting User Statuses...';

SET IDENTITY_INSERT [crm].[UserStatuses] ON;

INSERT INTO [crm].[UserStatuses] (userStatusId, userStatusKey, userStatusName, enabled)
VALUES
    (1, 'ACTIVE', 'Active', 1),
    (2, 'INACTIVE', 'Inactive', 1),
    (3, 'SUSPENDED', 'Suspended', 1),
    (4, 'PENDING_VERIFICATION', 'Pending Verification', 1),
    (5, 'LOCKED', 'Locked', 1),
    (6, 'DELETED', 'Deleted', 1);

SET IDENTITY_INSERT [crm].[UserStatuses] OFF;

PRINT '  ✓ Inserted 6 user statuses';

-- =============================================
-- LOG TYPES
-- =============================================
PRINT 'Inserting Log Types...';

SET IDENTITY_INSERT [crm].[logTypes] ON;

INSERT INTO [crm].[logTypes] (logTypeId, logType, enabled)
VALUES
    (1, 'AUTHENTICATION', 1),
    (2, 'AUTHORIZATION', 1),
    (3, 'DATA_ACCESS', 1),
    (4, 'DATA_MODIFICATION', 1),
    (5, 'SYSTEM_ERROR', 1),
    (6, 'BUSINESS_LOGIC', 1),
    (7, 'API_CALL', 1),
    (8, 'PAYMENT', 1),
    (9, 'SECURITY', 1),
    (10, 'AUDIT', 1);

SET IDENTITY_INSERT [crm].[logTypes] OFF;

PRINT '  ✓ Inserted 10 log types';

-- =============================================
-- LOG LEVELS
-- =============================================
PRINT 'Inserting Log Levels...';

SET IDENTITY_INSERT [crm].[logLevels] ON;

INSERT INTO [crm].[logLevels] (logLevelId, logLevel, enabled)
VALUES
    (1, 'TRACE', 1),
    (2, 'DEBUG', 1),
    (3, 'INFO', 1),
    (4, 'WARN', 1),
    (5, 'ERROR', 1),
    (6, 'CRITICAL', 1);

SET IDENTITY_INSERT [crm].[logLevels] OFF;

PRINT '  ✓ Inserted 6 log levels';

-- =============================================
-- LOG SOURCES
-- =============================================
PRINT 'Inserting Log Sources...';

SET IDENTITY_INSERT [crm].[logSources] ON;

INSERT INTO [crm].[logSources] (logSourceId, log_source, enabled)
VALUES
    (1, 'WEB_PORTAL', 1),
    (2, 'MOBILE_APP', 1),
    (3, 'API_REST', 1),
    (4, 'API_MCP', 1),
    (5, 'BACKGROUND_JOB', 1),
    (6, 'DATABASE_TRIGGER', 1),
    (7, 'ETL_PIPELINE', 1),
    (8, 'WEBHOOK', 1),
    (9, 'CLI', 1),
    (10,'ADMIN_PANEL', 1);

SET IDENTITY_INSERT [crm].[logSources] OFF;

PRINT '  ✓ Inserted 10 log sources';

-- =============================================
-- CURRENCIES
-- =============================================
PRINT 'Inserting Currencies...';

SET IDENTITY_INSERT [crm].[Currencies] ON;

INSERT INTO [crm].[Currencies] (currencyId, currencyName, currencyCode, enabled)
VALUES
    (1, 'US Dollar', 'USD', 1),
    (2, 'Euro', 'EUR', 1),
    (3, 'Costa Rican Colón', 'CRC', 1);

SET IDENTITY_INSERT [crm].[Currencies] OFF;

PRINT '  ✓ Inserted 3 currencies';

-- =============================================
-- PAYMENT METHOD TYPES
-- =============================================
PRINT 'Inserting Payment Method Types...';

SET IDENTITY_INSERT [crm].[PaymentMethodTypes] ON;

INSERT INTO [crm].[PaymentMethodTypes] (paymentMethodTypeId, methodTypeName, enabled)
VALUES
    (1, 'CREDIT_CARD', 1),
    (2, 'DEBIT_CARD', 1),
    (3, 'BANK_ACCOUNT', 1),
    (4, 'PAYPAL', 1),
    (5, 'STRIPE', 1),
    (6, 'WIRE_TRANSFER', 1),
    (7, 'CRYPTO', 1),
    (8, 'APPLE_PAY', 1),
    (9, 'GOOGLE_PAY', 1);

SET IDENTITY_INSERT [crm].[PaymentMethodTypes] OFF;

PRINT '  ✓ Inserted 9 payment method types';

-- =============================================
-- PAYMENT SCHEDULE TYPES
-- =============================================
PRINT 'Inserting Payment Schedule Types...';

SET IDENTITY_INSERT [crm].[PaymentScheduleTypes] ON;

INSERT INTO [crm].[PaymentScheduleTypes] (paymentScheduleTypeId, scheduleTypeName, billingFrequencyDays, enabled)
VALUES
    (1, 'Monthly', 30, 1),
    (2, 'Quarterly', 90, 1),
    (3, 'Semi-Annual', 180, 1),
    (4, 'Annual', 365, 1),
    (5, 'Weekly', 7, 1),
    (6, 'Bi-Weekly', 14, 1);

SET IDENTITY_INSERT [crm].[PaymentScheduleTypes] OFF;

PRINT '  ✓ Inserted 6 payment schedule types';

-- =============================================
-- TRANSACTION TYPES
-- =============================================
PRINT 'Inserting Transaction Types...';

SET IDENTITY_INSERT [crm].[TransactionTypes] ON;

INSERT INTO [crm].[TransactionTypes] (transactionTypeId, transactionTypeName, enabled)
VALUES
    (1, 'SUBSCRIPTION_PAYMENT', 1),
    (2, 'ONE_TIME_PAYMENT', 1),
    (3, 'REFUND', 1),
    (4, 'CHARGEBACK', 1),
    (5, 'CREDIT_ADJUSTMENT', 1),
    (6, 'CAMPAIGN_CHARGE', 1),
    (7, 'OVERAGE_CHARGE', 1),
    (8, 'SETUP_FEE', 1);

SET IDENTITY_INSERT [crm].[TransactionTypes] OFF;

PRINT '  ✓ Inserted 8 transaction types';

-- =============================================
-- TRANSACTION STATUSES
-- =============================================
PRINT 'Inserting Transaction Statuses...';

SET IDENTITY_INSERT [crm].[TransactionStatuses] ON;

INSERT INTO [crm].[TransactionStatuses] (transactionStatusId, transactionStatusKey, transactionStatusName, enabled)
VALUES
    (1, 'PENDING', 'Pending', 1),
    (2, 'PROCESSING', 'Processing', 1),
    (3, 'AUTHORIZED', 'Authorized', 1),
    (4, 'CAPTURED', 'Captured', 1),
    (5, 'SETTLED', 'Settled', 1),
    (6, 'FAILED', 'Failed', 1),
    (7, 'DECLINED', 'Declined', 1),
    (8, 'CANCELED', 'Canceled', 1),
    (9, 'REFUNDED', 'Refunded', 1),
    (10, 'PARTIALLY_REFUNDED', 'Partially Refunded', 1);

SET IDENTITY_INSERT [crm].[TransactionStatuses] OFF;

PRINT '  ✓ Inserted 10 transaction statuses';

-- =============================================
-- SUBSCRIPTION STATUSES
-- =============================================
PRINT 'Inserting Subscription Statuses...';

SET IDENTITY_INSERT [crm].[SubscriptionStatuses] ON;

INSERT INTO [crm].[SubscriptionStatuses] (subscriptionStatusId, subscriptionKey, subscriptionName, enabled)
VALUES
    (1, 'TRIAL', 'Trial', 1),
    (2, 'ACTIVE', 'Active', 1),
    (3, 'PAST_DUE', 'Past Due', 1),
    (4, 'CANCELED', 'Canceled', 1),
    (5, 'EXPIRED', 'Expired', 1),
    (6, 'SUSPENDED', 'Suspended', 1),
    (7, 'PAUSED', 'Paused', 1);

SET IDENTITY_INSERT [crm].[SubscriptionStatuses] OFF;

PRINT '  ✓ Inserted 7 subscription statuses';

-- =============================================
-- SUBSCRIPTION FEATURE TYPES
-- =============================================
PRINT 'Inserting Subscription Feature Types...';

SET IDENTITY_INSERT [crm].[SubscriptionFeatureTypes] ON;

INSERT INTO [crm].[SubscriptionFeatureTypes] (subscriptionFeatureTypeId, featureTypeName, enabled)
VALUES
    (1, 'BOOLEAN', 1),
    (2, 'NUMERIC', 1),
    (3, 'QUOTA', 1),
    (4, 'TEXT', 1);

SET IDENTITY_INSERT [crm].[SubscriptionFeatureTypes] OFF;

PRINT '  ✓ Inserted 4 subscription feature types';

-- =============================================
-- CLIENT STATUSES
-- =============================================
PRINT 'Inserting Client Statuses...';

SET IDENTITY_INSERT [crm].[ClientStatuses] ON;

INSERT INTO [crm].[ClientStatuses] (clientStatusId, clientStatusKey, clientStatusName, description, enabled)
VALUES
    (1, 'NEW', 'New Client', 'Recently converted lead', 1),
    (2, 'ACTIVE', 'Active', 'Regular purchasing client', 1),
    (3, 'VIP', 'VIP Client', 'High-value client', 1),
    (4, 'AT_RISK', 'At Risk', 'Declining engagement', 1),
    (5, 'CHURNED', 'Churned', 'Lost client', 1),
    (6, 'REACTIVATED', 'Reactivated', 'Returned after churn', 1),
    (7, 'DORMANT', 'Dormant', 'No recent activity', 1);

SET IDENTITY_INSERT [crm].[ClientStatuses] OFF;

PRINT '  ✓ Inserted 7 client statuses';

-- =============================================
-- PERMISSIONS
-- =============================================
PRINT 'Inserting Permissions...';

SET IDENTITY_INSERT [crm].[Permissions] ON;

INSERT INTO [crm].[Permissions] (permissionId, permissionCode, description, enabled)
VALUES
    (1, 'USR_VIEW', 'View users', 1),
    (2, 'USR_CRTE', 'Create users', 1),
    (3, 'USR_EDIT', 'Edit users', 1),
    (4, 'USR_DEL', 'Delete users', 1),
    (5, 'LEAD_VW', 'View leads', 1),
    (6, 'LEAD_CRT', 'Create leads', 1),
    (7, 'LEAD_EDT', 'Edit leads', 1),
    (8, 'LEAD_DEL', 'Delete leads', 1),
    (9, 'CLI_VIEW', 'View clients', 1),
    (10, 'CLI_EDIT', 'Edit clients', 1),
    (11, 'FIN_VIEW', 'View financials', 1),
    (12, 'FIN_EDIT', 'Edit financials', 1),
    (13, 'RPT_VIEW', 'View reports', 1),
    (14, 'RPT_EXP', 'Export reports', 1),
    (15, 'ADM_FULL', 'Full admin access', 1),
    (16, 'CAMP_VW', 'View campaigns', 1),
    (17, 'CAMP_CRT', 'Create campaigns', 1),
    (18, 'CAMP_EDT', 'Edit campaigns', 1),
    (19, 'FNNEL_VW', 'View funnels', 1),
    (20, 'FNNEL_ED', 'Edit funnels', 1);

SET IDENTITY_INSERT [crm].[Permissions] OFF;

PRINT '  ✓ Inserted 20 permissions';

-- =============================================
-- AI MODELS
-- =============================================
PRINT 'Inserting AI Models...';

SET IDENTITY_INSERT [crm].[aiModels] ON;

INSERT INTO [crm].[aiModels] (aiModelId, modelName, modelVersion, modelDescription, modelProvider, status)
VALUES
    (1, 'GPT-4', '4.0', 'OpenAI GPT-4 for content generation', 'OpenAI', 'ACTIVE'),
    (2, 'GPT-3.5-Turbo', '3.5', 'OpenAI GPT-3.5 Turbo', 'OpenAI', 'ACTIVE'),
    (3, 'Claude-3-Opus', '3.0', 'Anthropic Claude 3 Opus', 'Anthropic', 'ACTIVE'),
    (4, 'Claude-3-Sonnet', '3.0', 'Anthropic Claude 3 Sonnet', 'Anthropic', 'ACTIVE'),
    (5, 'DALL-E-3', '3.0', 'OpenAI image generation', 'OpenAI', 'ACTIVE'),
    (6, 'Stable-Diffusion-XL', '1.0', 'Stability AI image generation', 'Stability AI', 'ACTIVE'),
    (7, 'Lead-Scoring-v1', '1.0', 'Custom lead scoring model', 'PromptSales', 'ACTIVE'),
    (8, 'Sentiment-Analysis-v2', '2.0', 'Customer sentiment analysis', 'PromptSales', 'ACTIVE');

SET IDENTITY_INSERT [crm].[aiModels] OFF;

PRINT '  ✓ Inserted 8 AI models';

PRINT '';
PRINT '========================================';
PRINT 'SYSTEM CATALOGS SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT '';

GO
