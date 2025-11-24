-- =============================================
-- PromptCRM - Seed Data: Subscription Plans & Features
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Create subscription plans with features for PromptCRM
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'SEEDING SUBSCRIPTION PLANS & FEATURES';
PRINT '========================================';
PRINT '';

-- =============================================
-- SUBSCRIPTION PLANS
-- =============================================
PRINT 'Inserting Subscription Plans...';

SET IDENTITY_INSERT [crm].[SubscriptionPlans] ON;

INSERT INTO [crm].[SubscriptionPlans] (subscriptionPlanId, planName, planDescription, enabled)
VALUES
    (1, 'Starter', 'Perfect for small businesses starting with CRM', 1),
    (2, 'Professional', 'For growing teams with advanced needs', 1),
    (3, 'Business', 'Comprehensive solution for established businesses', 1),
    (4, 'Enterprise', 'Unlimited power for large organizations', 1),
    (5, 'Free Trial', '14-day free trial with full features', 1);

SET IDENTITY_INSERT [crm].[SubscriptionPlans] OFF;

PRINT '  ✓ Inserted 5 subscription plans';

-- =============================================
-- SUBSCRIPTION FEATURES
-- =============================================
PRINT 'Inserting Subscription Features...';

SET IDENTITY_INSERT [crm].[SubscriptionFeatures] ON;

INSERT INTO [crm].[SubscriptionFeatures]
    (subscriptionFeatureId, featureCode, featureName, defaultValue, description, subscriptionFeatureTypeId, enabled)
VALUES
    -- User & Team Features
    (1, 'MAX_USERS', 'Maximum Users', '5', 'Maximum number of users allowed', 2, 1),
    (2, 'MAX_TEAMS', 'Maximum Teams', '1', 'Maximum number of teams', 2, 1),
    (3, 'SSO_ENABLED', 'Single Sign-On', 'false', 'SSO authentication', 1, 1),
    (4, 'CUSTOM_ROLES', 'Custom Roles', 'false', 'Create custom user roles', 1, 1),

    -- Lead Management Features
    (10, 'MAX_LEADS', 'Maximum Leads', '1000', 'Maximum leads per month', 3, 1),
    (11, 'LEAD_SCORING', 'Lead Scoring', 'true', 'AI-powered lead scoring', 1, 1),
    (12, 'LEAD_ENRICHMENT', 'Lead Enrichment', 'false', 'Auto-enrich lead data', 1, 1),
    (13, 'CUSTOM_FIELDS_LEADS', 'Custom Lead Fields', '5', 'Number of custom fields', 2, 1),

    -- Client Management
    (20, 'MAX_CLIENTS', 'Maximum Clients', '500', 'Maximum active clients', 3, 1),
    (21, 'CLIENT_SEGMENTATION', 'Client Segmentation', 'true', 'Segment clients', 1, 1),
    (22, 'RFM_ANALYSIS', 'RFM Analysis', 'false', 'Recency/Frequency/Monetary', 1, 1),

    -- Automation Features
    (30, 'MAX_AUTOMATIONS', 'Maximum Automations', '5', 'Active automation rules', 3, 1),
    (31, 'EMAIL_AUTOMATION', 'Email Automation', 'true', 'Automated email campaigns', 1, 1),
    (32, 'SMS_AUTOMATION', 'SMS Automation', 'false', 'Automated SMS', 1, 1),
    (33, 'WHATSAPP_AUTOMATION', 'WhatsApp Automation', 'false', 'Automated WhatsApp', 1, 1),
    (34, 'WORKFLOW_BUILDER', 'Workflow Builder', 'false', 'Visual workflow builder', 1, 1),

    -- Funnel Features
    (40, 'MAX_FUNNELS', 'Maximum Funnels', '3', 'Sales funnels allowed', 3, 1),
    (41, 'FUNNEL_ANALYTICS', 'Funnel Analytics', 'true', 'Detailed funnel reports', 1, 1),
    (42, 'AB_TESTING', 'A/B Testing', 'false', 'A/B test funnels', 1, 1),

    -- API & Integration Features
    (50, 'API_CALLS_MONTH', 'API Calls per Month', '1000', 'Monthly API call limit', 3, 1),
    (51, 'WEBHOOKS', 'Webhooks', 'true', 'Webhook integrations', 1, 1),
    (52, 'MCP_SERVERS', 'MCP Server Access', 'false', 'MCP server integration', 1, 1),
    (53, 'CUSTOM_INTEGRATIONS', 'Custom Integrations', '2', 'Number of integrations', 2, 1),

    -- Analytics & Reporting
    (60, 'STANDARD_REPORTS', 'Standard Reports', 'true', 'Pre-built reports', 1, 1),
    (61, 'CUSTOM_REPORTS', 'Custom Reports', 'false', 'Build custom reports', 1, 1),
    (62, 'EXPORT_DATA', 'Data Export', 'true', 'Export data to CSV/Excel', 1, 1),
    (63, 'ADVANCED_ANALYTICS', 'Advanced Analytics', 'false', 'AI-powered insights', 1, 1),

    -- AI Features
    (70, 'AI_CREDITS_MONTH', 'AI Credits per Month', '100', 'Monthly AI credits', 3, 1),
    (71, 'AI_CONTENT_GEN', 'AI Content Generation', 'false', 'Generate content with AI', 1, 1),
    (72, 'AI_LEAD_PREDICT', 'AI Lead Prediction', 'false', 'Predict conversion likelihood', 1, 1),
    (73, 'AI_SENTIMENT', 'AI Sentiment Analysis', 'false', 'Analyze customer sentiment', 1, 1),

    -- Support Features
    (80, 'SUPPORT_LEVEL', 'Support Level', 'EMAIL', 'Support channel access', 4, 1),
    (81, 'PRIORITY_SUPPORT', 'Priority Support', 'false', 'Priority support queue', 1, 1),
    (82, 'DEDICATED_MANAGER', 'Dedicated Account Manager', 'false', 'Personal account manager', 1, 1),

    -- Storage & Data
    (90, 'STORAGE_GB', 'Storage (GB)', '10', 'File storage in GB', 2, 1),
    (91, 'DATA_RETENTION_DAYS', 'Data Retention (Days)', '90', 'Days to retain data', 2, 1),
    (92, 'BACKUP_FREQUENCY', 'Backup Frequency', 'WEEKLY', 'Backup schedule', 4, 1);

