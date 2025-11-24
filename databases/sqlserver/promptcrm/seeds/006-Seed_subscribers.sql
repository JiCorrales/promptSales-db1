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
PRINT 'Inserting Subscribers using MASTER encryption...';

-- Preparar variables para cifrado
DECLARE @Sub1LegalId VARBINARY(255), @Sub1TaxId VARBINARY(255);
DECLARE @Sub2LegalId VARBINARY(255), @Sub2TaxId VARBINARY(255);
DECLARE @Sub3LegalId VARBINARY(255), @Sub3TaxId VARBINARY(255);
DECLARE @Sub4LegalId VARBINARY(255), @Sub4TaxId VARBINARY(255);
DECLARE @Sub5LegalId VARBINARY(255), @Sub5TaxId VARBINARY(255);
DECLARE @Sub6LegalId VARBINARY(255), @Sub6TaxId VARBINARY(255);
DECLARE @Sub7LegalId VARBINARY(255), @Sub7TaxId VARBINARY(255);
DECLARE @Sub8LegalId VARBINARY(255), @Sub8TaxId VARBINARY(255);
DECLARE @Sub9LegalId VARBINARY(255), @Sub9TaxId VARBINARY(255);
DECLARE @Sub10LegalId VARBINARY(255), @Sub10TaxId VARBINARY(255);

-- Cifrar todos los IDs usando el SP de MASTER
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '45-2938475', @EncryptedData = @Sub1LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '45-2938475', @EncryptedData = @Sub1TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '47-3928471', @EncryptedData = @Sub2LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '47-3928471', @EncryptedData = @Sub2TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '52-8374658', @EncryptedData = @Sub3LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '52-8374658', @EncryptedData = @Sub3TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '61-9284756', @EncryptedData = @Sub4LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '61-9284756', @EncryptedData = @Sub4TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '73-4857293', @EncryptedData = @Sub5LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '73-4857293', @EncryptedData = @Sub5TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '84-7362947', @EncryptedData = @Sub6LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '84-7362947', @EncryptedData = @Sub6TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '92-5847362', @EncryptedData = @Sub7LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '92-5847362', @EncryptedData = @Sub7TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '38-9274658', @EncryptedData = @Sub8LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '38-9274658', @EncryptedData = @Sub8TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '47-8362947', @EncryptedData = @Sub9LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '47-8362947', @EncryptedData = @Sub9TaxId OUTPUT;

EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '56-7483920', @EncryptedData = @Sub10LegalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '56-7483920', @EncryptedData = @Sub10TaxId OUTPUT;

SET IDENTITY_INSERT [crm].[Subscribers] ON;

INSERT INTO [crm].[Subscribers]
    (subscriberId, legalName, comercialName, legalId, taxId, websiteUrl, status, metadata)
