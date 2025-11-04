
USE [PromptCRM];
GO

SET NOCOUNT ON;
GO

PRINT N'============================================';
PRINT N'Starting 500K Leads Generation Process';
PRINT N'This may take 5-10 minutes...';
PRINT N'============================================';
PRINT N'Start Time: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT N'';
GO

-- =====================================================
-- STEP 1: CREATE BASE DATA
-- =====================================================

PRINT N'STEP 1: Creating base data (Users, Subscribers, Marketing Channels)...';
GO

-- Create system user first (needed for created_by references)
IF NOT EXISTS (SELECT 1 FROM [crm].[Users] WHERE [email] = 'system@promptsales.com')
BEGIN
    SET IDENTITY_INSERT [crm].[Users] ON;
    INSERT INTO [crm].[Users] ([user_id], [first_name], [last_name], [email], [created_at], [status_catalog_id])
    VALUES (1, N'System', N'User', 'system@promptsales.com', GETDATE(), 1);
    SET IDENTITY_INSERT [crm].[Users] OFF;
    PRINT N'  - Created system user';
END
GO

-- Create sample users (sales team)
DECLARE @i INT = 2;
WHILE @i <= 50 AND NOT EXISTS (SELECT 1 FROM [crm].[Users] WHERE [user_id] = @i)
BEGIN
    INSERT INTO [crm].[Users] ([first_name], [last_name], [email], [created_at], [status_catalog_id], [created_by])
    VALUES (
        CONCAT(N'User', @i),
        CONCAT(N'Sales', @i),
        CONCAT('user', @i, '@promptsales.com'),
        DATEADD(DAY, -RAND(CHECKSUM(NEWID())) * 365, GETDATE()),
        1, -- Active
        1  -- Created by system
    );
    SET @i = @i + 1;
END
PRINT N'  - Created ' + CAST(@i - 2 AS VARCHAR) + ' user accounts';
GO

-- Create sample subscribers (companies using PromptSales)
DECLARE @sub_id INT = 1;
DECLARE @sub_names TABLE (name NVARCHAR(80));
INSERT INTO @sub_names VALUES
    (N'TechCorp Solutions'), (N'Digital Marketing Inc'), (N'E-Commerce Plus'),
    (N'SaaS Innovations'), (N'Retail Giants'), (N'Finance Advisors'),
    (N'Healthcare Systems'), (N'Education Platform'), (N'Travel Experts'),
    (N'Real Estate Pros'), (N'Manufacturing Co'), (N'Logistics Hub'),
    (N'Media Networks'), (N'Gaming Studios'), (N'Food Delivery'),
    (N'Fashion Brands'), (N'Auto Dealers'), (N'Energy Solutions'),
    (N'Construction LLC'), (N'Legal Services'), (N'Consulting Group'),
    (N'Insurance Partners'), (N'Telecom Systems'), (N'Cloud Services'),
    (N'Security Solutions');

MERGE INTO [crm].[Subscribers] AS target
USING @sub_names AS source
ON 1 = 0 -- Always insert
WHEN NOT MATCHED THEN
    INSERT ([legal_name], [comercial_name], [website_url], [created_at], [status_catalog_id], [created_by])
    VALUES (
        source.name,
        source.name,
        CONCAT('https://', LOWER(REPLACE(source.name, ' ', '')), '.com'),
        DATEADD(DAY, -RAND(CHECKSUM(NEWID())) * 730, GETDATE()), -- Up to 2 years ago
        1, -- Active
        1
    );

DECLARE @subscriber_count INT = (SELECT COUNT(*) FROM [crm].[Subscribers]);
PRINT N'  - Created/verified ' + CAST(@subscriber_count AS VARCHAR) + ' subscribers';
GO

-- Create Marketing Channels
DECLARE @channel_names TABLE (name NVARCHAR(80), type_id INT);
INSERT INTO @channel_names VALUES
    (N'Facebook Ads', 1), (N'Instagram Ads', 1), (N'LinkedIn Ads', 1), (N'Twitter Ads', 1), (N'TikTok Ads', 1),
    (N'Email Newsletter', 2), (N'Email Campaign', 2), (N'Drip Email', 2),
    (N'Google Search', 3), (N'Bing Search', 3),
    (N'Google Display', 4), (N'Banner Ads', 4),
    (N'Referral Program', 5), (N'Affiliate', 5),
    (N'Direct Traffic', 6), (N'Organic Social', 7),
    (N'Google Ads', 8), (N'YouTube Ads', 8),
    (N'Influencer Partnership', 9), (N'Blog Content', 10);

