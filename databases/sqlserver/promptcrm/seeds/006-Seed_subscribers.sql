-- =============================================
-- PromptCRM - Seed Data: Subscribers (Tenants)
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Create sample subscribers with users, subscriptions, and roles
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT '========================================';
PRINT 'SEEDING SUBSCRIBERS (TENANTS)';
PRINT '========================================';
PRINT '';

-- Ensure no IDENTITY_INSERT is active from previous scripts
-- SQL Server allows only ONE table to have IDENTITY_INSERT ON at a time
-- Turn off IDENTITY_INSERT on common tables from previous seeds
BEGIN TRY
    SET IDENTITY_INSERT [crm].[Countries] OFF;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    SET IDENTITY_INSERT [crm].[States] OFF;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    SET IDENTITY_INSERT [crm].[Cities] OFF;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    SET IDENTITY_INSERT [crm].[Addresses] OFF;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    SET IDENTITY_INSERT [crm].[SubscriptionPlans] OFF;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    SET IDENTITY_INSERT [crm].[SubscriptionFeatures] OFF;
END TRY BEGIN CATCH END CATCH;

-- =============================================
-- SUBSCRIBERS
-- =============================================
PRINT 'Inserting Subscribers (NO ENCRYPTION - temporary for testing)...';

SET IDENTITY_INSERT [crm].[Subscribers] ON;

INSERT INTO [crm].[Subscribers]
    (subscriberId, legalName, comercialName, legalId, taxId, websiteUrl, status, metadata)
VALUES
    (1, 'TechVision Solutions LLC', 'TechVision', CAST('45-2938475' AS VARBINARY(255)), CAST('45-2938475' AS VARBINARY(255)),
     'https://techvision-solutions.com', 'ACTIVE', '{"industry":"Technology","employees":50,"founded":"2019"}'),
    (2, 'GreenLeaf Organics Inc', 'GreenLeaf', CAST('47-3928471' AS VARBINARY(255)), CAST('47-3928471' AS VARBINARY(255)),
     'https://greenleaf-organics.com', 'ACTIVE', '{"industry":"Food & Beverage","employees":120,"founded":"2015"}'),
    (3, 'Stellar Marketing Group', 'Stellar Marketing', CAST('52-8374658' AS VARBINARY(255)), CAST('52-8374658' AS VARBINARY(255)),
     'https://stellarmarketing.io', 'ACTIVE', '{"industry":"Marketing","employees":35,"founded":"2020"}'),
    (4, 'FinanceFlow Corporation', 'FinanceFlow', CAST('61-9284756' AS VARBINARY(255)), CAST('61-9284756' AS VARBINARY(255)),
     'https://financeflow.com', 'ACTIVE', '{"industry":"Financial Services","employees":200,"founded":"2012"}'),
    (5, 'HealthFirst Medical Systems', 'HealthFirst', CAST('73-4857293' AS VARBINARY(255)), CAST('73-4857293' AS VARBINARY(255)),
     'https://healthfirst-med.com', 'ACTIVE', '{"industry":"Healthcare","employees":500,"founded":"2008"}'),
    (6, 'EduTech Innovations Ltd', 'EduTech', CAST('84-7362947' AS VARBINARY(255)), CAST('84-7362947' AS VARBINARY(255)),
     'https://edutech-innovations.edu', 'ACTIVE', '{"industry":"Education","employees":80,"founded":"2017"}'),
    (7, 'RetailMax Commerce LLC', 'RetailMax', CAST('92-5847362' AS VARBINARY(255)), CAST('92-5847362' AS VARBINARY(255)),
     'https://retailmax.shop', 'ACTIVE', '{"industry":"Retail","employees":300,"founded":"2010"}'),
    (8, 'PropTech Solutions Inc', 'PropTech', CAST('38-9274658' AS VARBINARY(255)), CAST('38-9274658' AS VARBINARY(255)),
     'https://proptech-solutions.com', 'ACTIVE', '{"industry":"Real Estate","employees":45,"founded":"2021"}'),
    (9, 'AutoDrive Systems', 'AutoDrive', CAST('47-8362947' AS VARBINARY(255)), CAST('47-8362947' AS VARBINARY(255)),
     'https://autodrive-systems.com', 'TRIAL', '{"industry":"Automotive","employees":25,"founded":"2023"}'),
    (10, 'CloudSync Technologies', 'CloudSync', CAST('56-7483920' AS VARBINARY(255)), CAST('56-7483920' AS VARBINARY(255)),
     'https://cloudsync.tech', 'ACTIVE', '{"industry":"Cloud Services","employees":150,"founded":"2018"}');