SET IDENTITY_INSERT [crm].[SubscriptionFeatures] OFF;

PRINT '  ✓ Inserted 37 subscription features';

-- =============================================
-- FEATURES PER PLAN - STARTER
-- =============================================
PRINT 'Configuring Starter Plan features...';

INSERT INTO [crm].[FeaturesPerPlan] (suscriptionPlanId, subscriptionFeatureId, featureValue, enabled)
VALUES
    -- Starter: Basic limits
    (1, 1, '3', 1),        -- MAX_USERS: 3
    (1, 2, '1', 1),        -- MAX_TEAMS: 1
    (1, 3, 'false', 1),    -- SSO_ENABLED: false
    (1, 4, 'false', 1),    -- CUSTOM_ROLES: false

    (1, 10, '1000', 1),    -- MAX_LEADS: 1,000
    (1, 11, 'true', 1),    -- LEAD_SCORING: true
    (1, 12, 'false', 1),   -- LEAD_ENRICHMENT: false
    (1, 13, '3', 1),       -- CUSTOM_FIELDS: 3

    (1, 20, '500', 1),     -- MAX_CLIENTS: 500
    (1, 21, 'true', 1),    -- CLIENT_SEGMENTATION: true
    (1, 22, 'false', 1),   -- RFM_ANALYSIS: false

    (1, 30, '3', 1),       -- MAX_AUTOMATIONS: 3
    (1, 31, 'true', 1),    -- EMAIL_AUTOMATION: true
    (1, 32, 'false', 1),   -- SMS_AUTOMATION: false
    (1, 33, 'false', 1),   -- WHATSAPP: false
    (1, 34, 'false', 1),   -- WORKFLOW_BUILDER: false

    (1, 40, '2', 1),       -- MAX_FUNNELS: 2
    (1, 41, 'true', 1),    -- FUNNEL_ANALYTICS: true
    (1, 42, 'false', 1),   -- AB_TESTING: false

    (1, 50, '5000', 1),    -- API_CALLS: 5,000
    (1, 51, 'true', 1),    -- WEBHOOKS: true
    (1, 52, 'false', 1),   -- MCP_SERVERS: false
    (1, 53, '1', 1),       -- INTEGRATIONS: 1

    (1, 60, 'true', 1),    -- STANDARD_REPORTS: true
    (1, 61, 'false', 1),   -- CUSTOM_REPORTS: false
    (1, 62, 'true', 1),    -- EXPORT: true
    (1, 63, 'false', 1),   -- ADVANCED_ANALYTICS: false

    (1, 70, '500', 1),     -- AI_CREDITS: 500
    (1, 71, 'false', 1),   -- AI_CONTENT: false
    (1, 72, 'false', 1),   -- AI_PREDICT: false
    (1, 73, 'false', 1),   -- AI_SENTIMENT: false

    (1, 80, 'EMAIL', 1),   -- SUPPORT: Email only
    (1, 81, 'false', 1),   -- PRIORITY: false
    (1, 82, 'false', 1),   -- DEDICATED_MGR: false

    (1, 90, '5', 1),       -- STORAGE: 5 GB
    (1, 91, '90', 1),      -- RETENTION: 90 days
    (1, 92, 'WEEKLY', 1);  -- BACKUP: Weekly

