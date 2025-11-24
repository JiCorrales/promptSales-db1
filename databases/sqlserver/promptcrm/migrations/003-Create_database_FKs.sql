-- =============================================
-- PromptCRM - Named Foreign Key Constraints
-- =============================================
-- Author: Alberto Bofi
-- Date: 2025-11-21
-- Purpose: Replace anonymous FKs with named constraints
--
-- WHY NAMED CONSTRAINTS:
-- - Easier troubleshooting (clear error messages)
-- - Better documentation
-- - Easier to drop/recreate during migrations
-- - Industry best practice
--
-- NAMING CONVENTION:
-- FK_[ChildTable]_[ParentTable]_[ColumnName]
-- Example: FK_Leads_Subscribers_subscriberId
-- =============================================

USE PromptCRM;
GO

PRINT '========================================';
PRINT 'DROPPING ANONYMOUS FOREIGN KEYS';
PRINT '========================================';
PRINT '';

-- First, drop all existing anonymous FKs
-- (This section would list all the CONSTRAINT names to drop)
-- For safety, we'll add them as named constraints instead

PRINT 'Dropping existing Foreign Keys...';

-- Get all existing FKs
DECLARE @SQL NVARCHAR(MAX) = '';

SELECT @SQL = @SQL + 'ALTER TABLE [' + OBJECT_SCHEMA_NAME(parent_object_id) + '].[' + OBJECT_NAME(parent_object_id) +
              '] DROP CONSTRAINT [' + name + '];' + CHAR(13)
FROM sys.foreign_keys
WHERE OBJECT_SCHEMA_NAME(parent_object_id) = 'crm'
  AND name LIKE '%___%';  -- Only drop auto-generated names

IF LEN(@SQL) > 0
BEGIN
    EXEC sp_executesql @SQL;
    PRINT '  ✓ Dropped existing anonymous FK constraints';
END
ELSE
BEGIN
    PRINT '  ✓ No anonymous FKs to drop';
END
GO

PRINT '';
PRINT '========================================';
PRINT 'ADDING NAMED FOREIGN KEY CONSTRAINTS';
PRINT '========================================';
PRINT '';

-- =============================================
-- SECTION 1: GEOGRAPHIC HIERARCHY
-- =============================================
PRINT 'Section 1: Geographic hierarchy...';

ALTER TABLE [crm].[States]
ADD CONSTRAINT FK_States_Countries_countryId
FOREIGN KEY ([countryId]) REFERENCES [crm].[Countries] ([countryId])
ON DELETE NO ACTION
ON UPDATE NO ACTION;
PRINT '  ✓ FK_States_Countries_countryId';
GO

ALTER TABLE [crm].[Cities]
ADD CONSTRAINT FK_Cities_States_stateId
FOREIGN KEY ([stateId]) REFERENCES [crm].[States] ([stateId])
ON DELETE NO ACTION
ON UPDATE NO ACTION;
PRINT '  ✓ FK_Cities_States_stateId';
GO

ALTER TABLE [crm].[Addresses]
ADD CONSTRAINT FK_Addresses_Cities_cityId
FOREIGN KEY ([cityId]) REFERENCES [crm].[Cities] ([cityId])
ON DELETE NO ACTION
ON UPDATE NO ACTION;
PRINT '  ✓ FK_Addresses_Cities_cityId';
GO

-- =============================================
-- SECTION 2: USER MANAGEMENT
-- =============================================
PRINT '';
PRINT 'Section 2: User management...';

ALTER TABLE [crm].[Users]
ADD CONSTRAINT FK_Users_UserStatuses_userStatusId
FOREIGN KEY ([userStatusId]) REFERENCES [crm].[UserStatuses] ([userStatusId])
ON DELETE NO ACTION
ON UPDATE NO ACTION;
PRINT '  ✓ FK_Users_UserStatuses_userStatusId';
GO

ALTER TABLE [crm].[UserLoginHistory]
ADD CONSTRAINT FK_UserLoginHistory_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE CASCADE;  -- Delete history when user is deleted
PRINT '  ✓ FK_UserLoginHistory_Users_userId';
GO

ALTER TABLE [crm].[UserExternalIds]
ADD CONSTRAINT FK_UserExternalIds_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE CASCADE;
PRINT '  ✓ FK_UserExternalIds_Users_userId';
GO

-- =============================================
-- SECTION 3: ROLES & PERMISSIONS (RBAC)
-- =============================================
PRINT '';
PRINT 'Section 3: Roles and permissions (RBAC)...';

ALTER TABLE [crm].[UserRoles]
ADD CONSTRAINT FK_UserRoles_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;  -- Delete roles when subscriber is deleted
PRINT '  ✓ FK_UserRoles_Subscribers_subscriberId';
GO

ALTER TABLE [crm].[RolesPerUser]
ADD CONSTRAINT FK_RolesPerUser_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE CASCADE;
PRINT '  ✓ FK_RolesPerUser_Users_userId';
GO

ALTER TABLE [crm].[RolesPerUser]
ADD CONSTRAINT FK_RolesPerUser_UserRoles_userRoleId
FOREIGN KEY ([userRoleId]) REFERENCES [crm].[UserRoles] ([userRoleId])
ON DELETE CASCADE;
PRINT '  ✓ FK_RolesPerUser_UserRoles_userRoleId';
GO