SET IDENTITY_INSERT [crm].[Subscribers] OFF;

PRINT '  ✓ Inserted 10 subscribers (NO ENCRYPTION)';

-- =============================================
-- ADDRESSES PER SUBSCRIBER
-- =============================================
PRINT 'Inserting Addresses...';

SET IDENTITY_INSERT [crm].[Addresses] ON;

INSERT INTO [crm].[Addresses] (addressId, address1, address2, zipcode, cityId, geolocation, enabled)
VALUES
    -- USA Subscribers (6)
    (1, '1234 Tech Boulevard', 'Suite 500', '94105', 2, geography::Point(37.7749, -122.4194, 4326), 1),   -- TechVision - San Francisco
    (2, '5678 Organic Lane', '', '92101', 3, geography::Point(32.7157, -117.1611, 4326), 1),               -- GreenLeaf - San Diego
    (3, '910 Marketing Plaza', 'Floor 12', '10001', 30, geography::Point(40.7128, -74.0060, 4326), 1),     -- Stellar - NYC
    (4, '234 Finance Street', '', '60601', 50, geography::Point(41.8781, -87.6298, 4326), 1),              -- FinanceFlow - Chicago
    (5, '567 Medical Center Dr', 'Building A', '02115', 80, geography::Point(42.3601, -71.0589, 4326), 1), -- HealthFirst - Boston
    (6, '890 Education Ave', '', '78701', 12, geography::Point(30.2672, -97.7431, 4326), 1),               -- EduTech - Austin

    -- Spain Subscribers (2)
    (7, 'Paseo de la Castellana 123', 'Piso 5', '28046', 1001, geography::Point(40.4168, -3.7038, 4326), 1),    -- RetailMax - Madrid
    (8, 'Avinguda Diagonal 456', '', '08006', 1002, geography::Point(41.3874, 2.1686, 4326), 1),                 -- PropTech - Barcelona

    -- Costa Rica Subscribers (2)
    (9, 'Avenida Escazú 789', 'Torre A', '10203', 2002, geography::Point(9.9281, -84.1325, 4326), 1),       -- AutoDrive - Escazú
    (10, 'Calle Central 321', 'Piso 8', '10101', 2001, geography::Point(9.9281, -84.0907, 4326), 1);        -- CloudSync - San José

SET IDENTITY_INSERT [crm].[Addresses] OFF;

PRINT '  ✓ Inserted 10 addresses';

-- Link addresses to subscribers
INSERT INTO [crm].[AddressesPerSubscriber] (subscriberId, addressId, enabled)
VALUES
    (1, 1, 1), (2, 2, 1), (3, 3, 1), (4, 4, 1), (5, 5, 1),
    (6, 6, 1), (7, 7, 1), (8, 8, 1), (9, 9, 1), (10, 10, 1);

PRINT '  ✓ Linked 10 addresses to subscribers';

-- =============================================
-- USERS (One Admin per Subscriber)
-- =============================================
PRINT 'Inserting Admin Users (NO ENCRYPTION - temporary for testing)...';

SET IDENTITY_INSERT [crm].[Users] ON;

INSERT INTO [crm].[Users]
    (userId, firstName, lastName, email, phoneNumber, nationalId, userStatusId)