MERGE INTO [crm].[Marketing_channels] AS target
USING @channel_names AS source
ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT ([channel_name], [channel_type_id], [enabled], [created_at], [status_catalog_id], [created_by])
    VALUES (source.name, source.type_id, 1, GETDATE(), 1, 1);

DECLARE @channel_count INT = (SELECT COUNT(*) FROM [crm].[Marketing_channels]);
PRINT N'  - Created/verified ' + CAST(@channel_count AS VARCHAR) + ' marketing channels';
PRINT N'';
GO

-- =====================================================
-- STEP 2: GENERATE 500,000 LEADS
-- =====================================================

PRINT N'STEP 2: Generating 500,000 leads in batches...';
PRINT N'  This will take several minutes. Progress will be shown every 50,000 records.';
PRINT N'';
GO

-- Create Numbers table for cross-join generation
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;
CREATE TABLE #Numbers (n INT PRIMARY KEY);

-- Insert numbers 1-10000 (we'll use this for cross joins)
;WITH
L0 AS (SELECT 1 AS c UNION ALL SELECT 1),
L1 AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
L2 AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
L3 AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
L4 AS (SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B),
Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM L4)
INSERT INTO #Numbers (n)
SELECT n FROM Nums WHERE n <= 10000;

PRINT N'  - Numbers table created (10,000 rows)';
GO

-- Get base data IDs for foreign keys
DECLARE @subscriber_ids TABLE (subscriber_id INT);
INSERT INTO @subscriber_ids SELECT [subscriber_id] FROM [crm].[Subscribers];
DECLARE @subscriber_count INT = (SELECT COUNT(*) FROM @subscriber_ids);

DECLARE @channel_ids TABLE (marketing_channel_id INT);
INSERT INTO @channel_ids SELECT [marketing_channel_id] FROM [crm].[Marketing_channels];
DECLARE @channel_count INT = (SELECT COUNT(*) FROM @channel_ids);

DECLARE @country_ids TABLE (country_id INT);
INSERT INTO @country_ids SELECT [country_id] FROM [crm].[Countries];
DECLARE @country_count INT = (SELECT COUNT(*) FROM @country_ids);

DECLARE @lead_status_ids TABLE (lead_status_id INT);
INSERT INTO @lead_status_ids SELECT [lead_status_id] FROM [crm].[Lead_status_catalog] WHERE [is_active_status] = 1;
DECLARE @status_count INT = (SELECT COUNT(*) FROM @lead_status_ids);

-- Batch configuration
DECLARE @batch_size INT = 10000;
DECLARE @total_leads INT = 500000;
DECLARE @batches INT = @total_leads / @batch_size;
DECLARE @current_batch INT = 1;
DECLARE @start_time DATETIME = GETDATE();

