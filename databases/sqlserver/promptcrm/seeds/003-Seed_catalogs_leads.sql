-- =============================================
-- PromptCRM - Seed Data: Lead-Related Catalogs
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Populate lead statuses, tiers, sources, events, etc.
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'SEEDING LEAD CATALOGS';
PRINT '========================================';
PRINT '';

-- =============================================
-- LEAD STATUS
-- =============================================
PRINT 'Inserting Lead Statuses...';

SET IDENTITY_INSERT [crm].[LeadStatus] ON;

INSERT INTO [crm].[LeadStatus] (leadStatusId, leadStatusKey, leadStatusName, enabled)
VALUES
    (1, 'NEW', 'New Lead', 1),
    (2, 'CONTACTED', 'Contacted', 1),
    (3, 'QUALIFIED', 'Qualified', 1),
    (4, 'UNQUALIFIED', 'Unqualified', 1),
    (5, 'NURTURING', 'Nurturing', 1),
    (6, 'CONVERTED', 'Converted', 1),
    (7, 'LOST', 'Lost', 1),
    (8, 'DEAD', 'Dead', 1);

SET IDENTITY_INSERT [crm].[LeadStatus] OFF;

PRINT '  ✓ Inserted 8 lead statuses';

-- =============================================
-- LEAD TIERS (Scoring Ranges)
-- =============================================
PRINT 'Inserting Lead Tiers...';

SET IDENTITY_INSERT [crm].[LeadTiers] ON;

INSERT INTO [crm].[LeadTiers] (leadTierId, leadTierKey, leadTierName, minScore, maxScore, enabled)
VALUES
    (1, 'COLD', 'Cold Lead', 0.00, 25.00, 1),
    (2, 'COOL', 'Cool Lead', 25.01, 50.00, 1),
    (3, 'WARM', 'Warm Lead', 50.01, 75.00, 1),
    (4, 'HOT', 'Hot Lead', 75.01, 90.00, 1),
    (5, 'BLAZING', 'Blazing Hot Lead', 90.01, 100.00, 1);

SET IDENTITY_INSERT [crm].[LeadTiers] OFF;

PRINT '  ✓ Inserted 5 lead tiers';

-- =============================================
-- LEAD SOURCE TYPES
-- =============================================
PRINT 'Inserting Lead Source Types...';

SET IDENTITY_INSERT [crm].[LeadSourceTypes] ON;

INSERT INTO [crm].[LeadSourceTypes] (leadSourceTypeId, sourceTypeKey, sourceTypeName, description, enabled)
VALUES
    (1, 'ORGANIC', 'Organic Search', 'Found via search engine', 1),
    (2, 'PAID_AD', 'Paid Advertising', 'Clicked on paid ad', 1),
    (3, 'SOCIAL', 'Social Media', 'Social media post/ad', 1),
    (4, 'EMAIL', 'Email Campaign', 'Email marketing campaign', 1),
    (5, 'REFERRAL', 'Referral', 'Referred by existing customer', 1),
    (6, 'DIRECT', 'Direct', 'Direct website visit', 1),
    (7, 'CONTENT', 'Content Marketing', 'Blog/content download', 1),
    (8, 'WEBINAR', 'Webinar', 'Webinar registration', 1),
    (9, 'TRADE_SHOW', 'Trade Show', 'Trade show/event', 1),
    (10, 'PARTNER', 'Partner', 'Partner referral', 1);

SET IDENTITY_INSERT [crm].[LeadSourceTypes] OFF;

PRINT '  ✓ Inserted 10 lead source types';

-- =============================================
-- LEAD SOURCE SYSTEMS
-- =============================================
PRINT 'Inserting Lead Source Systems...';

SET IDENTITY_INSERT [crm].[LeadSourceSystems] ON;