VALUES
    (1, 'TechVision Solutions LLC', 'TechVision', @Sub1LegalId, @Sub1TaxId,
     'https://techvision-solutions.com', 'ACTIVE', '{"industry":"Technology","employees":50,"founded":"2019"}'),
    (2, 'GreenLeaf Organics Inc', 'GreenLeaf', @Sub2LegalId, @Sub2TaxId,
     'https://greenleaf-organics.com', 'ACTIVE', '{"industry":"Food & Beverage","employees":120,"founded":"2015"}'),
    (3, 'Stellar Marketing Group', 'Stellar Marketing', @Sub3LegalId, @Sub3TaxId,
     'https://stellarmarketing.io', 'ACTIVE', '{"industry":"Marketing","employees":35,"founded":"2020"}'),
    (4, 'FinanceFlow Corporation', 'FinanceFlow', @Sub4LegalId, @Sub4TaxId,
     'https://financeflow.com', 'ACTIVE', '{"industry":"Financial Services","employees":200,"founded":"2012"}'),
    (5, 'HealthFirst Medical Systems', 'HealthFirst', @Sub5LegalId, @Sub5TaxId,
     'https://healthfirst-med.com', 'ACTIVE', '{"industry":"Healthcare","employees":500,"founded":"2008"}'),
    (6, 'EduTech Innovations Ltd', 'EduTech', @Sub6LegalId, @Sub6TaxId,
     'https://edutech-innovations.edu', 'ACTIVE', '{"industry":"Education","employees":80,"founded":"2017"}'),
    (7, 'RetailMax Commerce LLC', 'RetailMax', @Sub7LegalId, @Sub7TaxId,
     'https://retailmax.shop', 'ACTIVE', '{"industry":"Retail","employees":300,"founded":"2010"}'),
    (8, 'PropTech Solutions Inc', 'PropTech', @Sub8LegalId, @Sub8TaxId,
     'https://proptech-solutions.com', 'ACTIVE', '{"industry":"Real Estate","employees":45,"founded":"2021"}'),
    (9, 'AutoDrive Systems', 'AutoDrive', @Sub9LegalId, @Sub9TaxId,
     'https://autodrive-systems.com', 'TRIAL', '{"industry":"Automotive","employees":25,"founded":"2023"}'),
    (10, 'CloudSync Technologies', 'CloudSync', @Sub10LegalId, @Sub10TaxId,
     'https://cloudsync.tech', 'ACTIVE', '{"industry":"Cloud Services","employees":150,"founded":"2018"}');

SET IDENTITY_INSERT [crm].[Subscribers] OFF;

PRINT '  ✓ Inserted 10 subscribers (encrypted with MASTER key)';

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
PRINT 'Inserting Admin Users using MASTER encryption...';

-- Preparar variables para cifrado de nationalId
DECLARE @User1NationalId VARBINARY(255), @User2NationalId VARBINARY(255);
DECLARE @User3NationalId VARBINARY(255), @User4NationalId VARBINARY(255);
DECLARE @User5NationalId VARBINARY(255), @User6NationalId VARBINARY(255);
DECLARE @User7NationalId VARBINARY(255), @User8NationalId VARBINARY(255);
DECLARE @User9NationalId VARBINARY(255), @User10NationalId VARBINARY(255);

-- Cifrar nationalIds usando el SP de MASTER
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '123-45-6701', @EncryptedData = @User1NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '234-56-7802', @EncryptedData = @User2NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '345-67-8903', @EncryptedData = @User3NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '456-78-9004', @EncryptedData = @User4NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '567-89-0105', @EncryptedData = @User5NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '678-90-1206', @EncryptedData = @User6NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '789-01-2307', @EncryptedData = @User7NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '890-12-3408', @EncryptedData = @User8NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '901-23-4509', @EncryptedData = @User9NationalId OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '012-34-5610', @EncryptedData = @User10NationalId OUTPUT;

SET IDENTITY_INSERT [crm].[Users] ON;

INSERT INTO [crm].[Users]
    (userId, firstName, lastName, email, phoneNumber, nationalId, userStatusId)
VALUES
    (1, 'Sarah', 'Chen', 'sarah.chen@techvision-solutions.com', '+14155551001', @User1NationalId, 1),
    (2, 'Michael', 'Rodriguez', 'michael.r@greenleaf-organics.com', '+15035552002', @User2NationalId, 1),
    (3, 'Jennifer', 'Williams', 'jennifer.w@stellarmarketing.io', '+12125553003', @User3NationalId, 1),
    (4, 'David', 'Thompson', 'david.t@financeflow.com', '+13125554004', @User4NationalId, 1),
    (5, 'Emily', 'Anderson', 'emily.a@healthfirst-med.com', '+16175555005', @User5NationalId, 1),
    (6, 'James', 'Martinez', 'james.m@edutech-innovations.edu', '+15125556006', @User6NationalId, 1),
    (7, 'Lisa', 'Garcia', 'lisa.g@retailmax.shop', '+13105557007', @User7NationalId, 1),
    (8, 'Robert', 'Brown', 'robert.b@proptech-solutions.com', '+13055558008', @User8NationalId, 1),
    (9, 'Jessica', 'Davis', 'jessica.d@autodrive-systems.com', '+13135559009', @User9NationalId, 1),
    (10, 'Christopher', 'Wilson', 'chris.w@cloudsync.tech', '+12065550010', @User10NationalId, 1);

