
USE [PromptCRM];
GO

PRINT N'============================================';
PRINT N'Starting catalog data seeding...';
PRINT N'============================================';
GO

-- =====================================================
-- STATUS CATALOGS
-- =====================================================

-- Generic Status Catalog
PRINT N'Seeding Status_catalog...';
MERGE INTO [crm].[Status_catalog] AS target
USING (VALUES
    (1, N'Active'),
    (2, N'Inactive'),
    (3, N'Pending'),
    (4, N'Suspended'),
    (5, N'Deleted'),
    (6, N'Approved'),
    (7, N'Rejected'),
    (8, N'In Review'),
    (9, N'Completed'),
    (10, N'Failed'),
    (11, N'Processing'),
    (12, N'Cancelled'),
    (13, N'Expired'),
    (14, N'Draft'),
    (15, N'Published'),
    (16, N'Archived'),
    (17, N'Locked'),
    (18, N'Enabled'),
    (19, N'Disabled'),
    (20, N'On Hold')
) AS source ([status_catalog_id], [status_name])
ON target.[status_catalog_id] = source.[status_catalog_id]
WHEN MATCHED THEN
    UPDATE SET [status_name] = source.[status_name]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([status_name]) VALUES (source.[status_name]);
GO

-- Payment Status Catalog
PRINT N'Seeding Payment_status_catalog...';
MERGE INTO [crm].[Payment_status_catalog] AS target
USING (VALUES
    (1, 'PENDING', N'Pending Payment', N'Payment is awaiting processing', 0, 1),
    (2, 'PROCESSING', N'Processing', N'Payment is being processed', 0, 2),
    (3, 'COMPLETED', N'Completed', N'Payment completed successfully', 1, 3),
    (4, 'FAILED', N'Failed', N'Payment failed', 1, 4),
    (5, 'CANCELLED', N'Cancelled', N'Payment was cancelled', 1, 5),
    (6, 'REFUNDED', N'Refunded', N'Payment was refunded', 1, 6),
    (7, 'PARTIALLY_REFUNDED', N'Partially Refunded', N'Payment was partially refunded', 0, 7),
    (8, 'CHARGEBACK', N'Chargeback', N'Payment chargeback initiated', 1, 8),
    (9, 'DISPUTED', N'Disputed', N'Payment is disputed', 0, 9),
    (10, 'AUTHORIZED', N'Authorized', N'Payment authorized but not captured', 0, 10)
) AS source ([payment_status_id], [status_code], [status_name], [status_description], [is_final_status], [display_order])
ON target.[payment_status_id] = source.[payment_status_id]
WHEN MATCHED THEN
    UPDATE SET
        [status_code] = source.[status_code],
        [status_name] = source.[status_name],
        [status_description] = source.[status_description],
        [is_final_status] = source.[is_final_status],
        [display_order] = source.[display_order]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([status_code], [status_name], [status_description], [is_final_status], [display_order])
    VALUES (source.[status_code], source.[status_name], source.[status_description], source.[is_final_status], source.[display_order]);
GO

-- Subscription Status Catalog
PRINT N'Seeding Subscription_status_catalog...';
MERGE INTO [crm].[Subscription_status_catalog] AS target
USING (VALUES
    (1, 'ACTIVE', N'Active', N'Subscription is active and has access', 1, 1),
    (2, 'TRIAL', N'Trial', N'Subscription in trial period', 1, 2),
    (3, 'PAST_DUE', N'Past Due', N'Payment is past due', 0, 3),
    (4, 'CANCELLED', N'Cancelled', N'Subscription cancelled', 0, 4),
    (5, 'SUSPENDED', N'Suspended', N'Subscription suspended', 0, 5),
    (6, 'EXPIRED', N'Expired', N'Subscription expired', 0, 6),
    (7, 'PENDING', N'Pending', N'Subscription pending activation', 0, 7),
    (8, 'PAUSED', N'Paused', N'Subscription paused temporarily', 0, 8)
) AS source ([subscription_status_id], [status_code], [status_name], [status_description], [allows_access], [display_order])
ON target.[subscription_status_id] = source.[subscription_status_id]
WHEN MATCHED THEN
    UPDATE SET
        [status_code] = source.[status_code],
        [status_name] = source.[status_name],
        [status_description] = source.[status_description],
        [allows_access] = source.[allows_access],
        [display_order] = source.[display_order]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([status_code], [status_name], [status_description], [allows_access], [display_order])
    VALUES (source.[status_code], source.[status_name], source.[status_description], source.[allows_access], source.[display_order]);