INSERT INTO [crm].[LeadSourceSystems] (leadSourceSystemId, systemKey, systemName, description, enabled)
VALUES
    (1, 'GOOGLE_ADS', 'Google Ads', 'Google advertising platform', 1),
    (2, 'META_ADS', 'Meta Ads', 'Facebook/Instagram ads', 1),
    (3, 'TIKTOK_ADS', 'TikTok Ads', 'TikTok advertising', 1),
    (4, 'LINKEDIN_ADS', 'LinkedIn Ads', 'LinkedIn advertising', 1),
    (5, 'TWITTER_ADS', 'Twitter/X Ads', 'Twitter advertising', 1),
    (6, 'MAILCHIMP', 'Mailchimp', 'Email marketing platform', 1),
    (7, 'HUBSPOT', 'HubSpot', 'HubSpot CRM', 1),
    (8, 'SALESFORCE', 'Salesforce', 'Salesforce CRM', 1),
    (9, 'GOOGLE_SEARCH', 'Google Search', 'Organic Google search', 1),
    (10, 'YOUTUBE', 'YouTube', 'YouTube platform', 1);

SET IDENTITY_INSERT [crm].[LeadSourceSystems] OFF;

PRINT '  ✓ Inserted 10 lead source systems';

-- =============================================
-- LEAD MEDIUMS
-- =============================================
PRINT 'Inserting Lead Mediums...';

SET IDENTITY_INSERT [crm].[LeadMediums] ON;

INSERT INTO [crm].[LeadMediums] (leadMediumId, leadMediumKey, leadMediumName, description, enabled)
VALUES
    (1, 'CPC', 'Cost Per Click', 'Paid search/display ads', 1),
    (2, 'ORGANIC', 'Organic', 'Organic search traffic', 1),
    (3, 'EMAIL', 'Email', 'Email campaigns', 1),
    (4, 'SOCIAL', 'Social', 'Social media posts', 1),
    (5, 'DISPLAY', 'Display', 'Display/banner ads', 1),
    (6, 'VIDEO', 'Video', 'Video advertising', 1),
    (7, 'REFERRAL', 'Referral', 'Referral links', 1),
    (8, 'AFFILIATE', 'Affiliate', 'Affiliate marketing', 1),
    (9, 'SMS', 'SMS', 'Text message campaigns', 1),
    (10, 'PUSH', 'Push Notification', 'Push notifications', 1);

SET IDENTITY_INSERT [crm].[LeadMediums] OFF;

PRINT '  ✓ Inserted 10 lead mediums';

-- =============================================
-- LEAD ORIGIN CHANNELS
-- =============================================
PRINT 'Inserting Lead Origin Channels...';

SET IDENTITY_INSERT [crm].[LeadOriginChannels] ON;

INSERT INTO [crm].[LeadOriginChannels] (leadOriginChannelId, leadOriginChannelKey, leadOriginChannelName, description, enabled)
VALUES
    (1, 'FACEBOOK', 'Facebook', 'Facebook platform', 1),
    (2, 'INSTAGRAM', 'Instagram', 'Instagram platform', 1),
    (3, 'LINKEDIN', 'LinkedIn', 'LinkedIn platform', 1),
    (4, 'TWITTER', 'Twitter/X', 'Twitter/X platform', 1),
    (5, 'TIKTOK', 'TikTok', 'TikTok platform', 1),
    (6, 'YOUTUBE', 'YouTube', 'YouTube platform', 1),
    (7, 'GOOGLE', 'Google', 'Google Search/Display', 1),
    (8, 'WEBSITE', 'Website', 'Direct website', 1),
    (9, 'EMAIL', 'Email', 'Email channel', 1),
    (10, 'WHATSAPP', 'WhatsApp', 'WhatsApp Business', 1),
    (11, 'TELEGRAM', 'Telegram', 'Telegram', 1),
    (12, 'REDDIT', 'Reddit', 'Reddit platform', 1);

SET IDENTITY_INSERT [crm].[LeadOriginChannels] OFF;

PRINT '  ✓ Inserted 12 lead origin channels';

-- =============================================
-- DEVICE TYPES
-- =============================================
PRINT 'Inserting Device Types...';

SET IDENTITY_INSERT [crm].[DeviceTypes] ON;