-- Generate leads in batches
WHILE @current_batch <= @batches
BEGIN
    DECLARE @batch_start_time DATETIME = GETDATE();

    -- Generate batch of leads
    INSERT INTO [crm].[Leads] WITH (TABLOCK) (
        [subscriber_id],
        [lead_token],
        [utm_source],
        [utm_medium],
        [utm_campaign],
        [utm_term],
        [utm_content],
        [ad_id],
        [external_campaign_id],
        [first_name],
        [last_name],
        [email],
        [phone_number],
        [device_type],
        [browser_type],
        [operating_system],
        [ip_address],
        [country_id],
        [created_at],
        [status_catalog_id],
        [marketing_channel_id],
        [lead_score],
        [referrer_url],
        [landing_page_url]
    )
    SELECT
        -- Random subscriber
        (SELECT TOP 1 subscriber_id FROM @subscriber_ids ORDER BY NEWID()),

        -- Lead token (anonymous ID like 289A2-2828Y-5830F)
        CONCAT(
            RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR), 5), '-',
            RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR), 5), '-',
            RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS VARCHAR), 5)
        ),

        -- UTM parameters
        CASE ABS(CHECKSUM(NEWID())) % 10
            WHEN 0 THEN 'facebook'
            WHEN 1 THEN 'google'
            WHEN 2 THEN 'linkedin'
            WHEN 3 THEN 'instagram'
            WHEN 4 THEN 'email'
            WHEN 5 THEN 'twitter'
            WHEN 6 THEN 'tiktok'
            WHEN 7 THEN 'referral'
            WHEN 8 THEN 'direct'
            ELSE 'organic'
        END,

        CASE ABS(CHECKSUM(NEWID())) % 5
            WHEN 0 THEN 'cpc'
            WHEN 1 THEN 'social'
            WHEN 2 THEN 'email'
            WHEN 3 THEN 'organic'
            ELSE 'referral'
        END,

        CONCAT('campaign_', ABS(CHECKSUM(NEWID())) % 1000),

        -- utm_term (keywords)
        CASE ABS(CHECKSUM(NEWID())) % 8
            WHEN 0 THEN 'crm software'
            WHEN 1 THEN 'marketing automation'
            WHEN 2 THEN 'sales leads'
            WHEN 3 THEN 'lead generation'
            WHEN 4 THEN 'customer management'
            WHEN 5 THEN 'ai marketing'
            WHEN 6 THEN 'sales funnel'
            ELSE NULL
        END,

        -- utm_content
        CONCAT('ad_variant_', CHAR(65 + ABS(CHECKSUM(NEWID())) % 26)),

        -- ad_id
        CONCAT('ad_', ABS(CHECKSUM(NEWID())) % 10000),

        -- external_campaign_id
        CONCAT('ext_camp_', ABS(CHECKSUM(NEWID())) % 5000),

        -- Personal data (only 30% have this - simulating authorized data collection)
        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 30
            THEN CONCAT('FirstName', (@current_batch - 1) * @batch_size + n)
            ELSE NULL
        END,

        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 30
            THEN CONCAT('LastName', (@current_batch - 1) * @batch_size + n)
            ELSE NULL
        END,

        -- Email with unique combination: batch + n + random suffix to avoid duplicates
        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 30
            THEN CONCAT('lead', (@current_batch - 1) * @batch_size + n, '_', ABS(CHECKSUM(NEWID())) % 1000, '@example.com')
            ELSE NULL
        END,

        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 20
            THEN CONCAT('+1-555-', RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS VARCHAR), 4))
            ELSE NULL
        END,

        -- Device info
        CASE ABS(CHECKSUM(NEWID())) % 4
            WHEN 0 THEN 'Desktop'
            WHEN 1 THEN 'Mobile'
            WHEN 2 THEN 'Tablet'
            ELSE 'Other'
        END,

        CASE ABS(CHECKSUM(NEWID())) % 5
            WHEN 0 THEN 'Chrome'
            WHEN 1 THEN 'Safari'
            WHEN 2 THEN 'Firefox'
            WHEN 3 THEN 'Edge'
            ELSE 'Other'
        END,

        CASE ABS(CHECKSUM(NEWID())) % 6
            WHEN 0 THEN 'Windows'
            WHEN 1 THEN 'MacOS'
            WHEN 2 THEN 'iOS'
            WHEN 3 THEN 'Android'
            WHEN 4 THEN 'Linux'
            ELSE 'Other'
        END,

        -- Random IP address
        CONCAT(
            ABS(CHECKSUM(NEWID())) % 256, '.',
            ABS(CHECKSUM(NEWID())) % 256, '.',
            ABS(CHECKSUM(NEWID())) % 256, '.',
            ABS(CHECKSUM(NEWID())) % 256
        ),

        -- Random country
        (SELECT TOP 1 country_id FROM @country_ids ORDER BY NEWID()),

        -- Created date (last 2 years)
        DATEADD(SECOND, -ABS(CHECKSUM(NEWID())) % (730 * 24 * 3600), GETDATE()),

        -- Random active status
        (SELECT TOP 1 lead_status_id FROM @lead_status_ids ORDER BY NEWID()),

        -- Random marketing channel
        (SELECT TOP 1 marketing_channel_id FROM @channel_ids ORDER BY NEWID()),

        -- Lead score (0-100)
        ABS(CHECKSUM(NEWID())) % 101,

        -- Referrer URL
        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 40
            THEN CONCAT('https://www.google.com/search?q=', CAST(ABS(CHECKSUM(NEWID())) % 1000 AS VARCHAR))
            ELSE NULL
        END,

        -- Landing page URL
        CONCAT('https://promptsales.com/landing/', ABS(CHECKSUM(NEWID())) % 50)

    FROM #Numbers
    WHERE n <= @batch_size;

    DECLARE @batch_duration INT = DATEDIFF(SECOND, @batch_start_time, GETDATE());
    DECLARE @total_duration INT = DATEDIFF(SECOND, @start_time, GETDATE());
    DECLARE @leads_inserted INT = @current_batch * @batch_size;

    -- Progress report every 50k
    IF @current_batch % 5 = 0
    BEGIN
        PRINT N'  - Inserted ' + CAST(@leads_inserted AS VARCHAR) + ' / ' + CAST(@total_leads AS VARCHAR)
            + ' leads (' + CAST((@leads_inserted * 100 / @total_leads) AS VARCHAR) + '%) - '
            + 'Last batch: ' + CAST(@batch_duration AS VARCHAR) + 's - '
            + 'Total time: ' + CAST(@total_duration AS VARCHAR) + 's';
    END

    SET @current_batch = @current_batch + 1;