VALUES
    (1, 'Sarah', 'Chen', 'sarah.chen@techvision-solutions.com', '+14155551001', CAST('123-45-6701' AS VARBINARY(255)), 1),
    (2, 'Michael', 'Rodriguez', 'michael.r@greenleaf-organics.com', '+15035552002', CAST('234-56-7802' AS VARBINARY(255)), 1),
    (3, 'Jennifer', 'Williams', 'jennifer.w@stellarmarketing.io', '+12125553003', CAST('345-67-8903' AS VARBINARY(255)), 1),
    (4, 'David', 'Thompson', 'david.t@financeflow.com', '+13125554004', CAST('456-78-9004' AS VARBINARY(255)), 1),
    (5, 'Emily', 'Anderson', 'emily.a@healthfirst-med.com', '+16175555005', CAST('567-89-0105' AS VARBINARY(255)), 1),
    (6, 'James', 'Martinez', 'james.m@edutech-innovations.edu', '+15125556006', CAST('678-90-1206' AS VARBINARY(255)), 1),
    (7, 'Lisa', 'Garcia', 'lisa.g@retailmax.shop', '+13105557007', CAST('789-01-2307' AS VARBINARY(255)), 1),
    (8, 'Robert', 'Brown', 'robert.b@proptech-solutions.com', '+13055558008', CAST('890-12-3408' AS VARBINARY(255)), 1),
    (9, 'Jessica', 'Davis', 'jessica.d@autodrive-systems.com', '+13135559009', CAST('901-23-4509' AS VARBINARY(255)), 1),
    (10, 'Christopher', 'Wilson', 'chris.w@cloudsync.tech', '+12065550010', CAST('012-34-5610' AS VARBINARY(255)), 1);

SET IDENTITY_INSERT [crm].[Users] OFF;

PRINT '  ✓ Inserted 10 admin users (NO ENCRYPTION)';

-- Link users to subscribers
INSERT INTO [crm].[UsersPerSubscriber] (userId, subscriberId, status)
VALUES
    (1, 1, 'ACTIVE'), (2, 2, 'ACTIVE'), (3, 3, 'ACTIVE'), (4, 4, 'ACTIVE'), (5, 5, 'ACTIVE'),
    (6, 6, 'ACTIVE'), (7, 7, 'ACTIVE'), (8, 8, 'ACTIVE'), (9, 9, 'ACTIVE'), (10, 10, 'ACTIVE');

PRINT '  ✓ Linked 10 users to subscribers';

-- =============================================
-- USER ROLES
-- =============================================
PRINT 'Creating User Roles...';

SET IDENTITY_INSERT [crm].[UserRoles] ON;

INSERT INTO [crm].[UserRoles] (userRoleId, userRoleName, subscriberId, enabled)
VALUES
    -- TechVision
    (1, 'Admin', 1, 1),
    (2, 'Sales Manager', 1, 1),
    (3, 'Sales Rep', 1, 1),

    -- GreenLeaf
    (4, 'Admin', 2, 1),
    (5, 'Marketing Manager', 2, 1),

    -- Stellar Marketing
    (6, 'Admin', 3, 1),
    (7, 'Campaign Manager', 3, 1),

    -- FinanceFlow
    (8, 'Admin', 4, 1),
    (9, 'Relationship Manager', 4, 1),

    -- HealthFirst
    (10, 'Admin', 5, 1),
    (11, 'Patient Coordinator', 5, 1),

    -- EduTech
    (12, 'Admin', 6, 1),
    (13, 'Admissions Rep', 6, 1),

    -- RetailMax
    (14, 'Admin', 7, 1),
    (15, 'Store Manager', 7, 1),

    -- PropTech
    (16, 'Admin', 8, 1),
    (17, 'Agent', 8, 1),

    -- AutoDrive
    (18, 'Admin', 9, 1),

    -- CloudSync
    (19, 'Admin', 10, 1),
    (20, 'Customer Success', 10, 1);

SET IDENTITY_INSERT [crm].[UserRoles] OFF;

PRINT '  ✓ Created 20 user roles';

-- Assign Admin role to each user
INSERT INTO [crm].[RolesPerUser] (userId, userRoleId, enabled)
VALUES
    (1, 1, 1), (2, 4, 1), (3, 6, 1), (4, 8, 1), (5, 10, 1),
    (6, 12, 1), (7, 14, 1), (8, 16, 1), (9, 18, 1), (10, 19, 1);

PRINT '  ✓ Assigned admin roles to users';