INSERT INTO [crm].[DeviceTypes] (deviceTypeId, deviceTypeKey, deviceTypeName, description, enabled)
VALUES
    (1, 'DESKTOP', 'Desktop', 'Desktop computer', 1),
    (2, 'LAPTOP', 'Laptop', 'Laptop computer', 1),
    (3, 'MOBILE', 'Mobile', 'Mobile phone', 1),
    (4, 'TABLET', 'Tablet', 'Tablet device', 1),
    (5, 'SMART_TV', 'Smart TV', 'Smart television', 1),
    (6, 'WEARABLE', 'Wearable', 'Smartwatch/wearable', 1),
    (7, 'CONSOLE', 'Console', 'Gaming console', 1);

SET IDENTITY_INSERT [crm].[DeviceTypes] OFF;

PRINT '  ✓ Inserted 7 device types';

-- =============================================
-- DEVICE PLATFORMS
-- =============================================
PRINT 'Inserting Device Platforms...';

SET IDENTITY_INSERT [crm].[DevicePlatforms] ON;

INSERT INTO [crm].[DevicePlatforms] (devicePlatformId, devicePlatformKey, devicePlatformName, description, enabled)
VALUES
    (1, 'WINDOWS', 'Windows', 'Microsoft Windows', 1),
    (2, 'MACOS', 'macOS', 'Apple macOS', 1),
    (3, 'LINUX', 'Linux', 'Linux OS', 1),
    (4, 'IOS', 'iOS', 'Apple iOS', 1),
    (5, 'ANDROID', 'Android', 'Google Android', 1),
    (6, 'IPADOS', 'iPadOS', 'Apple iPadOS', 1),
    (7, 'CHROMEOS', 'ChromeOS', 'Google ChromeOS', 1),
    (8, 'WATCHOS', 'watchOS', 'Apple watchOS', 1);

SET IDENTITY_INSERT [crm].[DevicePlatforms] OFF;

PRINT '  ✓ Inserted 8 device platforms';

-- =============================================
-- BROWSERS
-- =============================================
PRINT 'Inserting Browsers...';

SET IDENTITY_INSERT [crm].[Browsers] ON;

INSERT INTO [crm].[Browsers] (browserId, browserKey, browserName, description, enabled)
VALUES
    (1, 'CHROME', 'Google Chrome', 'Google Chrome browser', 1),
    (2, 'FIREFOX', 'Mozilla Firefox', 'Mozilla Firefox browser', 1),
    (3, 'SAFARI', 'Safari', 'Apple Safari browser', 1),
    (4, 'EDGE', 'Microsoft Edge', 'Microsoft Edge browser', 1),
    (5, 'OPERA', 'Opera', 'Opera browser', 1),
    (6, 'BRAVE', 'Brave', 'Brave browser', 1),
    (7, 'SAMSUNG', 'Samsung Internet', 'Samsung Internet browser', 1),
    (8, 'UC', 'UC Browser', 'UC Browser', 1);

SET IDENTITY_INSERT [crm].[Browsers] OFF;

PRINT '  ✓ Inserted 8 browsers';

-- =============================================
-- LEAD EVENT TYPES
-- =============================================
PRINT 'Inserting Lead Event Types...';

SET IDENTITY_INSERT [crm].[LeadEventTypes] ON;