END

DECLARE @final_lead_count INT = (SELECT COUNT(*) FROM [crm].[Leads]);
DECLARE @total_time INT = DATEDIFF(SECOND, @start_time, GETDATE());

PRINT N'';
PRINT N'  ✓ Successfully generated ' + CAST(@final_lead_count AS VARCHAR) + ' leads';
PRINT N'  ✓ Total time: ' + CAST(@total_time / 60 AS VARCHAR) + ' minutes ' + CAST(@total_time % 60 AS VARCHAR) + ' seconds';
PRINT N'';
GO

-- =====================================================
-- STEP 3: GENERATE LEAD EVENTS
-- =====================================================

PRINT N'STEP 3: Generating lead events (~2M events)...';
GO

DECLARE @event_start DATETIME = GETDATE();

-- Generate 2-5 events per lead (average ~3)
-- We'll generate for a sample of leads to keep this reasonable
INSERT INTO [crm].[Lead_events] WITH (TABLOCK) (
    [lead_id],
    [event_type_id],
    [conversion_amount],
    [currency_id],
    [occurred_at]
)
SELECT TOP 2000000
    l.[lead_id],
    -- Random event type
    CASE ABS(CHECKSUM(NEWID())) % 12
        WHEN 0 THEN 1  -- View
        WHEN 1 THEN 2  -- Click
        WHEN 2 THEN 3  -- Impression
        WHEN 3 THEN 4  -- Conversion
        WHEN 4 THEN 5  -- Form Submit
        WHEN 5 THEN 6  -- Download
        WHEN 6 THEN 7  -- Video Watch
        WHEN 7 THEN 8  -- Email Open
        WHEN 8 THEN 9  -- Email Click
        WHEN 9 THEN 10 -- Call
        WHEN 10 THEN 11 -- Chat
        ELSE 12 -- Purchase
    END,
    -- Conversion amount (only for conversion/purchase events)
    CASE WHEN ABS(CHECKSUM(NEWID())) % 12 IN (3, 11) -- Conversion or Purchase
        THEN CAST(50 + (ABS(CHECKSUM(NEWID())) % 5000) AS DECIMAL(12,2))
        ELSE NULL
    END,
    -- Currency (USD most common)
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 8 THEN 1 ELSE ABS(CHECKSUM(NEWID())) % 10 + 1 END,
    -- Occurred at (after lead creation)
    DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % (24 * 30), l.[created_at])