GO

-- Lead Status Catalog
PRINT N'Seeding Lead_status_catalog...';
MERGE INTO [crm].[Lead_status_catalog] AS target
USING (VALUES
    (1, 'NEW', N'New Lead', N'Lead just created', 1, 1, '#3498db'),
    (2, 'CONTACTED', N'Contacted', N'Lead has been contacted', 1, 2, '#9b59b6'),
    (3, 'QUALIFIED', N'Qualified', N'Lead is qualified', 1, 3, '#f39c12'),
    (4, 'PROPOSAL_SENT', N'Proposal Sent', N'Proposal sent to lead', 1, 4, '#e67e22'),
    (5, 'NEGOTIATION', N'In Negotiation', N'Negotiating with lead', 1, 5, '#d35400'),
    (6, 'CONVERTED', N'Converted', N'Lead converted to customer', 0, 6, '#27ae60'),
    (7, 'LOST', N'Lost', N'Lead was lost', 0, 7, '#e74c3c'),
    (8, 'DISQUALIFIED', N'Disqualified', N'Lead disqualified', 0, 8, '#95a5a6'),
    (9, 'NURTURING', N'Nurturing', N'Lead in nurturing process', 1, 9, '#16a085'),
    (10, 'FOLLOW_UP', N'Follow Up', N'Awaiting follow up', 1, 10, '#2980b9'),
    (11, 'UNRESPONSIVE', N'Unresponsive', N'Lead not responding', 1, 11, '#7f8c8d'),
    (12, 'RECYCLE', N'Recycled', N'Lead recycled for future contact', 1, 12, '#34495e')
) AS source ([lead_status_id], [status_code], [status_name], [status_description], [is_active_status], [display_order], [status_color])
ON target.[lead_status_id] = source.[lead_status_id]
WHEN MATCHED THEN
    UPDATE SET
        [status_code] = source.[status_code],
        [status_name] = source.[status_name],
        [status_description] = source.[status_description],
        [is_active_status] = source.[is_active_status],
        [display_order] = source.[display_order],
        [status_color] = source.[status_color]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([status_code], [status_name], [status_description], [is_active_status], [display_order], [status_color])
    VALUES (source.[status_code], source.[status_name], source.[status_description], source.[is_active_status], source.[display_order], source.[status_color]);
GO

-- User Status Catalog
PRINT N'Seeding User_status_catalog...';
MERGE INTO [crm].[User_status_catalog] AS target
USING (VALUES
    (1, 'ACTIVE', N'Active', N'User is active and can login', 1, 1),
    (2, 'INACTIVE', N'Inactive', N'User is inactive', 0, 2),
    (3, 'LOCKED', N'Locked', N'User account is locked', 0, 3),
    (4, 'PENDING_VERIFICATION', N'Pending Verification', N'User pending email verification', 0, 4),
    (5, 'SUSPENDED', N'Suspended', N'User account suspended', 0, 5),
    (6, 'DELETED', N'Deleted', N'User account deleted', 0, 6)
) AS source ([user_status_id], [status_code], [status_name], [status_description], [allows_login], [display_order])
ON target.[user_status_id] = source.[user_status_id]
WHEN MATCHED THEN
    UPDATE SET
        [status_code] = source.[status_code],
        [status_name] = source.[status_name],
        [status_description] = source.[status_description],
        [allows_login] = source.[allows_login],
        [display_order] = source.[display_order]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([status_code], [status_name], [status_description], [allows_login], [display_order])
    VALUES (source.[status_code], source.[status_name], source.[status_description], source.[allows_login], source.[display_order]);