INSERT INTO [crm].[LeadEventTypes] (leadEventTypeId, eventTypeKey, eventTypeName, categoryKey, description, enabled)
VALUES
    (1, 'PAGE_VIEW', 'Page View', 'ENGAGEMENT', 'User viewed a page', 1),
    (2, 'LINK_CLICK', 'Link Click', 'ENGAGEMENT', 'User clicked a link', 1),
    (3, 'BUTTON_CLICK', 'Button Click', 'ENGAGEMENT', 'User clicked a button', 1),
    (4, 'FORM_VIEW', 'Form View', 'ENGAGEMENT', 'User viewed a form', 1),
    (5, 'FORM_START', 'Form Start', 'ENGAGEMENT', 'User started filling form', 1),
    (6, 'FORM_SUBMIT', 'Form Submit', 'CONVERSION', 'User submitted form', 1),
    (7, 'VIDEO_VIEW', 'Video View', 'ENGAGEMENT', 'User viewed video', 1),
    (8, 'VIDEO_25', 'Video 25%', 'ENGAGEMENT', 'Watched 25% of video', 1),
    (9, 'VIDEO_50', 'Video 50%', 'ENGAGEMENT', 'Watched 50% of video', 1),
    (10, 'VIDEO_75', 'Video 75%', 'ENGAGEMENT', 'Watched 75% of video', 1),
    (11, 'VIDEO_100', 'Video Complete', 'ENGAGEMENT', 'Watched 100% of video', 1),
    (12, 'DOWNLOAD', 'File Download', 'CONVERSION', 'Downloaded a file', 1),
    (13, 'SIGNUP', 'Sign Up', 'CONVERSION', 'Created account', 1),
    (14, 'ADD_TO_CART', 'Add to Cart', 'CONVERSION', 'Added item to cart', 1),
    (15, 'CHECKOUT_START', 'Checkout Start', 'CONVERSION', 'Started checkout', 1),
    (16, 'PURCHASE', 'Purchase', 'CONVERSION', 'Completed purchase', 1),
    (17, 'EMAIL_OPEN', 'Email Open', 'ENGAGEMENT', 'Opened email', 1),
    (18, 'EMAIL_CLICK', 'Email Click', 'ENGAGEMENT', 'Clicked link in email', 1),
    (19, 'CALL', 'Phone Call', 'ENGAGEMENT', 'Made phone call', 1),
    (20, 'CHAT_START', 'Chat Started', 'ENGAGEMENT', 'Started chat', 1);

SET IDENTITY_INSERT [crm].[LeadEventTypes] OFF;

PRINT '  ✓ Inserted 20 lead event types';

-- =============================================
-- LEAD EVENT SOURCES
-- =============================================
PRINT 'Inserting Lead Event Sources...';

SET IDENTITY_INSERT [crm].[LeadEventSources] ON;

INSERT INTO [crm].[LeadEventSources] (leadEventSourceId, sourceKey, sourceName, description, enabled)
VALUES
    (1, 'WEBSITE', 'Website Tracking', 'Events from website', 1),
    (2, 'MOBILE_APP', 'Mobile App', 'Events from mobile app', 1),
    (3, 'EMAIL_PLATFORM', 'Email Platform', 'Events from email tracking', 1),
    (4, 'CRM_SYSTEM', 'CRM System', 'Events from CRM', 1),
    (5, 'CHAT_WIDGET', 'Chat Widget', 'Events from chat', 1),
    (6, 'PHONE_SYSTEM', 'Phone System', 'Events from phone', 1),
    (7, 'WEBHOOK', 'Webhook', 'Events from external webhook', 1),
    (8, 'API', 'API', 'Events via API', 1);

SET IDENTITY_INSERT [crm].[LeadEventSources] OFF;

PRINT '  ✓ Inserted 8 lead event sources';

-- =============================================
-- DEMOGRAPHIC RACES
-- =============================================
PRINT 'Inserting Demographic Races...';

SET IDENTITY_INSERT [crm].[DemographicRaces] ON;

INSERT INTO [crm].[DemographicRaces] (demographicRaceId, demographicRaceKey, demographicRaceName, enabled)
VALUES
    (1, 'ASIAN', 'Asian', 1),
    (2, 'BLACK', 'Black or African American', 1),
    (3, 'WHITE', 'White', 1),
    (4, 'NATIVE', 'Native American', 1),
    (5, 'PACIFIC', 'Pacific Islander', 1),
    (6, 'MIXED', 'Mixed Race', 1),
    (7, 'OTHER', 'Other', 1),
    (8, 'PREFER_NOT', 'Prefer not to say', 1);

SET IDENTITY_INSERT [crm].[DemographicRaces] OFF;

PRINT '  ✓ Inserted 8 demographic races';

-- =============================================
-- DEMOGRAPHIC GENDERS
-- =============================================
PRINT 'Inserting Demographic Genders...';

SET IDENTITY_INSERT [crm].[DemographicGenders] ON;