PRINT '  ✓ Configured Starter plan (37 features)';

-- =============================================
-- FEATURES PER PLAN - PROFESSIONAL
-- =============================================
PRINT 'Configuring Professional Plan features...';

INSERT INTO [crm].[FeaturesPerPlan] (suscriptionPlanId, subscriptionFeatureId, featureValue, enabled)
VALUES
    (2, 1, '10', 1),       -- MAX_USERS: 10
    (2, 2, '3', 1),        -- MAX_TEAMS: 3
    (2, 3, 'true', 1),     -- SSO_ENABLED: true
    (2, 4, 'true', 1),     -- CUSTOM_ROLES: true

    (2, 10, '10000', 1),   -- MAX_LEADS: 10,000
    (2, 11, 'true', 1),    -- LEAD_SCORING: true
    (2, 12, 'true', 1),    -- LEAD_ENRICHMENT: true
    (2, 13, '10', 1),      -- CUSTOM_FIELDS: 10

    (2, 20, '5000', 1),    -- MAX_CLIENTS: 5,000
    (2, 21, 'true', 1),    -- SEGMENTATION: true
    (2, 22, 'true', 1),    -- RFM: true

    (2, 30, '15', 1),      -- AUTOMATIONS: 15
    (2, 31, 'true', 1),    -- EMAIL: true
    (2, 32, 'true', 1),    -- SMS: true
    (2, 33, 'true', 1),    -- WHATSAPP: true
    (2, 34, 'true', 1),    -- WORKFLOW: true

    (2, 40, '10', 1),      -- FUNNELS: 10
    (2, 41, 'true', 1),    -- ANALYTICS: true
    (2, 42, 'true', 1),    -- AB_TEST: true

    (2, 50, '50000', 1),   -- API: 50,000
    (2, 51, 'true', 1),    -- WEBHOOKS: true
    (2, 52, 'true', 1),    -- MCP: true
    (2, 53, '5', 1),       -- INTEGRATIONS: 5

    (2, 60, 'true', 1),    -- STD_REPORTS: true
    (2, 61, 'true', 1),    -- CUSTOM_REPORTS: true
    (2, 62, 'true', 1),    -- EXPORT: true
    (2, 63, 'true', 1),    -- ADV_ANALYTICS: true

    (2, 70, '5000', 1),    -- AI_CREDITS: 5,000
    (2, 71, 'true', 1),    -- AI_CONTENT: true
    (2, 72, 'true', 1),    -- AI_PREDICT: true
    (2, 73, 'true', 1),    -- AI_SENTIMENT: true

    (2, 80, 'CHAT', 1),    -- SUPPORT: Email + Chat
    (2, 81, 'true', 1),    -- PRIORITY: true
    (2, 82, 'false', 1),   -- DEDICATED: false

    (2, 90, '50', 1),      -- STORAGE: 50 GB
    (2, 91, '365', 1),     -- RETENTION: 1 year
    (2, 92, 'DAILY', 1);   -- BACKUP: Daily

PRINT '  ✓ Configured Professional plan (37 features)';

-- =============================================
-- FEATURES PER PLAN - BUSINESS
-- =============================================
PRINT 'Configuring Business Plan features...';