GO

-- =====================================================
-- LOG CATALOGS
-- =====================================================

PRINT N'Seeding Log_types...';
MERGE INTO [crm].[Log_types] AS target
USING (VALUES
    (1, N'System'),
    (2, N'User Action'),
    (3, N'API Call'),
    (4, N'Database'),
    (5, N'Security'),
    (6, N'Payment'),
    (7, N'Integration'),
    (8, N'Email'),
    (9, N'Workflow'),
    (10, N'Error')
) AS source ([log_type_id], [log_type])
ON target.[log_type_id] = source.[log_type_id]
WHEN MATCHED THEN UPDATE SET [log_type] = source.[log_type]
WHEN NOT MATCHED BY TARGET THEN INSERT ([log_type]) VALUES (source.[log_type]);
GO

PRINT N'Seeding Log_levels...';
MERGE INTO [crm].[Log_levels] AS target
USING (VALUES
    (1, N'Debug'),
    (2, N'Info'),
    (3, N'Warning'),
    (4, N'Error'),
    (5, N'Critical'),
    (6, N'Trace')
) AS source ([log_level_id], [log_level])
ON target.[log_level_id] = source.[log_level_id]
WHEN MATCHED THEN UPDATE SET [log_level] = source.[log_level]
WHEN NOT MATCHED BY TARGET THEN INSERT ([log_level]) VALUES (source.[log_level]);
GO

PRINT N'Seeding log_sources...';
MERGE INTO [crm].[log_sources] AS target
USING (VALUES
    (1, N'Web Portal'),
    (2, N'Mobile App'),
    (3, N'API'),
    (4, N'Background Job'),
    (5, N'Database Trigger'),
    (6, N'MCP Server'),
    (7, N'Integration Service'),
    (8, N'Email Service')
) AS source ([log_source_id], [log_source])
ON target.[log_source_id] = source.[log_source_id]
WHEN MATCHED THEN UPDATE SET [log_source] = source.[log_source]
WHEN NOT MATCHED BY TARGET THEN INSERT ([log_source]) VALUES (source.[log_source]);
GO

-- =====================================================
-- GEOGRAPHY
-- =====================================================

PRINT N'Seeding Countries...';
SET IDENTITY_INSERT [crm].[Countries] ON;
MERGE INTO [crm].[Countries] AS target
USING (VALUES
    (1, N'United States', N'USA'),
    (2, N'Canada', N'CAN'),
    (3, N'Mexico', N'MEX'),
    (4, N'United Kingdom', N'GBR'),
    (5, N'Germany', N'DEU'),
    (6, N'France', N'FRA'),
    (7, N'Spain', N'ESP'),
    (8, N'Italy', N'ITA'),
    (9, N'Brazil', N'BRA'),
    (10, N'Argentina', N'ARG'),
    (11, N'Colombia', N'COL'),
    (12, N'Chile', N'CHL'),
    (13, N'Peru', N'PER'),
    (14, N'China', N'CHN'),
    (15, N'Japan', N'JPN'),
    (16, N'India', N'IND'),
    (17, N'Australia', N'AUS'),
    (18, N'Netherlands', N'NLD'),
    (19, N'Belgium', N'BEL'),
    (20, N'Switzerland', N'CHE')
) AS source ([country_id], [country_name], [country_code])
ON target.[country_id] = source.[country_id]
WHEN MATCHED THEN UPDATE SET [country_name] = source.[country_name], [country_code] = source.[country_code]
WHEN NOT MATCHED BY TARGET THEN INSERT ([country_id], [country_name], [country_code]) VALUES (source.[country_id], source.[country_name], source.[country_code]);
SET IDENTITY_INSERT [crm].[Countries] OFF;
GO