INSERT INTO [crm].[DemographicGenders] (demographicGenderId, demographicGenderKey, demographicGenderName, enabled)
VALUES
    (1, 'MALE', 'Male', 1),
    (2, 'FEMALE', 'Female', 1),
    (3, 'NON_BINARY', 'Non-Binary', 1),
    (4, 'OTHER', 'Other', 1),
    (5, 'PREFER_NOT', 'Prefer not to say', 1);

SET IDENTITY_INSERT [crm].[DemographicGenders] OFF;

PRINT '  ✓ Inserted 5 demographic genders';

-- =============================================
-- DEMOGRAPHIC ETHNICITIES
-- =============================================
PRINT 'Inserting Demographic Ethnicities...';

SET IDENTITY_INSERT [crm].[DemographicEthnicities] ON;

INSERT INTO [crm].[DemographicEthnicities] (demographicEthnicityId, demographicEnthnicityKey, demographicEnthnicityName, enabled)
VALUES
    (1, 'HISPANIC', 'Hispanic or Latino', 1),
    (2, 'NOT_HISPANIC', 'Not Hispanic or Latino', 1),
    (3, 'PREFER_NOT', 'Prefer not to say', 1);

SET IDENTITY_INSERT [crm].[DemographicEthnicities] OFF;

PRINT '  ✓ Inserted 3 demographic ethnicities';

-- =============================================
-- LEAD CONVERSION TYPES
-- =============================================
PRINT 'Inserting Lead Conversion Types...';

SET IDENTITY_INSERT [crm].[LeadConversionTypes] ON;

INSERT INTO [crm].[LeadConversionTypes] (leadConversionTypeId, leadConversionKey, leadConversionName, enabled)
VALUES
    (1, 'SIGNUP', 'Sign Up Conversion', 1),
    (2, 'TRIAL', 'Trial Conversion', 1),
    (3, 'PURCHASE', 'Purchase Conversion', 1),
    (4, 'SUBSCRIPTION', 'Subscription Conversion', 1),
    (5, 'DEMO_REQUEST', 'Demo Request', 1),
    (6, 'CONTACT', 'Contact Conversion', 1),
    (7, 'DOWNLOAD', 'Download Conversion', 1);

SET IDENTITY_INSERT [crm].[LeadConversionTypes] OFF;

PRINT '  ✓ Inserted 7 lead conversion types';

-- =============================================
-- ATTRIBUTION MODELS
-- =============================================
PRINT 'Inserting Attribution Models...';

SET IDENTITY_INSERT [crm].[AttributionModels] ON;

INSERT INTO [crm].[AttributionModels] (attributionModelId, modelKey, modelName, description, enabled)
VALUES
    (1, 'LAST_TOUCH', 'Last Touch', 'Credit to last interaction', 1),
    (2, 'FIRST_TOUCH', 'First Touch', 'Credit to first interaction', 1),
    (3, 'LINEAR', 'Linear', 'Equal credit to all touches', 1),
    (4, 'TIME_DECAY', 'Time Decay', 'More credit to recent touches', 1),
    (5, 'U_SHAPED', 'U-Shaped', 'Credit to first and last', 1),
    (6, 'W_SHAPED', 'W-Shaped', 'Credit to first, middle, last', 1);

SET IDENTITY_INSERT [crm].[AttributionModels] OFF;

PRINT '  ✓ Inserted 6 attribution models';

-- =============================================
-- LEAD TAG CATEGORIES
-- =============================================
PRINT 'Inserting Lead Tag Categories...';

SET IDENTITY_INSERT [crm].[LeadTagCategories] ON;

INSERT INTO [crm].[LeadTagCategories] (leadCategoryId, leadCategoryKey, leadCategorynName, enabled)
VALUES
    (1, 'INTEREST', 'Interest', 1),
    (2, 'BEHAVIOR', 'Behavior', 1),
    (3, 'DEMOGRAPHIC', 'Demographic', 1),
    (4, 'INTENT', 'Intent Signal', 1),
    (5, 'ENGAGEMENT', 'Engagement Level', 1);

SET IDENTITY_INSERT [crm].[LeadTagCategories] OFF;

PRINT '  ✓ Inserted 5 lead tag categories';