INSERT INTO [crm].[FeaturesPerPlan] (suscriptionPlanId, subscriptionFeatureId, featureValue, enabled)
VALUES
    (3, 1, '50', 1),       -- MAX_USERS: 50
    (3, 2, '10', 1),       -- MAX_TEAMS: 10
    (3, 3, 'true', 1),     -- SSO: true
    (3, 4, 'true', 1),     -- CUSTOM_ROLES: true

    (3, 10, '100000', 1),  -- LEADS: 100,000
    (3, 11, 'true', 1),
    (3, 12, 'true', 1),
    (3, 13, '25', 1),      -- FIELDS: 25

    (3, 20, '50000', 1),   -- CLIENTS: 50,000
    (3, 21, 'true', 1),
    (3, 22, 'true', 1),

    (3, 30, '50', 1),      -- AUTOMATIONS: 50
    (3, 31, 'true', 1),
    (3, 32, 'true', 1),
    (3, 33, 'true', 1),
    (3, 34, 'true', 1),

    (3, 40, '50', 1),      -- FUNNELS: 50
    (3, 41, 'true', 1),
    (3, 42, 'true', 1),

    (3, 50, '500000', 1),  -- API: 500,000
    (3, 51, 'true', 1),
    (3, 52, 'true', 1),
    (3, 53, '20', 1),      -- INTEGRATIONS: 20

    (3, 60, 'true', 1),
    (3, 61, 'true', 1),
    (3, 62, 'true', 1),
    (3, 63, 'true', 1),

    (3, 70, '25000', 1),   -- AI: 25,000
    (3, 71, 'true', 1),
    (3, 72, 'true', 1),
    (3, 73, 'true', 1),

    (3, 80, 'PHONE', 1),   -- SUPPORT: All channels
    (3, 81, 'true', 1),
    (3, 82, 'true', 1),    -- DEDICATED: true

    (3, 90, '200', 1),     -- STORAGE: 200 GB
    (3, 91, '730', 1),     -- RETENTION: 2 years
    (3, 92, 'HOURLY', 1);  -- BACKUP: Hourly

PRINT '  ✓ Configured Business plan (37 features)';

-- =============================================
-- FEATURES PER PLAN - ENTERPRISE
-- =============================================
PRINT 'Configuring Enterprise Plan features...';

INSERT INTO [crm].[FeaturesPerPlan] (suscriptionPlanId, subscriptionFeatureId, featureValue, enabled)
VALUES
    (4, 1, 'UNLIMITED', 1),
    (4, 2, 'UNLIMITED', 1),
    (4, 3, 'true', 1),
    (4, 4, 'true', 1),

    (4, 10, 'UNLIMITED', 1),
    (4, 11, 'true', 1),
    (4, 12, 'true', 1),
    (4, 13, 'UNLIMITED', 1),

    (4, 20, 'UNLIMITED', 1),
    (4, 21, 'true', 1),
    (4, 22, 'true', 1),

    (4, 30, 'UNLIMITED', 1),
    (4, 31, 'true', 1),
    (4, 32, 'true', 1),
    (4, 33, 'true', 1),
    (4, 34, 'true', 1),

    (4, 40, 'UNLIMITED', 1),
    (4, 41, 'true', 1),
    (4, 42, 'true', 1),

    (4, 50, 'UNLIMITED', 1),
    (4, 51, 'true', 1),
    (4, 52, 'true', 1),
    (4, 53, 'UNLIMITED', 1),

    (4, 60, 'true', 1),
    (4, 61, 'true', 1),
    (4, 62, 'true', 1),
    (4, 63, 'true', 1),

    (4, 70, 'UNLIMITED', 1),
    (4, 71, 'true', 1),
    (4, 72, 'true', 1),
    (4, 73, 'true', 1),

    (4, 80, 'DEDICATED', 1),
    (4, 81, 'true', 1),
    (4, 82, 'true', 1),

    (4, 90, 'UNLIMITED', 1),
    (4, 91, 'UNLIMITED', 1),
    (4, 92, 'REALTIME', 1);

PRINT '  ✓ Configured Enterprise plan (37 features)';

-- =============================================
-- PAYMENT SCHEDULES PER PLAN
-- =============================================
PRINT 'Inserting Payment Schedules...';

INSERT INTO [crm].[PaymentSchedulesPerPlan]
    (suscriptionPlanId, paymentScheduleTypeId, price, currencyId, enabled)
VALUES
    -- Starter
    (1, 1, 49.00, 1, 1),    -- Monthly USD
    (1, 4, 490.00, 1, 1),   -- Annual USD (2 months free)

    -- Professional
    (2, 1, 149.00, 1, 1),   -- Monthly USD
    (2, 4, 1490.00, 1, 1),  -- Annual USD

    -- Business
    (3, 1, 499.00, 1, 1),   -- Monthly USD
    (3, 4, 4990.00, 1, 1),  -- Annual USD

    -- Enterprise (Contact Sales)
    (4, 1, 2500.00, 1, 1),  -- Monthly USD (starting)
    (4, 4, 25000.00, 1, 1), -- Annual USD

    -- Trial (Free)
    (5, 1, 0.00, 1, 1);

PRINT '  ✓ Inserted 9 payment schedules';

PRINT '';
PRINT '========================================';
PRINT 'SUBSCRIPTION PLANS SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT 'Summary:';
PRINT '  - Plans: 5 (Starter, Pro, Business, Enterprise, Trial)';
PRINT '  - Features: 37';
PRINT '  - Features configured per plan: 148 (37 x 4 plans)';
PRINT '  - Payment schedules: 9';
PRINT '';

GO