FROM [crm].[Leads] l
CROSS JOIN (SELECT TOP 4 1 AS n FROM #Numbers) AS multiplier -- Generate ~4 events per lead
WHERE ABS(CHECKSUM(l.[lead_id])) % 100 < 100; -- All leads get events

DECLARE @event_count INT = (SELECT COUNT(*) FROM [crm].[Lead_events]);
DECLARE @event_time INT = DATEDIFF(SECOND, @event_start, GETDATE());

PRINT N'  ✓ Generated ' + CAST(@event_count AS VARCHAR) + ' lead events';
PRINT N'  ✓ Time: ' + CAST(@event_time AS VARCHAR) + ' seconds';
PRINT N'';
GO

-- =====================================================
-- STEP 4: CONVERT ~10% TO CUSTOMERS
-- =====================================================

PRINT N'STEP 4: Converting ~10% of leads to customers (~50K customers)...';
GO

DECLARE @customer_start DATETIME = GETDATE();

-- Convert high-scoring leads to customers
-- Use DISTINCT to prevent duplicate lead_id
INSERT INTO [crm].[Customers] WITH (TABLOCK) (
    [lead_id],
    [subscriber_id],
    [customer_since],
    [total_conversions],
    [total_conversion_value],
    [last_conversion_date],
    [created_at],
    [status_catalog_id],
    [created_by],
    [lifetime_value],
    [average_order_value],
    [churn_risk_score]
)
SELECT DISTINCT TOP 50000
    l.[lead_id],
    l.[subscriber_id],
    -- Customer since (some time after lead creation)
    DATEADD(DAY, ABS(CHECKSUM(l.[lead_id])) % 90, l.[created_at]),
    -- Total conversions (1-10)
    1 + ABS(CHECKSUM(l.[lead_id])) % 10,
    -- Total conversion value
    CAST(100 + (ABS(CHECKSUM(l.[lead_id])) % 50000) AS DECIMAL(12,2)),
    -- Last conversion date
    DATEADD(DAY, -ABS(CHECKSUM(l.[lead_id])) % 30, GETDATE()),
    GETDATE(),
    1, -- Active
    1, -- System user
    -- Lifetime value
    CAST(500 + (ABS(CHECKSUM(l.[lead_id] * 2)) % 100000) AS DECIMAL(12,2)),
    -- Average order value
    CAST(50 + (ABS(CHECKSUM(l.[lead_id] * 3)) % 5000) AS DECIMAL(12,2)),
    -- Churn risk score (0-100, most are low risk)
    CASE WHEN ABS(CHECKSUM(l.[lead_id] * 4)) % 100 < 80
        THEN ABS(CHECKSUM(l.[lead_id] * 5)) % 30  -- Low risk (0-29)
        ELSE 30 + ABS(CHECKSUM(l.[lead_id] * 6)) % 71  -- Higher risk (30-100)
    END
FROM [crm].[Leads] l
WHERE l.[lead_score] >= 60  -- Only convert high-scoring leads
    AND EXISTS (
        SELECT 1 FROM [crm].[Lead_events] le
        WHERE le.[lead_id] = l.[lead_id]
            AND le.[event_type_id] IN (4, 12) -- Conversion or Purchase events
    )
    AND NOT EXISTS (
        SELECT 1 FROM [crm].[Customers] c
        WHERE c.[lead_id] = l.[lead_id]
    )
ORDER BY l.[lead_id];

-- Update converted leads
UPDATE l
SET [converted_to_customer_at] = c.[customer_since],
    [status_catalog_id] = 6  -- Converted status
FROM [crm].[Leads] l
INNER JOIN [crm].[Customers] c ON l.[lead_id] = c.[lead_id];

DECLARE @customer_count INT = (SELECT COUNT(*) FROM [crm].[Customers]);
DECLARE @customer_time INT = DATEDIFF(SECOND, @customer_start, GETDATE());

PRINT N'  ✓ Created ' + CAST(@customer_count AS VARCHAR) + ' customers';
PRINT N'  ✓ Time: ' + CAST(@customer_time AS VARCHAR) + ' seconds';
PRINT N'';
GO

-- =====================================================
-- CLEANUP
-- =====================================================

DROP TABLE #Numbers;
GO

-- =====================================================
-- FINAL SUMMARY
-- =====================================================

PRINT N'============================================';
PRINT N'500K Leads Generation COMPLETED!';
PRINT N'============================================';
PRINT N'End Time: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT N'';
PRINT N'Summary:';
SELECT [Entity], [Count]
FROM (
    SELECT 'Subscribers' AS [Entity], COUNT(*) AS [Count], 1 AS [SortOrder] FROM [crm].[Subscribers]
    UNION ALL SELECT 'Users', COUNT(*), 2 FROM [crm].[Users]
    UNION ALL SELECT 'Marketing Channels', COUNT(*), 3 FROM [crm].[Marketing_channels]
    UNION ALL SELECT 'Leads', COUNT(*), 4 FROM [crm].[Leads]
    UNION ALL SELECT 'Lead Events', COUNT(*), 5 FROM [crm].[Lead_events]
    UNION ALL SELECT 'Customers', COUNT(*), 6 FROM [crm].[Customers]
) AS Summary
ORDER BY [SortOrder];
PRINT N'';

-- Lead distribution by status
PRINT N'Lead Distribution by Status:';
SELECT
    lsc.[status_name],
    COUNT(*) AS [Lead Count],
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM [crm].[Leads]) AS DECIMAL(5,2)) AS [Percentage]
FROM [crm].[Leads] l
INNER JOIN [crm].[Lead_status_catalog] lsc ON l.[status_catalog_id] = lsc.[lead_status_id]
GROUP BY lsc.[status_name]
ORDER BY COUNT(*) DESC;
PRINT N'';

PRINT N'============================================';
PRINT N'NEXT STEPS:';
PRINT N'1. Run queries to analyze the data';
PRINT N'2. Create indexed views for performance';
PRINT N'3. Test concurrent access scenarios';
PRINT N'============================================';
GO

SET NOCOUNT OFF;
GO