SET IDENTITY_INSERT [crm].[Users] OFF;

PRINT '  ✓ Inserted 10 admin users (encrypted with MASTER key)';

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
PRINT 'Creating Payment Methods using MASTER encryption...';

-- Preparar variables para cifrado de payment methods (4 campos x 10 = 40 variables)
DECLARE @PM1Card VARBINARY(255), @PM1Brand VARBINARY(255), @PM1Month VARBINARY(255), @PM1Year VARBINARY(255);
DECLARE @PM2Card VARBINARY(255), @PM2Brand VARBINARY(255), @PM2Month VARBINARY(255), @PM2Year VARBINARY(255);
DECLARE @PM3Card VARBINARY(255), @PM3Brand VARBINARY(255), @PM3Month VARBINARY(255), @PM3Year VARBINARY(255);
DECLARE @PM4Card VARBINARY(255), @PM4Brand VARBINARY(255), @PM4Month VARBINARY(255), @PM4Year VARBINARY(255);
DECLARE @PM5Card VARBINARY(255), @PM5Brand VARBINARY(255), @PM5Month VARBINARY(255), @PM5Year VARBINARY(255);
DECLARE @PM6Card VARBINARY(255), @PM6Brand VARBINARY(255), @PM6Month VARBINARY(255), @PM6Year VARBINARY(255);
DECLARE @PM7Card VARBINARY(255), @PM7Brand VARBINARY(255), @PM7Month VARBINARY(255), @PM7Year VARBINARY(255);
DECLARE @PM8Card VARBINARY(255), @PM8Brand VARBINARY(255), @PM8Month VARBINARY(255), @PM8Year VARBINARY(255);
DECLARE @PM9Card VARBINARY(255), @PM9Brand VARBINARY(255), @PM9Month VARBINARY(255), @PM9Year VARBINARY(255);
DECLARE @PM10Card VARBINARY(255), @PM10Brand VARBINARY(255), @PM10Month VARBINARY(255), @PM10Year VARBINARY(255);

-- Cifrar payment method 1
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '4242', @EncryptedData = @PM1Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM1Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '12', @EncryptedData = @PM1Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2026', @EncryptedData = @PM1Year OUTPUT;

-- Cifrar payment method 2
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '8888', @EncryptedData = @PM2Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'MASTERCARD', @EncryptedData = @PM2Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '08', @EncryptedData = @PM2Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2027', @EncryptedData = @PM2Year OUTPUT;

-- Cifrar payment method 3
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '1234', @EncryptedData = @PM3Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'AMEX', @EncryptedData = @PM3Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '05', @EncryptedData = @PM3Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2025', @EncryptedData = @PM3Year OUTPUT;

-- Cifrar payment method 4
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '5555', @EncryptedData = @PM4Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM4Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '11', @EncryptedData = @PM4Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2028', @EncryptedData = @PM4Year OUTPUT;

-- Cifrar payment method 5
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '9999', @EncryptedData = @PM5Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM5Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '03', @EncryptedData = @PM5Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2026', @EncryptedData = @PM5Year OUTPUT;

-- Cifrar payment method 6
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '6666', @EncryptedData = @PM6Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'MASTERCARD', @EncryptedData = @PM6Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '07', @EncryptedData = @PM6Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2027', @EncryptedData = @PM6Year OUTPUT;

-- Cifrar payment method 7
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '3333', @EncryptedData = @PM7Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM7Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '10', @EncryptedData = @PM7Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2026', @EncryptedData = @PM7Year OUTPUT;

-- Cifrar payment method 8
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '7777', @EncryptedData = @PM8Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'AMEX', @EncryptedData = @PM8Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '06', @EncryptedData = @PM8Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2025', @EncryptedData = @PM8Year OUTPUT;