-- Assign full permissions to Admin roles
INSERT INTO [crm].[PermissionPerRole] (userRoleId, permissionId, enabled)
SELECT ur.userRoleId, p.permissionId, 1
FROM [crm].[UserRoles] ur
CROSS JOIN [crm].[Permissions] p
WHERE ur.userRoleName = 'Admin';

PRINT '  ✓ Assigned all permissions to admin roles';

-- =============================================
-- PAYMENT METHODS
-- =============================================
PRINT 'Creating Payment Methods (NO ENCRYPTION - temporary for testing)...';

SET IDENTITY_INSERT [crm].[PaymentMethods] ON;

INSERT INTO [crm].[PaymentMethods]
    (paymentMethodId, cardLastFour, cardBrand, expiryMonth, expiryYear,
     fingerprint, status, paymentMethodTypeId, verifiedAt)
VALUES
    (1, CAST('4242' AS VARBINARY(255)), CAST('VISA' AS VARBINARY(255)),
        CAST('12' AS VARBINARY(255)), CAST('2026' AS VARBINARY(255)),
        'fp_tech1234abcd', 'ACTIVE', 1, GETUTCDATE()),
    (2, CAST('8888' AS VARBINARY(255)), CAST('MASTERCARD' AS VARBINARY(255)),
        CAST('08' AS VARBINARY(255)), CAST('2027' AS VARBINARY(255)),
        'fp_green5678efgh', 'ACTIVE', 1, GETUTCDATE()),
    (3, CAST('1234' AS VARBINARY(255)), CAST('AMEX' AS VARBINARY(255)),
        CAST('05' AS VARBINARY(255)), CAST('2025' AS VARBINARY(255)),
        'fp_stellar9012ijkl', 'ACTIVE', 1, GETUTCDATE()),
    (4, CAST('5555' AS VARBINARY(255)), CAST('VISA' AS VARBINARY(255)),
        CAST('11' AS VARBINARY(255)), CAST('2028' AS VARBINARY(255)),
        'fp_finance3456mnop', 'ACTIVE', 1, GETUTCDATE()),
    (5, CAST('9999' AS VARBINARY(255)), CAST('VISA' AS VARBINARY(255)),
        CAST('03' AS VARBINARY(255)), CAST('2026' AS VARBINARY(255)),
        'fp_health7890qrst', 'ACTIVE', 1, GETUTCDATE()),
    (6, CAST('6666' AS VARBINARY(255)), CAST('MASTERCARD' AS VARBINARY(255)),
        CAST('07' AS VARBINARY(255)), CAST('2027' AS VARBINARY(255)),
        'fp_edu1234uvwx', 'ACTIVE', 1, GETUTCDATE()),
    (7, CAST('3333' AS VARBINARY(255)), CAST('VISA' AS VARBINARY(255)),
        CAST('10' AS VARBINARY(255)), CAST('2026' AS VARBINARY(255)),
        'fp_retail5678yzab', 'ACTIVE', 1, GETUTCDATE()),
    (8, CAST('7777' AS VARBINARY(255)), CAST('AMEX' AS VARBINARY(255)),
        CAST('06' AS VARBINARY(255)), CAST('2025' AS VARBINARY(255)),
        'fp_prop9012cdef', 'ACTIVE', 1, GETUTCDATE()),
    (9, CAST('0000' AS VARBINARY(255)), CAST('VISA' AS VARBINARY(255)),
        CAST('12' AS VARBINARY(255)), CAST('2024' AS VARBINARY(255)),
        'fp_auto3456ghij', 'ACTIVE', 1, GETUTCDATE()),
    (10, CAST('1111' AS VARBINARY(255)), CAST('MASTERCARD' AS VARBINARY(255)),
        CAST('09' AS VARBINARY(255)), CAST('2027' AS VARBINARY(255)),
        'fp_cloud7890klmn', 'ACTIVE', 1, GETUTCDATE());

SET IDENTITY_INSERT [crm].[PaymentMethods] OFF;

PRINT '  ✓ Created 10 payment methods (NO ENCRYPTION)';

-- =============================================
-- SUBSCRIPTIONS
-- =============================================
PRINT 'Creating Active Subscriptions...';

SET IDENTITY_INSERT [crm].[Subscriptions] ON;