PRINT N'Seeding States...';
SET IDENTITY_INSERT [crm].[States] ON;
MERGE INTO [crm].[States] AS target
USING (VALUES
    -- USA States (top 15)
    (1, N'California', 1),
    (2, N'Texas', 1),
    (3, N'Florida', 1),
    (4, N'New York', 1),
    (5, N'Pennsylvania', 1),
    (6, N'Illinois', 1),
    (7, N'Ohio', 1),
    (8, N'Georgia', 1),
    (9, N'North Carolina', 1),
    (10, N'Michigan', 1),
    (11, N'New Jersey', 1),
    (12, N'Virginia', 1),
    (13, N'Washington', 1),
    (14, N'Arizona', 1),
    (15, N'Massachusetts', 1),
    -- Canada Provinces
    (16, N'Ontario', 2),
    (17, N'Quebec', 2),
    (18, N'British Columbia', 2),
    (19, N'Alberta', 2),
    -- Mexico States
    (20, N'Mexico City', 3),
    (21, N'Jalisco', 3),
    (22, N'Nuevo León', 3),
    -- UK
    (23, N'England', 4),
    (24, N'Scotland', 4),
    (25, N'Wales', 4)
) AS source ([state_id], [state_name], [country_id])
ON target.[state_id] = source.[state_id]
WHEN MATCHED THEN UPDATE SET [state_name] = source.[state_name], [country_id] = source.[country_id]
WHEN NOT MATCHED BY TARGET THEN INSERT ([state_id], [state_name], [country_id]) VALUES (source.[state_id], source.[state_name], source.[country_id]);
SET IDENTITY_INSERT [crm].[States] OFF;
GO

PRINT N'Seeding Cities...';
SET IDENTITY_INSERT [crm].[Cities] ON;
MERGE INTO [crm].[Cities] AS target
USING (VALUES
    -- California cities
    (1, N'Los Angeles', 1),
    (2, N'San Francisco', 1),
    (3, N'San Diego', 1),
    (4, N'San Jose', 1),
    -- Texas cities
    (5, N'Houston', 2),
    (6, N'Dallas', 2),
    (7, N'Austin', 2),
    (8, N'San Antonio', 2),
    -- Florida cities
    (9, N'Miami', 3),
    (10, N'Tampa', 3),
    (11, N'Orlando', 3),
    -- New York cities
    (12, N'New York City', 4),
    (13, N'Buffalo', 4),
    -- Illinois
    (14, N'Chicago', 6),
    -- Washington
    (15, N'Seattle', 13),
    -- Ontario
    (16, N'Toronto', 16),
    (17, N'Ottawa', 16),
    -- Quebec
    (18, N'Montreal', 17),
    -- Mexico
    (19, N'Mexico City', 20),
    (20, N'Guadalajara', 21)
) AS source ([city_id], [city_name], [state_id])
ON target.[city_id] = source.[city_id]
WHEN MATCHED THEN UPDATE SET [city_name] = source.[city_name], [state_id] = source.[state_id]
WHEN NOT MATCHED BY TARGET THEN INSERT ([city_id], [city_name], [state_id]) VALUES (source.[city_id], source.[city_name], source.[state_id]);
SET IDENTITY_INSERT [crm].[Cities] OFF;
GO

-- =====================================================
-- CURRENCIES
-- =====================================================

PRINT N'Seeding Currencies...';
SET IDENTITY_INSERT [crm].[Currencies] ON;
MERGE INTO [crm].[Currencies] AS target
USING (VALUES
    (1, N'US Dollar', N'USD', 1, GETDATE()),
    (2, N'Euro', N'EUR', 1, GETDATE()),
    (3, N'British Pound', N'GBP', 1, GETDATE()),
    (4, N'Canadian Dollar', N'CAD', 1, GETDATE()),
    (5, N'Mexican Peso', N'MXN', 1, GETDATE()),
    (6, N'Japanese Yen', N'JPY', 1, GETDATE()),
    (7, N'Chinese Yuan', N'CNY', 1, GETDATE()),
    (8, N'Brazilian Real', N'BRL', 1, GETDATE()),
    (9, N'Argentine Peso', N'ARS', 1, GETDATE()),
    (10, N'Colombian Peso', N'COP', 1, GETDATE())
) AS source ([currency_id], [currency_name], [currency_code], [enabled], [created_at])
ON target.[currency_id] = source.[currency_id]
WHEN MATCHED THEN UPDATE SET [currency_name] = source.[currency_name], [currency_code] = source.[currency_code], [enabled] = source.[enabled]
WHEN NOT MATCHED BY TARGET THEN INSERT ([currency_id], [currency_name], [currency_code], [enabled], [created_at]) VALUES (source.[currency_id], source.[currency_name], source.[currency_code], source.[enabled], source.[created_at]);
SET IDENTITY_INSERT [crm].[Currencies] OFF;
GO