-- Cifrar payment method 9
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '0000', @EncryptedData = @PM9Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'VISA', @EncryptedData = @PM9Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '12', @EncryptedData = @PM9Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2024', @EncryptedData = @PM9Year OUTPUT;

-- Cifrar payment method 10
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '1111', @EncryptedData = @PM10Card OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = 'MASTERCARD', @EncryptedData = @PM10Brand OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '09', @EncryptedData = @PM10Month OUTPUT;
EXEC master.dbo.sp_PromptCRM_Encrypt_Bridge @ClearText = '2027', @EncryptedData = @PM10Year OUTPUT;

SET IDENTITY_INSERT [crm].[PaymentMethods] ON;

INSERT INTO [crm].[PaymentMethods]
    (paymentMethodId, cardLastFour, cardBrand, expiryMonth, expiryYear,
     fingerprint, status, paymentMethodTypeId, verifiedAt)
VALUES
    (1, @PM1Card, @PM1Brand, @PM1Month, @PM1Year, 'fp_tech1234abcd', 'ACTIVE', 1, GETUTCDATE()),
    (2, @PM2Card, @PM2Brand, @PM2Month, @PM2Year, 'fp_green5678efgh', 'ACTIVE', 1, GETUTCDATE()),
    (3, @PM3Card, @PM3Brand, @PM3Month, @PM3Year, 'fp_stellar9012ijkl', 'ACTIVE', 1, GETUTCDATE()),
    (4, @PM4Card, @PM4Brand, @PM4Month, @PM4Year, 'fp_finance3456mnop', 'ACTIVE', 1, GETUTCDATE()),
    (5, @PM5Card, @PM5Brand, @PM5Month, @PM5Year, 'fp_health7890qrst', 'ACTIVE', 1, GETUTCDATE()),
    (6, @PM6Card, @PM6Brand, @PM6Month, @PM6Year, 'fp_edu1234uvwx', 'ACTIVE', 1, GETUTCDATE()),
    (7, @PM7Card, @PM7Brand, @PM7Month, @PM7Year, 'fp_retail5678yzab', 'ACTIVE', 1, GETUTCDATE()),
    (8, @PM8Card, @PM8Brand, @PM8Month, @PM8Year, 'fp_prop9012cdef', 'ACTIVE', 1, GETUTCDATE()),
    (9, @PM9Card, @PM9Brand, @PM9Month, @PM9Year, 'fp_auto3456ghij', 'ACTIVE', 1, GETUTCDATE()),
    (10, @PM10Card, @PM10Brand, @PM10Month, @PM10Year, 'fp_cloud7890klmn', 'ACTIVE', 1, GETUTCDATE());

SET IDENTITY_INSERT [crm].[PaymentMethods] OFF;

PRINT '  ✓ Created 10 payment methods (encrypted with MASTER key)';

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
PRINT 'SUBSCRIBERS SEEDED SUCCESSFULLY (MASTER ENCRYPTION)';
PRINT '========================================';
PRINT 'Summary:';
PRINT '  - Subscribers: 10 (9 active, 1 trial)';
PRINT '  - Users: 10 (1 admin per subscriber)';
PRINT '  - Addresses: 10';
PRINT '  - User Roles: 20';
PRINT '  - Payment Methods: 10 (encrypted)';
PRINT '  - Active Subscriptions: 10';
PRINT '';
PRINT 'Subscriber Breakdown:';
PRINT '  - Starter Plan: 1 (PropTech)';
PRINT '  - Professional Plan: 3 (TechVision, Stellar, CloudSync)';
PRINT '  - Business Plan: 3 (GreenLeaf, EduTech, RetailMax)';
PRINT '  - Enterprise Plan: 2 (FinanceFlow, HealthFirst)';
PRINT '  - Trial: 1 (AutoDrive)';
PRINT '';

GO