-- =============================================
-- COMMUNICATION CHANNELS
-- =============================================
PRINT 'Inserting Communication Channels...';

SET IDENTITY_INSERT [crm].[CommunicationChannels] ON;

INSERT INTO [crm].[CommunicationChannels] (communicationChannelId, communicationChannelKey, communicationChannelName, description, enabled)
VALUES
    (1, 'EMAIL', 'Email', 'Email communication', 1),
    (2, 'SMS', 'SMS', 'Text message', 1),
    (3, 'PHONE', 'Phone', 'Phone call', 1),
    (4, 'WHATSAPP', 'WhatsApp', 'WhatsApp message', 1),
    (5, 'PUSH', 'Push Notification', 'Push notification', 1),
    (6, 'IN_APP', 'In-App Message', 'In-app messaging', 1);

SET IDENTITY_INSERT [crm].[CommunicationChannels] OFF;

PRINT '  ✓ Inserted 6 communication channels';

-- =============================================
-- GDPR REQUEST TYPES
-- =============================================
PRINT 'Inserting GDPR Request Types...';

SET IDENTITY_INSERT [crm].[GdprRequestTypes] ON;

INSERT INTO [crm].[GdprRequestTypes] (gdprRequestTypeId, gdprRequestTypeKey, gdprRequestTypeName, description, enabled)
VALUES
    (1, 'ACCESS', 'Data Access Request', 'Request copy of data', 1),
    (2, 'RECTIFICATION', 'Data Rectification', 'Correct inaccurate data', 1),
    (3, 'ERASURE', 'Right to be Forgotten', 'Delete personal data', 1),
    (4, 'PORTABILITY', 'Data Portability', 'Export data', 1),
    (5, 'OBJECTION', 'Object to Processing', 'Object to data processing', 1),
    (6, 'RESTRICTION', 'Restrict Processing', 'Restrict processing', 1);

SET IDENTITY_INSERT [crm].[GdprRequestTypes] OFF;

PRINT '  ✓ Inserted 6 GDPR request types';

-- =============================================
-- GDPR REQUEST STATUSES
-- =============================================
PRINT 'Inserting GDPR Request Statuses...';

SET IDENTITY_INSERT [crm].[GdprRequestStatuses] ON;

INSERT INTO [crm].[GdprRequestStatuses] (gdprRequestStatusId, gdprRequeststatusKey, gdprRequestStatusName, description, enabled)
VALUES
    (1, 'PENDING', 'Pending', 'Request received', 1),
    (2, 'IN_PROGRESS', 'In Progress', 'Being processed', 1),
    (3, 'COMPLETED', 'Completed', 'Request completed', 1),
    (4, 'REJECTED', 'Rejected', 'Request rejected', 1),
    (5, 'CANCELED', 'Canceled', 'Request canceled', 1);

SET IDENTITY_INSERT [crm].[GdprRequestStatuses] OFF;

PRINT '  ✓ Inserted 5 GDPR request statuses';

-- =============================================
-- API REQUEST RESULT STATUSES
-- =============================================
PRINT 'Inserting API Request Result Statuses...';

SET IDENTITY_INSERT [crm].[ApiRequestResultStatuses] ON;

INSERT INTO [crm].[ApiRequestResultStatuses] (apiRequestResultStatusId, resultStatusKey, resultStatusName, description, enabled)
VALUES
    (1, 'SUCCESS', 'Success', 'Request successful', 1),
    (2, 'ERROR', 'Error', 'Request error', 1),
    (3, 'TIMEOUT', 'Timeout', 'Request timeout', 1),
    (4, 'RATE_LIMITED', 'Rate Limited', 'Rate limit exceeded', 1),
    (5, 'AUTH_FAILED', 'Auth Failed', 'Authentication failed', 1),
    (6, 'INVALID_REQUEST', 'Invalid Request', 'Invalid request', 1);

SET IDENTITY_INSERT [crm].[ApiRequestResultStatuses] OFF;

PRINT '  ✓ Inserted 6 API request result statuses';

PRINT '';
PRINT '========================================';
PRINT 'LEAD CATALOGS SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT '';

GO