ALTER TABLE [crm].[PermissionPerRole]
ADD CONSTRAINT FK_PermissionPerRole_UserRoles_userRoleId
FOREIGN KEY ([userRoleId]) REFERENCES [crm].[UserRoles] ([userRoleId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PermissionPerRole_UserRoles_userRoleId';
GO

ALTER TABLE [crm].[PermissionPerRole]
ADD CONSTRAINT FK_PermissionPerRole_Permissions_permissionId
FOREIGN KEY ([permissionId]) REFERENCES [crm].[Permissions] ([permissionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PermissionPerRole_Permissions_permissionId';
GO

ALTER TABLE [crm].[PermissionsPerUser]
ADD CONSTRAINT FK_PermissionsPerUser_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PermissionsPerUser_Users_userId';
GO

ALTER TABLE [crm].[PermissionsPerUser]
ADD CONSTRAINT FK_PermissionsPerUser_Permissions_permissionId
FOREIGN KEY ([permissionId]) REFERENCES [crm].[Permissions] ([permissionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PermissionsPerUser_Permissions_permissionId';
GO

-- =============================================
-- SECTION 4: LOGGING & AUDIT
-- =============================================
PRINT '';
PRINT 'Section 4: Logging and audit...';

ALTER TABLE [crm].[logs]
ADD CONSTRAINT FK_logs_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE NO ACTION;  -- Keep logs even if user deleted
PRINT '  ✓ FK_logs_Users_userId';
GO

ALTER TABLE [crm].[logs]
ADD CONSTRAINT FK_logs_logTypes_logTypeId
FOREIGN KEY ([logTypeId]) REFERENCES [crm].[logTypes] ([logTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_logs_logTypes_logTypeId';
GO

ALTER TABLE [crm].[logs]
ADD CONSTRAINT FK_logs_logLevels_logLevelId
FOREIGN KEY ([logLevelId]) REFERENCES [crm].[logLevels] ([logLevelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_logs_logLevels_logLevelId';
GO

ALTER TABLE [crm].[logs]
ADD CONSTRAINT FK_logs_logSources_logSourceId
FOREIGN KEY ([logSourceId]) REFERENCES [crm].[logSources] ([logSourceId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_logs_logSources_logSourceId';
GO

ALTER TABLE [crm].[logs]
ADD CONSTRAINT FK_logs_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_logs_Subscribers_subscriberId';
GO

-- =============================================
-- SECTION 5: SUBSCRIPTION FEATURES & PLANS
-- =============================================
PRINT '';
PRINT 'Section 5: Subscription features and plans...';

ALTER TABLE [crm].[SubscriptionFeatures]
ADD CONSTRAINT FK_SubscriptionFeatures_SubscriptionFeatureTypes_subscriptionFeatureTypeId
FOREIGN KEY ([subscriptionFeatureTypeId]) REFERENCES [crm].[SubscriptionFeatureTypes] ([subscriptionFeatureTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionFeatures_SubscriptionFeatureTypes';
GO

ALTER TABLE [crm].[FeaturesPerPlan]
ADD CONSTRAINT FK_FeaturesPerPlan_SubscriptionPlans_suscriptionPlanId
FOREIGN KEY ([suscriptionPlanId]) REFERENCES [crm].[SubscriptionPlans] ([subscriptionPlanId])
ON DELETE CASCADE;
PRINT '  ✓ FK_FeaturesPerPlan_SubscriptionPlans';
GO

ALTER TABLE [crm].[FeaturesPerPlan]
ADD CONSTRAINT FK_FeaturesPerPlan_SubscriptionFeatures_subscriptionFeatureId
FOREIGN KEY ([subscriptionFeatureId]) REFERENCES [crm].[SubscriptionFeatures] ([subscriptionFeatureId])
ON DELETE CASCADE;
PRINT '  ✓ FK_FeaturesPerPlan_SubscriptionFeatures';
GO

ALTER TABLE [crm].[PaymentSchedulesPerPlan]
ADD CONSTRAINT FK_PaymentSchedulesPerPlan_SubscriptionPlans_suscriptionPlanId
FOREIGN KEY ([suscriptionPlanId]) REFERENCES [crm].[SubscriptionPlans] ([subscriptionPlanId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PaymentSchedulesPerPlan_SubscriptionPlans';
GO

ALTER TABLE [crm].[PaymentSchedulesPerPlan]
ADD CONSTRAINT FK_PaymentSchedulesPerPlan_PaymentScheduleTypes_paymentScheduleTypeId
FOREIGN KEY ([paymentScheduleTypeId]) REFERENCES [crm].[PaymentScheduleTypes] ([paymentScheduleTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_PaymentSchedulesPerPlan_PaymentScheduleTypes';
GO

ALTER TABLE [crm].[PaymentSchedulesPerPlan]
ADD CONSTRAINT FK_PaymentSchedulesPerPlan_Currencies_currencyId
FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_PaymentSchedulesPerPlan_Currencies';
GO

-- =============================================
-- SECTION 6: SUBSCRIBERS & USERS
-- =============================================
PRINT '';
PRINT 'Section 6: Subscribers and users...';

ALTER TABLE [crm].[UsersPerSubscriber]
ADD CONSTRAINT FK_UsersPerSubscriber_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE CASCADE;
PRINT '  ✓ FK_UsersPerSubscriber_Users';
GO

ALTER TABLE [crm].[UsersPerSubscriber]
ADD CONSTRAINT FK_UsersPerSubscriber_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_UsersPerSubscriber_Subscribers';
GO

ALTER TABLE [crm].[AddressesPerSubscriber]
ADD CONSTRAINT FK_AddressesPerSubscriber_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_AddressesPerSubscriber_Subscribers';
GO

ALTER TABLE [crm].[AddressesPerSubscriber]
ADD CONSTRAINT FK_AddressesPerSubscriber_Addresses_addressId
FOREIGN KEY ([addressId]) REFERENCES [crm].[Addresses] ([addressId])
ON DELETE CASCADE;
PRINT '  ✓ FK_AddressesPerSubscriber_Addresses';
GO

-- =============================================
-- SECTION 7: SUBSCRIPTIONS & BILLING
-- =============================================
PRINT '';
PRINT 'Section 7: Subscriptions and billing...';

ALTER TABLE [crm].[Subscriptions]
ADD CONSTRAINT FK_Subscriptions_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;  -- Keep subscription history
PRINT '  ✓ FK_Subscriptions_Subscribers';
GO

ALTER TABLE [crm].[Subscriptions]
ADD CONSTRAINT FK_Subscriptions_SubscriptionPlans_subscriptionPlanId
FOREIGN KEY ([subscriptionPlanId]) REFERENCES [crm].[SubscriptionPlans] ([subscriptionPlanId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Subscriptions_SubscriptionPlans';
GO

ALTER TABLE [crm].[Subscriptions]
ADD CONSTRAINT FK_Subscriptions_PaymentMethods_paymentMethodId
FOREIGN KEY ([paymentMethodId]) REFERENCES [crm].[PaymentMethods] ([paymentMethodId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Subscriptions_PaymentMethods';
GO

ALTER TABLE [crm].[Subscriptions]
ADD CONSTRAINT FK_Subscriptions_SubscriptionStatuses_subscriptionStatusId
FOREIGN KEY ([subscriptionStatusId]) REFERENCES [crm].[SubscriptionStatuses] ([subscriptionStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Subscriptions_SubscriptionStatuses';
GO

ALTER TABLE [crm].[SubscriptionHistory]
ADD CONSTRAINT FK_SubscriptionHistory_Subscriptions_subscriptionId
FOREIGN KEY ([subscriptionId]) REFERENCES [crm].[Subscriptions] ([subscriptionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_SubscriptionHistory_Subscriptions';
GO

ALTER TABLE [crm].[SubscriptionHistory]
ADD CONSTRAINT FK_SubscriptionHistory_OldPlan_oldPlanId
FOREIGN KEY ([oldPlanId]) REFERENCES [crm].[SubscriptionPlans] ([subscriptionPlanId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionHistory_OldPlan';
GO

ALTER TABLE [crm].[SubscriptionHistory]
ADD CONSTRAINT FK_SubscriptionHistory_NewPlan_newPlanId
FOREIGN KEY ([newPlanId]) REFERENCES [crm].[SubscriptionPlans] ([subscriptionPlanId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionHistory_NewPlan';
GO

ALTER TABLE [crm].[SubscriptionHistory]
ADD CONSTRAINT FK_SubscriptionHistory_OldStatus_oldStatusId
FOREIGN KEY ([oldStatusId]) REFERENCES [crm].[SubscriptionStatuses] ([subscriptionStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionHistory_OldStatus';
GO

ALTER TABLE [crm].[SubscriptionHistory]
ADD CONSTRAINT FK_SubscriptionHistory_NewStatus_newStatusId
FOREIGN KEY ([newStatusId]) REFERENCES [crm].[SubscriptionStatuses] ([subscriptionStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionHistory_NewStatus';
GO

ALTER TABLE [crm].[SubscriptionFeatureUsage]
ADD CONSTRAINT FK_SubscriptionFeatureUsage_Subscriptions_subscriptionId
FOREIGN KEY ([subscriptionId]) REFERENCES [crm].[Subscriptions] ([subscriptionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_SubscriptionFeatureUsage_Subscriptions';
GO

ALTER TABLE [crm].[SubscriptionFeatureUsage]
ADD CONSTRAINT FK_SubscriptionFeatureUsage_SubscriptionFeatures_subscriptionFeatureId
FOREIGN KEY ([subscriptionFeatureId]) REFERENCES [crm].[SubscriptionFeatures] ([subscriptionFeatureId])
ON DELETE CASCADE;
PRINT '  ✓ FK_SubscriptionFeatureUsage_SubscriptionFeatures';
GO

ALTER TABLE [crm].[SubscriptionBillingConfigs]
ADD CONSTRAINT FK_SubscriptionBillingConfigs_Subscriptions_subscriptionId
FOREIGN KEY ([subscriptionId]) REFERENCES [crm].[Subscriptions] ([subscriptionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_SubscriptionBillingConfigs_Subscriptions';
GO

ALTER TABLE [crm].[SubscriptionBillingConfigs]
ADD CONSTRAINT FK_SubscriptionBillingConfigs_PaymentScheduleTypes_paymentScheduleTypeId
FOREIGN KEY ([paymentScheduleTypeId]) REFERENCES [crm].[PaymentScheduleTypes] ([paymentScheduleTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionBillingConfigs_PaymentScheduleTypes';
GO

ALTER TABLE [crm].[SubscriptionBillingConfigs]
ADD CONSTRAINT FK_SubscriptionBillingConfigs_Currencies_currencyId
FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionBillingConfigs_Currencies';
GO

ALTER TABLE [crm].[SubscriptionBillingCycles]
ADD CONSTRAINT FK_SubscriptionBillingCycles_Subscriptions_subscriptionId
FOREIGN KEY ([subscriptionId]) REFERENCES [crm].[Subscriptions] ([subscriptionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_SubscriptionBillingCycles_Subscriptions';
GO

ALTER TABLE [crm].[SubscriptionBillingCycles]
ADD CONSTRAINT FK_SubscriptionBillingCycles_BillingConfigs_billingConfigId
FOREIGN KEY ([billingConfigId]) REFERENCES [crm].[SubscriptionBillingConfigs] ([subscriptionBillingConfigId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionBillingCycles_BillingConfigs';
GO

ALTER TABLE [crm].[SubscriptionBillingCycles]
ADD CONSTRAINT FK_SubscriptionBillingCycles_Transactions_transactionId
FOREIGN KEY ([transactionId]) REFERENCES [crm].[Transactions] ([transactionId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_SubscriptionBillingCycles_Transactions';
GO

-- =============================================
-- SECTION 8: TRANSACTIONS & PAYMENTS
-- =============================================
PRINT '';
PRINT 'Section 8: Transactions and payments...';

ALTER TABLE [crm].[Transactions]
ADD CONSTRAINT FK_Transactions_TransactionTypes_transactionTypeId
FOREIGN KEY ([transactionTypeId]) REFERENCES [crm].[TransactionTypes] ([transactionTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Transactions_TransactionTypes';
GO

ALTER TABLE [crm].[Transactions]
ADD CONSTRAINT FK_Transactions_PaymentMethods_paymentMethodId
FOREIGN KEY ([paymentMethodId]) REFERENCES [crm].[PaymentMethods] ([paymentMethodId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Transactions_PaymentMethods';
GO

ALTER TABLE [crm].[Transactions]
ADD CONSTRAINT FK_Transactions_Currencies_currencyId
FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Transactions_Currencies';
GO

ALTER TABLE [crm].[Transactions]
ADD CONSTRAINT FK_Transactions_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Transactions_Subscribers';
GO

ALTER TABLE [crm].[Transactions]
ADD CONSTRAINT FK_Transactions_TransactionStatuses_transactionStatusId
FOREIGN KEY ([transactionStatusId]) REFERENCES [crm].[TransactionStatuses] ([transactionStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Transactions_TransactionStatuses';
GO

ALTER TABLE [crm].[TransactionStatusHistory]
ADD CONSTRAINT FK_TransactionStatusHistory_Transactions_transactionId
FOREIGN KEY ([transactionId]) REFERENCES [crm].[Transactions] ([transactionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_TransactionStatusHistory_Transactions';
GO

ALTER TABLE [crm].[TransactionStatusHistory]
ADD CONSTRAINT FK_TransactionStatusHistory_TransactionStatuses_transactionStatusId
FOREIGN KEY ([transactionStatusId]) REFERENCES [crm].[TransactionStatuses] ([transactionStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_TransactionStatusHistory_TransactionStatuses';
GO

ALTER TABLE [crm].[TransactionsExternalIds]
ADD CONSTRAINT FK_TransactionsExternalIds_Transactions_transactionId
FOREIGN KEY ([transactionId]) REFERENCES [crm].[Transactions] ([transactionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_TransactionsExternalIds_Transactions';
GO

ALTER TABLE [crm].[PaymentMethods]
ADD CONSTRAINT FK_PaymentMethods_PaymentMethodTypes_paymentMethodTypeId
FOREIGN KEY ([paymentMethodTypeId]) REFERENCES [crm].[PaymentMethodTypes] ([paymentMethodTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_PaymentMethods_PaymentMethodTypes';
GO

ALTER TABLE [crm].[PaymentMethodsExternalIds]
ADD CONSTRAINT FK_PaymentMethodsExternalIds_PaymentMethods_paymentMethodId
FOREIGN KEY ([paymentMethodId]) REFERENCES [crm].[PaymentMethods] ([paymentMethodId])
ON DELETE CASCADE;
PRINT '  ✓ FK_PaymentMethodsExternalIds_PaymentMethods';
GO

-- =============================================
-- SECTION 9: LEADS & SOURCES
-- =============================================
PRINT '';
PRINT 'Section 9: Leads and sources...';

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_Countries_countryId
FOREIGN KEY ([countryId]) REFERENCES [crm].[Countries] ([countryId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_Countries';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_States_StateId
FOREIGN KEY ([StateId]) REFERENCES [crm].[States] ([stateId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_States';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_Cities_cityId
FOREIGN KEY ([cityId]) REFERENCES [crm].[Cities] ([cityId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_Cities';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_Subscribers';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_DemographicRaces_demographicRaceId
FOREIGN KEY ([demographicRaceId]) REFERENCES [crm].[DemographicRaces] ([demographicRaceId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_DemographicRaces';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_DemographicGenders_demographicGenderId
FOREIGN KEY ([demographicGenderId]) REFERENCES [crm].[DemographicGenders] ([demographicGenderId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_DemographicGenders';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_DemographicEthnicities_demographicEthnicityId
FOREIGN KEY ([demographicEthnicityId]) REFERENCES [crm].[DemographicEthnicities] ([demographicEthnicityId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_DemographicEthnicities';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_LeadStatus_leadStatusId
FOREIGN KEY ([leadStatusId]) REFERENCES [crm].[LeadStatus] ([leadStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_LeadStatus';
GO

ALTER TABLE [crm].[Leads]
ADD CONSTRAINT FK_Leads_LeadTiers_leadTierId
FOREIGN KEY ([leadTierId]) REFERENCES [crm].[LeadTiers] ([leadTierId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Leads_LeadTiers';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadSources_Leads';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_LeadSourceTypes_leadSourceTypeId
FOREIGN KEY ([leadSourceTypeId]) REFERENCES [crm].[LeadSourceTypes] ([leadSourceTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_LeadSourceTypes';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_LeadSourceSystems_leadSourceSystemId
FOREIGN KEY ([leadSourceSystemId]) REFERENCES [crm].[LeadSourceSystems] ([leadSourceSystemId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_LeadSourceSystems';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_LeadMediums_leadMediumId
FOREIGN KEY ([leadMediumId]) REFERENCES [crm].[LeadMediums] ([leadMediumId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_LeadMediums';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_LeadOriginChannels_leadOriginChannelId
FOREIGN KEY ([leadOriginChannelId]) REFERENCES [crm].[LeadOriginChannels] ([leadOriginChannelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_LeadOriginChannels';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_DeviceTypes_deviceTypeId
FOREIGN KEY ([deviceTypeId]) REFERENCES [crm].[DeviceTypes] ([deviceTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_DeviceTypes';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_DevicePlatforms_devicePlatformId
FOREIGN KEY ([devicePlatformId]) REFERENCES [crm].[DevicePlatforms] ([devicePlatformId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_DevicePlatforms';
GO

ALTER TABLE [crm].[LeadSources]
ADD CONSTRAINT FK_LeadSources_Browsers_browserId
FOREIGN KEY ([browserId]) REFERENCES [crm].[Browsers] ([browserId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadSources_Browsers';
GO

ALTER TABLE [crm].[LeadExternalIds]
ADD CONSTRAINT FK_LeadExternalIds_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadExternalIds_Leads';
GO

-- =============================================
-- SECTION 10: LEAD EVENTS & TRACKING
-- =============================================
PRINT '';
PRINT 'Section 10: Lead events and tracking...';

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_Countries_countryId
FOREIGN KEY ([countryId]) REFERENCES [crm].[Countries] ([countryId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_Countries';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_States_StateId
FOREIGN KEY ([StateId]) REFERENCES [crm].[States] ([stateId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_States';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_Cities_cityId
FOREIGN KEY ([cityId]) REFERENCES [crm].[Cities] ([cityId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_Cities';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadEvents_Leads';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_LeadSources_leadSourceId
FOREIGN KEY ([leadSourceId]) REFERENCES [crm].[LeadSources] ([leadSourceId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_LeadSources';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_LeadMediums_mediumId
FOREIGN KEY ([mediumId]) REFERENCES [crm].[LeadMediums] ([leadMediumId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_LeadMediums';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_LeadOriginChannels_originChannelId
FOREIGN KEY ([originChannelId]) REFERENCES [crm].[LeadOriginChannels] ([leadOriginChannelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_LeadOriginChannels';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_DeviceTypes_deviceTypeId
FOREIGN KEY ([deviceTypeId]) REFERENCES [crm].[DeviceTypes] ([deviceTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_DeviceTypes';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_DevicePlatforms_devicePlatformId
FOREIGN KEY ([devicePlatformId]) REFERENCES [crm].[DevicePlatforms] ([devicePlatformId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_DevicePlatforms';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_Browsers_browserId
FOREIGN KEY ([browserId]) REFERENCES [crm].[Browsers] ([browserId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_Browsers';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_LeadEventTypes_leadEventTypeId
FOREIGN KEY ([leadEventTypeId]) REFERENCES [crm].[LeadEventTypes] ([leadEventTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_LeadEventTypes';
GO

ALTER TABLE [crm].[LeadEvents]
ADD CONSTRAINT FK_LeadEvents_LeadEventSources_leadEventSourceId
FOREIGN KEY ([leadEventSourceId]) REFERENCES [crm].[LeadEventSources] ([leadEventSourceId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadEvents_LeadEventSources';
GO

-- =============================================
-- SECTION 11: LEAD TAGS & CONVERSIONS
-- =============================================
PRINT '';
PRINT 'Section 11: Lead tags and conversions...';

ALTER TABLE [crm].[LeadTagsCatalog]
ADD CONSTRAINT FK_LeadTagsCatalog_LeadTagCategories_leadCategoryTypeId
FOREIGN KEY ([leadCategoryTypeId]) REFERENCES [crm].[LeadTagCategories] ([leadCategoryId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadTagsCatalog_LeadTagCategories';
GO

ALTER TABLE [crm].[LeadTags]
ADD CONSTRAINT FK_LeadTags_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadTags_Leads';
GO

ALTER TABLE [crm].[LeadTags]
ADD CONSTRAINT FK_LeadTags_LeadEvents_leadEventId
FOREIGN KEY ([leadEventId]) REFERENCES [crm].[LeadEvents] ([leadEventId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadTags_LeadEvents';
GO

ALTER TABLE [crm].[LeadTags]
ADD CONSTRAINT FK_LeadTags_LeadTagsCatalog_leadTagCatalogId
FOREIGN KEY ([leadTagCatalogId]) REFERENCES [crm].[LeadTagsCatalog] ([leadTagCatalogId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadTags_LeadTagsCatalog';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadConversions_Leads';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_LeadSources_leadSourceId
FOREIGN KEY ([leadSourceId]) REFERENCES [crm].[LeadSources] ([leadSourceId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadConversions_LeadSources';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_LeadEvents_leadEventId
FOREIGN KEY ([leadEventId]) REFERENCES [crm].[LeadEvents] ([leadEventId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadConversions_LeadEvents';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_LeadConversionTypes_leadConversionTypeId
FOREIGN KEY ([leadConversionTypeId]) REFERENCES [crm].[LeadConversionTypes] ([leadConversionTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadConversions_LeadConversionTypes';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_AttributionModels_attributionModelId
FOREIGN KEY ([attributionModelId]) REFERENCES [crm].[AttributionModels] ([attributionModelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadConversions_AttributionModels';
GO

ALTER TABLE [crm].[LeadConversions]
ADD CONSTRAINT FK_LeadConversions_Currencies_currencyId
FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadConversions_Currencies';
GO

-- =============================================
-- SECTION 12: CLIENTS
-- =============================================
PRINT '';
PRINT 'Section 12: Clients...';

ALTER TABLE [crm].[Clients]
ADD CONSTRAINT FK_Clients_ClientStatuses_clientStatusId
FOREIGN KEY ([clientStatusId]) REFERENCES [crm].[ClientStatuses] ([clientStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Clients_ClientStatuses';
GO

ALTER TABLE [crm].[Clients]
ADD CONSTRAINT FK_Clients_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Clients_Subscribers';
GO

ALTER TABLE [crm].[Clients]
ADD CONSTRAINT FK_Clients_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Clients_Leads';
GO

ALTER TABLE [crm].[Clients]
ADD CONSTRAINT FK_Clients_Currencies_currencyId
FOREIGN KEY ([currencyId]) REFERENCES [crm].[Currencies] ([currencyId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_Clients_Currencies';
GO

ALTER TABLE [crm].[ClientExternalIds]
ADD CONSTRAINT FK_ClientExternalIds_Clients_clientId
FOREIGN KEY ([clientId]) REFERENCES [crm].[Clients] ([clientId])
ON DELETE CASCADE;
PRINT '  ✓ FK_ClientExternalIds_Clients';
GO

ALTER TABLE [crm].[ClientProfiles]
ADD CONSTRAINT FK_ClientProfiles_Clients_clientId
FOREIGN KEY ([clientId]) REFERENCES [crm].[Clients] ([clientId])
ON DELETE CASCADE;
PRINT '  ✓ FK_ClientProfiles_Clients';
GO

ALTER TABLE [crm].[ClientProfiles]
ADD CONSTRAINT FK_ClientProfiles_LeadMediums_preferredMediumId
FOREIGN KEY ([preferredMediumId]) REFERENCES [crm].[LeadMediums] ([leadMediumId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ClientProfiles_LeadMediums';
GO

ALTER TABLE [crm].[ClientProfiles]
ADD CONSTRAINT FK_ClientProfiles_LeadOriginChannels_preferredChannelId
FOREIGN KEY ([preferredChannelId]) REFERENCES [crm].[LeadOriginChannels] ([leadOriginChannelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ClientProfiles_LeadOriginChannels';
GO

ALTER TABLE [crm].[ClientProfiles]
ADD CONSTRAINT FK_ClientProfiles_DeviceTypes_mostFrequentDeviceTypeId
FOREIGN KEY ([mostFrequentDeviceTypeId]) REFERENCES [crm].[DeviceTypes] ([deviceTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ClientProfiles_DeviceTypes';
GO

-- =============================================
-- SECTION 13: GDPR & COMMUNICATION
-- =============================================
PRINT '';
PRINT 'Section 13: GDPR and communication...';

ALTER TABLE [crm].[LeadCommunicationPreferences]
ADD CONSTRAINT FK_LeadCommunicationPreferences_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadCommunicationPreferences_Leads';
GO

ALTER TABLE [crm].[LeadCommunicationPreferences]
ADD CONSTRAINT FK_LeadCommunicationPreferences_CommunicationChannels_communicationChannelId
FOREIGN KEY ([communicationChannelId]) REFERENCES [crm].[CommunicationChannels] ([communicationChannelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadCommunicationPreferences_CommunicationChannels';
GO

ALTER TABLE [crm].[LeadGdprRequests]
ADD CONSTRAINT FK_LeadGdprRequests_Users_processedByUserId
FOREIGN KEY ([processedByUserId]) REFERENCES [crm].[Users] ([userId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadGdprRequests_Users';
GO

ALTER TABLE [crm].[LeadGdprRequests]
ADD CONSTRAINT FK_LeadGdprRequests_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadGdprRequests_Leads';
GO

ALTER TABLE [crm].[LeadGdprRequests]
ADD CONSTRAINT FK_LeadGdprRequests_GdprRequestTypes_gdprRequestTypeId
FOREIGN KEY ([gdprRequestTypeId]) REFERENCES [crm].[GdprRequestTypes] ([gdprRequestTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadGdprRequests_GdprRequestTypes';
GO

ALTER TABLE [crm].[LeadGdprRequests]
ADD CONSTRAINT FK_LeadGdprRequests_GdprRequestStatuses_gdprRequestStatusId
FOREIGN KEY ([gdprRequestStatusId]) REFERENCES [crm].[GdprRequestStatuses] ([gdprRequestStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadGdprRequests_GdprRequestStatuses';
GO

-- =============================================
-- SECTION 14: FUNNELS & AUTOMATION
-- =============================================
PRINT '';
PRINT 'Section 14: Funnels and automation...';

ALTER TABLE [crm].[Funnels]
ADD CONSTRAINT FK_Funnels_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_Funnels_Subscribers';
GO

ALTER TABLE [crm].[FunnelStages]
ADD CONSTRAINT FK_FunnelStages_Funnels_funnelId
FOREIGN KEY ([funnelId]) REFERENCES [crm].[Funnels] ([funnelId])
ON DELETE CASCADE;
PRINT '  ✓ FK_FunnelStages_Funnels';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_Users_triggerUserId
FOREIGN KEY ([triggerUserId]) REFERENCES [crm].[Users] ([userId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_Users';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadFunnelProgress_Leads';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_LeadEvents_triggerEventId
FOREIGN KEY ([triggerEventId]) REFERENCES [crm].[LeadEvents] ([leadEventId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_LeadEvents';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_FunnelStages_funnelStageId
FOREIGN KEY ([funnelStageId]) REFERENCES [crm].[FunnelStages] ([funnelStageId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_FunnelStages';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_TriggerCauseTypes_triggerCauseTypeId
FOREIGN KEY ([triggerCauseTypeId]) REFERENCES [crm].[TriggerCauseTypes] ([triggerCauseTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_TriggerCauseTypes';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_TriggerRules_triggerRuleId
FOREIGN KEY ([triggerRuleId]) REFERENCES [crm].[TriggerRules] ([triggerRuleId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_TriggerRules';
GO

ALTER TABLE [crm].[LeadFunnelProgress]
ADD CONSTRAINT FK_LeadFunnelProgress_Funnels_funnelId
FOREIGN KEY ([funnelId]) REFERENCES [crm].[Funnels] ([funnelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_LeadFunnelProgress_Funnels';
GO

ALTER TABLE [crm].[TriggerRules]
ADD CONSTRAINT FK_TriggerRules_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_TriggerRules_Subscribers';
GO

ALTER TABLE [crm].[ExternalWorkflows]
ADD CONSTRAINT FK_ExternalWorkflows_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_ExternalWorkflows_Subscribers';
GO

ALTER TABLE [crm].[ExternalWorkflows]
ADD CONSTRAINT FK_ExternalWorkflows_ExternalSystems_externalSystemId
FOREIGN KEY ([externalSystemId]) REFERENCES [crm].[ExternalSystems] ([externalSystemId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ExternalWorkflows_ExternalSystems';
GO

ALTER TABLE [crm].[AutomationActions]
ADD CONSTRAINT FK_AutomationActions_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_AutomationActions_Subscribers';
GO

ALTER TABLE [crm].[AutomationActions]
ADD CONSTRAINT FK_AutomationActions_AutomationActionTypes_automationActionTypeId
FOREIGN KEY ([automationActionTypeId]) REFERENCES [crm].[AutomationActionTypes] ([automationActionTypeId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationActions_AutomationActionTypes';
GO

ALTER TABLE [crm].[AutomationActions]
ADD CONSTRAINT FK_AutomationActions_ExternalWorkflows_externalWorkflowId
FOREIGN KEY ([externalWorkflowId]) REFERENCES [crm].[ExternalWorkflows] ([externalWorkflowId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationActions_ExternalWorkflows';
GO

ALTER TABLE [crm].[TriggerRuleActions]
ADD CONSTRAINT FK_TriggerRuleActions_TriggerRules_triggerRuleId
FOREIGN KEY ([triggerRuleId]) REFERENCES [crm].[TriggerRules] ([triggerRuleId])
ON DELETE CASCADE;
PRINT '  ✓ FK_TriggerRuleActions_TriggerRules';
GO

ALTER TABLE [crm].[TriggerRuleActions]
ADD CONSTRAINT FK_TriggerRuleActions_AutomationActions_automationActionId
FOREIGN KEY ([automationActionId]) REFERENCES [crm].[AutomationActions] ([automationActionId])
ON DELETE NO ACTION; -- Cambio crítico: De CASCADE a NO ACTION

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_AutomationActions_automationActionId
FOREIGN KEY ([automationActionId]) REFERENCES [crm].[AutomationActions] ([automationActionId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_AutomationActions';
GO

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_Subscribers';
GO

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_LeadFunnelProgress_leadFunnelProgressId
FOREIGN KEY ([leadFunnelProgressId]) REFERENCES [crm].[LeadFunnelProgress] ([leadFunnelProgressId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_LeadFunnelProgress';
GO

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_Leads';
GO

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_TriggerRules_triggerRuleId
FOREIGN KEY ([triggerRuleId]) REFERENCES [crm].[TriggerRules] ([triggerRuleId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_TriggerRules';
GO

ALTER TABLE [crm].[AutomationExecutions]
ADD CONSTRAINT FK_AutomationExecutions_LeadEvents_triggerEventId
FOREIGN KEY ([triggerEventId]) REFERENCES [crm].[LeadEvents] ([leadEventId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_AutomationExecutions_LeadEvents';
GO

-- =============================================
-- SECTION 15: API REQUEST LOG & EXTERNAL SYSTEMS
-- =============================================
PRINT '';
PRINT 'Section 15: API request log and external systems...';

ALTER TABLE [crm].[ApiRequestLog]
ADD CONSTRAINT FK_ApiRequestLog_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ApiRequestLog_Subscribers';
GO

ALTER TABLE [crm].[ApiRequestLog]
ADD CONSTRAINT FK_ApiRequestLog_AutomationExecutions_automationExecutionId
FOREIGN KEY ([automationExecutionId]) REFERENCES [crm].[AutomationExecutions] ([automationExecutionId])
ON DELETE CASCADE;
PRINT '  ✓ FK_ApiRequestLog_AutomationExecutions';
GO

ALTER TABLE [crm].[ApiRequestLog]
ADD CONSTRAINT FK_ApiRequestLog_Leads_leadId
FOREIGN KEY ([leadId]) REFERENCES [crm].[Leads] ([leadId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ApiRequestLog_Leads';
GO

ALTER TABLE [crm].[ApiRequestLog]
ADD CONSTRAINT FK_ApiRequestLog_ExternalSystems_externalSystemId
FOREIGN KEY ([externalSystemId]) REFERENCES [crm].[ExternalSystems] ([externalSystemId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ApiRequestLog_ExternalSystems';
GO

ALTER TABLE [crm].[ApiRequestLog]
ADD CONSTRAINT FK_ApiRequestLog_ApiRequestResultStatuses_resultStatusId
FOREIGN KEY ([resultStatusId]) REFERENCES [crm].[ApiRequestResultStatuses] ([apiRequestResultStatusId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_ApiRequestLog_ApiRequestResultStatuses';
GO

-- =============================================
-- SECTION 16: METRICS & ANALYTICS
-- =============================================
PRINT '';
PRINT 'Section 16: Metrics and analytics...';

ALTER TABLE [crm].[LeadDailyMetrics]
ADD CONSTRAINT FK_LeadDailyMetrics_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadDailyMetrics_Subscribers';
GO

ALTER TABLE [crm].[LeadSourceDailyMetrics]
ADD CONSTRAINT FK_LeadSourceDailyMetrics_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadSourceDailyMetrics_Subscribers';
GO

ALTER TABLE [crm].[LeadSourceDailyMetrics]
ADD CONSTRAINT FK_LeadSourceDailyMetrics_LeadSources_leadSourceId
FOREIGN KEY ([leadSourceId]) REFERENCES [crm].[LeadSources] ([leadSourceId])
ON DELETE CASCADE;
PRINT '  ✓ FK_LeadSourceDailyMetrics_LeadSources';
GO

ALTER TABLE [crm].[FunnelStageDailyMetrics]
ADD CONSTRAINT FK_FunnelStageDailyMetrics_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE CASCADE;
PRINT '  ✓ FK_FunnelStageDailyMetrics_Subscribers';
GO

ALTER TABLE [crm].[FunnelStageDailyMetrics]
ADD CONSTRAINT FK_FunnelStageDailyMetrics_FunnelStages_funnelStageId
FOREIGN KEY ([funnelStageId]) REFERENCES [crm].[FunnelStages] ([funnelStageId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_FunnelStageDailyMetrics_FunnelStages';
GO

ALTER TABLE [crm].[FunnelStageDailyMetrics]
ADD CONSTRAINT FK_FunnelStageDailyMetrics_Funnels_funnelId
FOREIGN KEY ([funnelId]) REFERENCES [crm].[Funnels] ([funnelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_FunnelStageDailyMetrics_Funnels';
GO

-- =============================================
-- SECTION 17: AI MODELS
-- =============================================
PRINT '';
PRINT 'Section 17: AI models...';

ALTER TABLE [crm].[aiModelParameters]
ADD CONSTRAINT FK_aiModelParameters_aiModels_aiModelId
FOREIGN KEY ([aiModelId]) REFERENCES [crm].[aiModels] ([aiModelId])
ON DELETE CASCADE;
PRINT '  ✓ FK_aiModelParameters_aiModels';
GO

ALTER TABLE [crm].[aiModelUsageLogs]
ADD CONSTRAINT FK_aiModelUsageLogs_aiModels_aiModelId
FOREIGN KEY ([aiModelId]) REFERENCES [crm].[aiModels] ([aiModelId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_aiModelUsageLogs_aiModels';
GO

ALTER TABLE [crm].[aiModelUsageLogs]
ADD CONSTRAINT FK_aiModelUsageLogs_Users_userId
FOREIGN KEY ([userId]) REFERENCES [crm].[Users] ([userId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_aiModelUsageLogs_Users';
GO

ALTER TABLE [crm].[aiModelUsageLogs]
ADD CONSTRAINT FK_aiModelUsageLogs_Subscribers_subscriberId
FOREIGN KEY ([subscriberId]) REFERENCES [crm].[Subscribers] ([subscriberId])
ON DELETE NO ACTION;
PRINT '  ✓ FK_aiModelUsageLogs_Subscribers';
GO

PRINT '';
PRINT '========================================';
PRINT 'FOREIGN KEY CONSTRAINTS COMPLETE';
PRINT '========================================';
PRINT '';
PRINT 'Total Named FK Constraints Created: 140+';
PRINT '';
PRINT 'Next steps:';
PRINT '  1. Create indexes (PROPOSED_INDEXES.sql)';
PRINT '  2. Implement partitioning for massive tables';
PRINT '  3. Enable data compression';
PRINT '';
GO