DECLARE @Today datetime2 = GETUTCDATE();

INSERT INTO [crm].[Subscriptions]
    (subscriptionId, subscriberId, subscriptionPlanId, subscriptionStatusId,
     paymentMethodId, startDate, endDate, autoRenew, nextBillingDate)
VALUES
    -- TechVision: Professional Annual
    (1, 1, 2, 2, 1,
     DATEADD(YEAR, -1, @Today),
     DATEADD(YEAR, 1, @Today),
     1,
     DATEADD(YEAR, 1, @Today)),

    -- GreenLeaf: Business Monthly
    (2, 2, 3, 2, 2,
     DATEADD(MONTH, -6, @Today),
     DATEADD(MONTH, 6, @Today),
     1,
     DATEADD(MONTH, 1, @Today)),

    -- Stellar: Professional Monthly
    (3, 3, 2, 2, 3,
     DATEADD(MONTH, -3, @Today),
     DATEADD(MONTH, 9, @Today),
     1,
     DATEADD(MONTH, 1, @Today)),

    -- FinanceFlow: Enterprise Annual
    (4, 4, 4, 2, 4,
     DATEADD(YEAR, -2, @Today),
     DATEADD(YEAR, 1, @Today),
     1,
     DATEADD(YEAR, 1, @Today)),

    -- HealthFirst: Enterprise Annual
    (5, 5, 4, 2, 5,
     DATEADD(MONTH, -18, @Today),
     DATEADD(MONTH, 6, @Today),
     1,
     DATEADD(MONTH, 6, @Today)),

    -- EduTech: Business Annual
    (6, 6, 3, 2, 6,
     DATEADD(MONTH, -8, @Today),
     DATEADD(MONTH, 4, @Today),
     1,
     DATEADD(MONTH, 4, @Today)),

    -- RetailMax: Business Monthly
    (7, 7, 3, 2, 7,
     DATEADD(MONTH, -12, @Today),
     DATEADD(MONTH, 12, @Today),
     1,
     DATEADD(MONTH, 1, @Today)),

    -- PropTech: Starter Monthly
    (8, 8, 1, 2, 8,
     DATEADD(MONTH, -2, @Today),
     DATEADD(MONTH, 10, @Today),
     1,
     DATEADD(MONTH, 1, @Today)),

    -- AutoDrive: Trial
    (9, 9, 5, 1, 9,
     DATEADD(DAY, -7, @Today),
     DATEADD(DAY, 7, @Today),
     0,
     NULL),

    -- CloudSync: Professional Annual
    (10, 10, 2, 2, 10,
     DATEADD(MONTH, -4, @Today),
     DATEADD(MONTH, 8, @Today),
     1,
     DATEADD(MONTH, 8, @Today));

SET IDENTITY_INSERT [crm].[Subscriptions] OFF;

PRINT '  ✓ Created 10 active subscriptions';

PRINT '';
PRINT '========================================';
PRINT 'SUBSCRIBERS SEEDED SUCCESSFULLY (NO ENCRYPTION)';
PRINT '========================================';
PRINT 'Summary:';
PRINT '  - Subscribers: 10 (9 active, 1 trial) - NO ENCRYPTION';
PRINT '  - Users: 10 (1 admin per subscriber) - NO ENCRYPTION';
PRINT '  - Addresses: 10';
PRINT '  - User Roles: 20';
PRINT '  - Payment Methods: 10 - NO ENCRYPTION';
PRINT '  - Active Subscriptions: 10';
PRINT '';
PRINT 'Subscriber Breakdown:';
PRINT '  - Starter Plan: 1 (PropTech)';
PRINT '  - Professional Plan: 3 (TechVision, Stellar, CloudSync)';
PRINT '  - Business Plan: 3 (GreenLeaf, EduTech, RetailMax)';
PRINT '  - Enterprise Plan: 2 (FinanceFlow, HealthFirst)';
PRINT '  - Trial: 1 (AutoDrive)';
PRINT '';
PRINT 'NOTE: Data stored as VARBINARY without encryption (for testing).';
PRINT '      Encrypt sensitive data after generation using ENCRYPTBYKEY.';

GO