-- =====================================================
-- PAYMENT & SUBSCRIPTION
-- =====================================================

PRINT N'Seeding Payment_schedule_types...';
SET IDENTITY_INSERT [crm].[Payment_schedule_types] ON;
MERGE INTO [crm].[Payment_schedule_types] AS target
USING (VALUES
    (1, N'Monthly', 30),
    (2, N'Quarterly', 90),
    (3, N'Semi-Annual', 180),
    (4, N'Annual', 365),
    (5, N'Weekly', 7),
    (6, N'Bi-Weekly', 14),
    (7, N'One-Time', NULL)
) AS source ([payment_schedule_type_id], [schedule_type_name], [billing_frequency_days])
ON target.[payment_schedule_type_id] = source.[payment_schedule_type_id]
WHEN MATCHED THEN UPDATE SET [schedule_type_name] = source.[schedule_type_name], [billing_frequency_days] = source.[billing_frequency_days]
WHEN NOT MATCHED BY TARGET THEN INSERT ([payment_schedule_type_id], [schedule_type_name], [billing_frequency_days]) VALUES (source.[payment_schedule_type_id], source.[schedule_type_name], source.[billing_frequency_days]);
SET IDENTITY_INSERT [crm].[Payment_schedule_types] OFF;
GO

PRINT N'Seeding Payment_method_types...';
SET IDENTITY_INSERT [crm].[Payment_method_types] ON;
MERGE INTO [crm].[Payment_method_types] AS target
USING (VALUES
    (1, N'Credit Card'),
    (2, N'Debit Card'),
    (3, N'PayPal'),
    (4, N'Bank Transfer'),
    (5, N'Stripe'),
    (6, N'Apple Pay'),
    (7, N'Google Pay'),
    (8, N'Crypto'),
    (9, N'Check'),
    (10, N'Wire Transfer')
) AS source ([payment_method_type_id], [method_type_name])
ON target.[payment_method_type_id] = source.[payment_method_type_id]
WHEN MATCHED THEN UPDATE SET [method_type_name] = source.[method_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([payment_method_type_id], [method_type_name]) VALUES (source.[payment_method_type_id], source.[method_type_name]);
SET IDENTITY_INSERT [crm].[Payment_method_types] OFF;
GO

PRINT N'Seeding Transaction_types...';
SET IDENTITY_INSERT [crm].[Transaction_types] ON;
MERGE INTO [crm].[Transaction_types] AS target
USING (VALUES
    (1, N'Subscription Payment'),
    (2, N'Refund'),
    (3, N'Chargeback'),
    (4, N'Credit'),
    (5, N'Adjustment'),
    (6, N'Fee'),
    (7, N'Setup Fee'),
    (8, N'Trial Conversion'),
    (9, N'Upgrade'),
    (10, N'Downgrade')
) AS source ([transaction_type_id], [transaction_type_name])
ON target.[transaction_type_id] = source.[transaction_type_id]
WHEN MATCHED THEN UPDATE SET [transaction_type_name] = source.[transaction_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([transaction_type_id], [transaction_type_name]) VALUES (source.[transaction_type_id], source.[transaction_type_name]);
SET IDENTITY_INSERT [crm].[Transaction_types] OFF;
GO

-- =====================================================
-- SUBSCRIPTION FEATURES
-- =====================================================

PRINT N'Seeding Subscription_feature_types...';
SET IDENTITY_INSERT [crm].[Subscription_feature_types] ON;
MERGE INTO [crm].[Subscription_feature_types] AS target
USING (VALUES
    (1, N'Boolean'),
    (2, N'Number'),
    (3, N'Text'),
    (4, N'Limit'),
    (5, N'Quota')
) AS source ([subscription_feature_type_id], [feature_type_name])
ON target.[subscription_feature_type_id] = source.[subscription_feature_type_id]
WHEN MATCHED THEN UPDATE SET [feature_type_name] = source.[feature_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([subscription_feature_type_id], [feature_type_name]) VALUES (source.[subscription_feature_type_id], source.[feature_type_name]);
SET IDENTITY_INSERT [crm].[Subscription_feature_types] OFF;
GO

-- =====================================================
-- MARKETING
-- =====================================================

PRINT N'Seeding Marketing_channel_types...';
SET IDENTITY_INSERT [crm].[Marketing_channel_types] ON;
MERGE INTO [crm].[Marketing_channel_types] AS target
USING (VALUES
    (1, N'Social Media'),
    (2, N'Email'),
    (3, N'Search Engine'),
    (4, N'Display Advertising'),
    (5, N'Referral'),
    (6, N'Direct'),
    (7, N'Organic'),
    (8, N'Paid Search'),
    (9, N'Influencer'),
    (10, N'Content Marketing')
) AS source ([channel_type_id], [channel_type_name])
ON target.[channel_type_id] = source.[channel_type_id]
WHEN MATCHED THEN UPDATE SET [channel_type_name] = source.[channel_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([channel_type_id], [channel_type_name]) VALUES (source.[channel_type_id], source.[channel_type_name]);
SET IDENTITY_INSERT [crm].[Marketing_channel_types] OFF;
GO

-- =====================================================
-- LEAD EVENTS
-- =====================================================

PRINT N'Seeding Lead_event_types...';
SET IDENTITY_INSERT [crm].[Lead_event_types] ON;
MERGE INTO [crm].[Lead_event_types] AS target
USING (VALUES
    (1, N'View'),
    (2, N'Click'),
    (3, N'Impression'),
    (4, N'Conversion'),
    (5, N'Form Submit'),
    (6, N'Download'),
    (7, N'Video Watch'),
    (8, N'Email Open'),
    (9, N'Email Click'),
    (10, N'Call'),
    (11, N'Chat'),
    (12, N'Purchase')
) AS source ([event_type_id], [event_type_name])
ON target.[event_type_id] = source.[event_type_id]
WHEN MATCHED THEN UPDATE SET [event_type_name] = source.[event_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([event_type_id], [event_type_name]) VALUES (source.[event_type_id], source.[event_type_name]);
SET IDENTITY_INSERT [crm].[Lead_event_types] OFF;
GO

-- =====================================================
-- FUNNEL
-- =====================================================

PRINT N'Seeding Sales_funnel_types...';
SET IDENTITY_INSERT [crm].[Sales_funnel_types] ON;
MERGE INTO [crm].[Sales_funnel_types] AS target
USING (VALUES
    (1, N'B2B Sales', N'Business to business sales funnel'),
    (2, N'B2C Sales', N'Business to consumer sales funnel'),
    (3, N'Lead Nurturing', N'Long-term lead nurturing funnel'),
    (4, N'Product Launch', N'New product launch funnel'),
    (5, N'Webinar', N'Webinar registration and conversion funnel'),
    (6, N'Trial Conversion', N'Free trial to paid conversion funnel'),
    (7, N'Upsell', N'Customer upsell funnel'),
    (8, N'Reactivation', N'Dormant lead reactivation funnel')
) AS source ([funnel_type_id], [funnel_type_name], [funnel_type_description])
ON target.[funnel_type_id] = source.[funnel_type_id]
WHEN MATCHED THEN UPDATE SET [funnel_type_name] = source.[funnel_type_name], [funnel_type_description] = source.[funnel_type_description]
WHEN NOT MATCHED BY TARGET THEN INSERT ([funnel_type_id], [funnel_type_name], [funnel_type_description]) VALUES (source.[funnel_type_id], source.[funnel_type_name], source.[funnel_type_description]);
SET IDENTITY_INSERT [crm].[Sales_funnel_types] OFF;
GO

-- =====================================================
-- LEAD NURTURING
-- =====================================================

PRINT N'Seeding Lead_nurturing_action_types...';
SET IDENTITY_INSERT [crm].[Lead_nurturing_action_types] ON;
MERGE INTO [crm].[Lead_nurturing_action_types] AS target
USING (VALUES
    (1, N'Email'),
    (2, N'Phone Call'),
    (3, N'SMS'),
    (4, N'LinkedIn Message'),
    (5, N'Direct Mail'),
    (6, N'Meeting'),
    (7, N'Demo'),
    (8, N'Proposal'),
    (9, N'Follow-up'),
    (10, N'Retargeting Ad')
) AS source ([action_type_id], [action_type_name])
ON target.[action_type_id] = source.[action_type_id]
WHEN MATCHED THEN UPDATE SET [action_type_name] = source.[action_type_name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([action_type_id], [action_type_name]) VALUES (source.[action_type_id], source.[action_type_name]);
SET IDENTITY_INSERT [crm].[Lead_nurturing_action_types] OFF;
GO

-- =====================================================
-- SUMMARY
-- =====================================================

PRINT N'';
PRINT N'============================================';
PRINT N'Catalog seeding completed successfully!';
PRINT N'============================================';
PRINT N'';
PRINT N'Summary of seeded catalogs:';
SELECT 'Status_catalog' AS [Catalog], COUNT(*) AS [Records] FROM [crm].[Status_catalog]
UNION ALL SELECT 'Payment_status_catalog', COUNT(*) FROM [crm].[Payment_status_catalog]
UNION ALL SELECT 'Subscription_status_catalog', COUNT(*) FROM [crm].[Subscription_status_catalog]
UNION ALL SELECT 'Lead_status_catalog', COUNT(*) FROM [crm].[Lead_status_catalog]
UNION ALL SELECT 'User_status_catalog', COUNT(*) FROM [crm].[User_status_catalog]
UNION ALL SELECT 'Log_types', COUNT(*) FROM [crm].[Log_types]
UNION ALL SELECT 'Log_levels', COUNT(*) FROM [crm].[Log_levels]
UNION ALL SELECT 'log_sources', COUNT(*) FROM [crm].[log_sources]
UNION ALL SELECT 'Countries', COUNT(*) FROM [crm].[Countries]
UNION ALL SELECT 'States', COUNT(*) FROM [crm].[States]
UNION ALL SELECT 'Cities', COUNT(*) FROM [crm].[Cities]
UNION ALL SELECT 'Currencies', COUNT(*) FROM [crm].[Currencies]
UNION ALL SELECT 'Payment_schedule_types', COUNT(*) FROM [crm].[Payment_schedule_types]
UNION ALL SELECT 'Payment_method_types', COUNT(*) FROM [crm].[Payment_method_types]
UNION ALL SELECT 'Transaction_types', COUNT(*) FROM [crm].[Transaction_types]
UNION ALL SELECT 'Subscription_feature_types', COUNT(*) FROM [crm].[Subscription_feature_types]
UNION ALL SELECT 'Marketing_channel_types', COUNT(*) FROM [crm].[Marketing_channel_types]
UNION ALL SELECT 'Lead_event_types', COUNT(*) FROM [crm].[Lead_event_types]
UNION ALL SELECT 'Sales_funnel_types', COUNT(*) FROM [crm].[Sales_funnel_types]
UNION ALL SELECT 'Lead_nurturing_action_types', COUNT(*) FROM [crm].[Lead_nurturing_action_types]
ORDER BY [Catalog];
GO
