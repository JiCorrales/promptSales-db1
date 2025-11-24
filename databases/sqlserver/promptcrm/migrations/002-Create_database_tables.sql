CREATE SCHEMA [crm]
GO

CREATE TABLE [crm].[Countries] (
  [countryId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [countryName] varchar(60) NOT NULL,
  [countryCode] varchar(3) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[States] (
  [stateId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [stateName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [countryId] int NOT NULL
)
GO

CREATE TABLE [crm].[Cities] (
  [cityId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [cityName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [stateId] int NOT NULL
)
GO

CREATE TABLE [crm].[Addresses] (
  [addressId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [address1] varchar(100) NOT NULL,
  [address2] varchar(100) NOT NULL,
  [zipcode] varchar(10) NOT NULL,
  [geolocation] geography,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [cityId] int NOT NULL
)
GO

CREATE TABLE [crm].[Users] (
  [userId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [firstName] varchar(60) NOT NULL,
  [lastName] varchar(60) NOT NULL,
  [email] varchar(255) UNIQUE NOT NULL,
  [phoneNumber] varchar(18) UNIQUE NOT NULL,
  [nationalId] varbinary(255) UNIQUE NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [userStatusId] int NOT NULL
)
GO

CREATE TABLE [crm].[UserStatuses] (
  [userStatusId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [userStatusKey] varchar(30) NOT NULL,
  [userStatusName] varchar(30) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[UserLoginHistory] (
  [loginId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [identifyMethod] varchar(60) NOT NULL,
  [success] bit NOT NULL,
  [loginAt] datetime2,
  [logoutAt] datetime2,
  [sessionData] varbinary(max),
  [userId] int NOT NULL
)
GO

CREATE TABLE [crm].[UserExternalIds] (
  [userExternalId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externalSystem] varchar(60) NOT NULL,
  [externalValue] varbinary(255) NOT NULL,
  [externalObjectType] varchar(60) NOT NULL,
  [isPrimary] bit NOT NULL DEFAULT (0),
  [linkedAt] datetime2,
  [metadata] nvarchar(max),
  [userId] int NOT NULL
)
GO

CREATE TABLE [crm].[UserRoles] (
  [userRoleId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [userRoleName] varchar(80) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [subscriberId] int NOT NULL
)
GO

CREATE TABLE [crm].[RolesPerUser] (
  [userId] int NOT NULL,
  [userRoleId] int NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Permissions] (
  [permissionId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [permissionCode] varchar(8) NOT NULL,
  [description] nvarchar(max) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PermissionPerRole] (
  [userRoleId] int NOT NULL,
  [permissionId] int NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PermissionsPerUser] (
  [userId] int NOT NULL,
  [permissionId] int NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[logTypes] (
  [logTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [logType] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[logLevels] (
  [logLevelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [logLevel] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[logSources] (
  [logSourceId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [log_source] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[logs] (
  [systemLogId] int IDENTITY(1, 1) NOT NULL, -- 1. Se quitó "PRIMARY KEY" de aquí
  [logDescription] varchar(255) NOT NULL,
  [sourceDevice] varchar(60),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [checksum] varchar(64) NOT NULL,
  [userId] int NOT NULL,
  [logTypeId] int NOT NULL,
  [logLevelId] int NOT NULL,
  [logSourceId] int NOT NULL,
  [subscriberId] int NOT NULL,
  -- 2. Se define la PK compuesta (Fecha + ID) para soportar particionado
  CONSTRAINT [PK_logs] PRIMARY KEY CLUSTERED 
  (
    [createdAt] ASC,
    [systemLogId] ASC
  )
) ON [PS_Logs_ByMonth]([createdAt]) -- 3. Se asigna al esquema de partición
GO

CREATE TABLE [crm].[SubscriptionPlans] (
  [subscriptionPlanId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [planName] varchar(30) NOT NULL,
  [planDescription] nvarchar(max) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[SubscriptionFeatureTypes] (
  [subscriptionFeatureTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [featureTypeName] varchar(30) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[SubscriptionFeatures] (
  [subscriptionFeatureId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [featureCode] varchar(40) NOT NULL,
  [featureName] varchar(80) NOT NULL,
  [defaultValue] varchar(20) NOT NULL,
  [description] varchar(512) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [subscriptionFeatureTypeId] int NOT NULL
)
GO

CREATE TABLE [crm].[FeaturesPerPlan] (
  [suscriptionPlanId] int NOT NULL,
  [subscriptionFeatureId] int NOT NULL,
  [featureValue] varchar(20) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PaymentScheduleTypes] (
  [paymentScheduleTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [scheduleTypeName] varchar(30),
  [billingFrequencyDays] int,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PaymentSchedulesPerPlan] (
  [suscriptionPlanId] int NOT NULL,
  [price] decimal(18,4) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [paymentScheduleTypeId] int NOT NULL,
  [currencyId] int NOT NULL
)
GO

CREATE TABLE [crm].[Subscribers] (
  [subscriberId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [legalName] varchar(120) NOT NULL,
  [comercialName] varchar(80) NOT NULL,
  [legalId] varbinary(255) NOT NULL,
  [taxId] varbinary(255) NOT NULL,
  [websiteUrl] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20) NOT NULL,
  [metadata] nvarchar(max)
)
GO

CREATE TABLE [crm].[UsersPerSubscriber] (
  [userId] int NOT NULL,
  [subscriberId] int NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20) NOT NULL
)
GO

CREATE TABLE [crm].[AddressesPerSubscriber] (
  [subscriberId] int NOT NULL,
  [addressId] int NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Subscriptions] (
  [subscriptionId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [startDate] datetime2 NOT NULL,
  [endDate] datetime2 NOT NULL,
  [autoRenew] bit NOT NULL DEFAULT (1),
  [renewalCount] int NOT NULL DEFAULT (0),
  [nextBillingDate] datetime2,
  [canceledAt] datetime2,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [metadata] nvarchar(max),
  [subscriberId] int NOT NULL,
  [subscriptionPlanId] int NOT NULL,
  [paymentMethodId] int NOT NULL,
  [subscriptionStatusId] int NOT NULL
)
GO

CREATE TABLE [crm].[SubscriptionHistory] (
  [subscriptionHistoryId] BIGINT PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [changedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [changeAction] varchar(60) NOT NULL,
  [metadata] nvarchar(max),
  [subscriptionId] int NOT NULL,
  [oldPlanId] int,
  [newPlanId] int,
  [oldStatusId] int,
  [newStatusId] int
)
GO

CREATE TABLE [crm].[SubscriptionStatuses] (
  [subscriptionStatusId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [subscriptionKey] varchar(20) NOT NULL,
  [subscriptionName] varchar(30) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[SubscriptionFeatureUsage] (
  [subscriptionId] int NOT NULL,
  [subscriptionFeatureId] int NOT NULL,
  [usageCount] int NOT NULL,
  [usedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [resetAt] datetime2
)
GO

CREATE TABLE [crm].[SubscriptionBillingConfigs] (
  [subscriptionBillingConfigId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [price] decimal(18,4) NOT NULL,
  [billingFrequencyDays] int NOT NULL,
  [anchorTimeZone] varchar(80) NOT NULL,
  [status] varchar(20) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [effectiveFrom] datetime2 NOT NULL,
  [effectiveTo] datetime2,
  [metadata] nvarchar(max),
  [subscriptionId] int NOT NULL,
  [paymentScheduleTypeId] int NOT NULL,
  [currencyId] int NOT NULL
)
GO

CREATE TABLE [crm].[SubscriptionBillingCycles] (
  [billingCycleId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [periodStart] datetime2 NOT NULL,
  [periodEnd] datetime2 NOT NULL,
  [expectedAmount] decimal(18,4) NOT NULL,
  [status] varchar(20) NOT NULL DEFAULT 'scheduled',
  [scheduledAt] datetime2 NOT NULL,
  [billedAt] datetime2,
  [retryCount] int NOT NULL DEFAULT (0),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2,
  [metadata] nvarchar(max),
  [subscriptionId] int NOT NULL,
  [billingConfigId] int NOT NULL,
  [transactionId] int
)
GO

CREATE TABLE [crm].[TransactionTypes] (
  [transactionTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [transactionTypeName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Transactions] (
  [transactionId] int IDENTITY(1, 1) NOT NULL, 
  -- 1. CORRECCIÓN: Quitamos la palabra "UNIQUE" de aquí
  [transactionReference] varchar(100) NOT NULL, 
  [amount] decimal(18,4) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [processedAt] datetime2 NOT NULL,
  [settledAt] datetime2 NOT NULL,
  [checksum] varchar(64) NOT NULL,
  [metadata] nvarchar(max),
  [transactionTypeId] int NOT NULL,
  [paymentMethodId] int NOT NULL,
  [currencyId] int NOT NULL,
  [subscriberId] int NOT NULL,
  [transactionStatusId] int NOT NULL,
  
  -- 2. PK Compuesta (Para Particionamiento)
  CONSTRAINT [PK_Transactions] PRIMARY KEY CLUSTERED 
  (
    [createdAt] ASC,
    [transactionId] ASC
  ) ON [PS_Transactions_ByMonth]([createdAt]),

  -- 3. EL SALVAVIDAS DEL ID (Para que funcionen las FKs)
  CONSTRAINT [UK_Transactions_Id] UNIQUE NONCLUSTERED 
  (
    [transactionId] ASC
  ) ON [PRIMARY],

  -- 4. NUEVO: El Unique del Reference movido aquí (Global Index)
  CONSTRAINT [UK_Transactions_Reference] UNIQUE NONCLUSTERED 
  (
    [transactionReference] ASC
  ) ON [PRIMARY] -- <--- Esto evita el error 1908 al sacarlo de la partición
)
GO


CREATE TABLE [crm].[TransactionStatuses] (
  [transactionStatusId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [transactionStatusKey] varchar(20) NOT NULL,
  [transactionStatusName] varchar(30) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[TransactionStatusHistory] (
  [transactionStatusHistoryId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [metadata] nvarchar(max),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [checksum] varchar(64) NOT NULL,
  [transactionId] int NOT NULL,
  [transactionStatusId] int NOT NULL
)
GO

CREATE TABLE [crm].[TransactionsExternalIds] (
  [externalId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externalSystem] varchar(60) NOT NULL,
  [externalValue] varbinary(255) NOT NULL,
  [externalObjectType] varchar(60) NOT NULL,
  [isPrimary] bit NOT NULL DEFAULT (0),
  [linkedAt] datetime2,
  [metadata] nvarchar(max),
  [transactionId] int NOT NULL
)
GO

CREATE TABLE [crm].[Currencies] (
  [currencyId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [currencyName] varchar(30) NOT NULL,
  [currencyCode] varchar(3) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PaymentMethodTypes] (
  [paymentMethodTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [methodTypeName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[PaymentMethods] (
  [paymentMethodId] int PRIMARY KEY IDENTITY(1, 1),
  [cardLastFour] VARBINARY(255),
  [cardBrand] VARBINARY(255),
  [expiryMonth] VARBINARY(255),
  [expiryYear] VARBINARY(255),
  [verifiedAt] datetime2,
  [lastUsedAt] datetime2,
  [fingerprint] varchar(64) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20) NOT NULL DEFAULT 'ACTIVE',
  [paymentMethodTypeId] int NOT NULL
)
GO

CREATE TABLE [crm].[PaymentMethodsExternalIds] (
  [externalId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externalSystem] varchar(60) NOT NULL,
  [externalValue] varbinary(255) NOT NULL,
  [externalObjectType] varchar(60) NOT NULL,
  [isPrimary] bit NOT NULL DEFAULT (0),
  [linkedAt] datetime2,
  [metadata] nvarchar(max),
  [paymentMethodId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadSources] (
  [leadSourceId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [campaignKey] varchar(255) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [metadata] nvarchar(max),
  [leadId] int NOT NULL,
  [leadSourceTypeId] int NOT NULL,
  [leadSourceSystemId] int,
  [leadMediumId] int,
  [leadOriginChannelId] int,
  [deviceTypeId] int,
  [devicePlatformId] int,
  [browserId] int
)
GO

CREATE TABLE [crm].[LeadSourceTypes] (
  [leadSourceTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [sourceTypeKey] varchar(30) UNIQUE NOT NULL,
  [sourceTypeName] nvarchar(60) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadStatus] (
  [leadStatusId] int PRIMARY KEY IDENTITY(1, 1),
  [leadStatusKey] varchar(30) UNIQUE NOT NULL,
  [leadStatusName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Leads] (
  [leadId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadToken] varchar(64) UNIQUE NOT NULL,
  [email] varchar(255),
  [phoneNumber] varchar(18),
  [firstName] varchar(60),
  [lastName] varchar(60),
  [age] int,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [lead_score] decimal(5,2) DEFAULT (0),
  [metadata] nvarchar(max),
  [countryId] int,
  [StateId] int,
  [cityId] int,
  [subscriberId] int NOT NULL,
  [demographicRaceId] int,
  [demographicGenderId] int,
  [demographicEthnicityId] int,
  [leadStatusId] int NOT NULL,
  [leadTierId] int NOT NULL
)
GO

CREATE TABLE [crm].[DemographicRaces] (
  [demographicRaceId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [demographicRaceKey] varchar(30) NOT NULL,
  [demographicRaceName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[DemographicGenders] (
  [demographicGenderId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [demographicGenderKey] varchar(30) NOT NULL,
  [demographicGenderName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[DemographicEthnicities] (
  [demographicEthnicityId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [demographicEnthnicityKey] varchar(30) NOT NULL,
  [demographicEnthnicityName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadTiers] (
  [leadTierId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadTierKey] varchar(30) UNIQUE NOT NULL,
  [leadTierName] nvarchar(60) NOT NULL,
  [minScore] decimal(5,2) NOT NULL,
  [maxScore] decimal(5,2) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadExternalIds] (
  [leadExternalId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externalSystem] varchar(60) NOT NULL,
  [externalValue] varbinary(255) NOT NULL,
  [externalObjectType] varchar(60) NOT NULL,
  [isPrimary] bit NOT NULL DEFAULT (0),
  [linkedAt] datetime2,
  [metadata] nvarchar(max),
  [leadId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadSourceSystems] (
  [leadSourceSystemId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [systemKey] varchar(30) UNIQUE NOT NULL,
  [systemName] varchar(60) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadMediums] (
  [leadMediumId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadMediumKey] varchar(30) UNIQUE NOT NULL,
  [leadMediumName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadOriginChannels] (
  [leadOriginChannelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadOriginChannelKey] varchar(30) UNIQUE NOT NULL,
  [leadOriginChannelName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[DeviceTypes] (
  [deviceTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [deviceTypeKey] varchar(30) UNIQUE NOT NULL,
  [deviceTypeName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[DevicePlatforms] (
  [devicePlatformId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [devicePlatformKey] varchar(30) UNIQUE NOT NULL,
  [devicePlatformName] nvarchar(60) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Browsers] (
  [browserId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [browserKey] varchar(30) UNIQUE NOT NULL,
  [browserName] nvarchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadEventTypes] (
  [leadEventTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [eventTypeKey] varchar(60) UNIQUE NOT NULL,
  [eventTypeName] nvarchar(120) NOT NULL,
  [categoryKey] varchar(30) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadEventSources] (
  [leadEventSourceId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [sourceKey] varchar(60) UNIQUE NOT NULL,
  [sourceName] nvarchar(120) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadEvents] (
  [leadEventId] bigint IDENTITY(1, 1) NOT NULL, -- 1. Se quitó "PRIMARY KEY"
  [campaignKey] varchar(255),
  [adGroupKey] varchar(255),
  [adKey] varchar(255),
  [contentKey] varchar(255),
  [ipAddress] varbinary(64),
  [occurredAt] datetime2 NOT NULL, -- Esta es la columna clave de partición
  [receivedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [metadata] nvarchar(max),
  [checksum] varchar(64),
  [countryId] int,
  [StateId] int,
  [cityId] int,
  [leadId] int NOT NULL,
  [leadSourceId] int NOT NULL,
  [mediumId] int,
  [originChannelId] int,
  [deviceTypeId] int,
  [devicePlatformId] int,
  [browserId] int,
  [leadEventTypeId] int NOT NULL,
  [leadEventSourceId] int NOT NULL,
  -- 2. PK Compuesta (Para Particionamiento)
  CONSTRAINT [PK_LeadEvents] PRIMARY KEY CLUSTERED 
  (
    [occurredAt] ASC,
    [leadEventId] ASC
  ) ON [PS_LeadEvents_ByMonth]([occurredAt]),
  
  -- 4. SALVAVIDAS DE FKs: Esto permite que otras tablas apunten solo al ID
  CONSTRAINT [UK_LeadEvents_Id] UNIQUE NONCLUSTERED 
  (
    [leadEventId] ASC
  ) ON [PRIMARY] -- Importante: Este índice se queda en PRIMARY, no se particiona
) 
GO

CREATE TABLE [crm].[LeadTagsCatalog] (
  [leadTagCatalogId] int PRIMARY KEY IDENTITY(1, 1),
  [tagKey] varchar(100) UNIQUE NOT NULL,
  [tagName] nvarchar(100),
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2,
  [enabled] bit DEFAULT (1),
  [leadCategoryTypeId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadTagCategories] (
  [leadCategoryId] int PRIMARY KEY IDENTITY(1, 1),
  [leadCategoryKey] varchar(30),
  [leadCategorynName] varchar(30),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2,
  [enabled] bit DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadTags] (
  [leadTagId] bigint PRIMARY KEY IDENTITY(1, 1),
  [weight] decimal(5,2),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2,
  [enabled] bit DEFAULT (1),
  [leadId] int NOT NULL,
  [leadEventId] bigint,
  [leadTagCatalogId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadConversions] (
  [leadConversionId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [conversionValue] decimal(18,4) NOT NULL,
  [externalOrderId] varchar(255),
  [externalSystemName] varchar(60),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [metadata] nvarchar(max),
  [leadId] int NOT NULL,
  [leadSourceId] int,
  [leadEventId] bigint NOT NULL,
  [leadConversionTypeId] int NOT NULL,
  [attributionModelId] int,
  [currencyId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadConversionTypes] (
  [leadConversionTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadConversionKey] varchar(30) NOT NULL,
  [leadConversionName] varchar(60) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[AttributionModels] (
  [attributionModelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [modelKey] varchar(30) UNIQUE NOT NULL,
  [modelName] nvarchar(60) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[ClientStatuses] (
  [clientStatusId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [clientStatusKey] varchar(30) UNIQUE NOT NULL,
  [clientStatusName] varchar(100) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[Clients] (
  [clientId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [firstName] varchar(60) NOT NULL,
  [lastName] varchar(60) NOT NULL,
  [email] varchar(255),
  [phoneNumber] varchar(18),
  [nationalId] varbinary(255),
  [lifetimeValue] decimal(18,4) NOT NULL DEFAULT (0),
  [firstPurchaseAt] datetime2 NOT NULL,
  [lastPurchaseAt] datetime2 NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [metadata] nvarchar(max),
  [clientStatusId] int NOT NULL,
  [subscriberId] int NOT NULL,
  [leadId] int UNIQUE NOT NULL,
  [currencyId] int NOT NULL
)
GO

CREATE TABLE [crm].[ClientExternalIds] (
  [clientExternalId] bigint PRIMARY KEY IDENTITY(1, 1),
  [systemName] varchar(60) NOT NULL,
  [issuer] varchar(255),
  [subject] varchar(255),
  [externalIdentification] varchar(255) NOT NULL,
  [objectType] varchar(30),
  [metadata] nvarchar(max),
  [createdAt] datetime2 NOT NULL,
  [linkedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2,
  [enabled] bit DEFAULT (1),
  [clientId] bigint NOT NULL
)
GO

CREATE TABLE [crm].[ClientProfiles] (
  [clientId] bigint PRIMARY KEY,
  [recencyScore] int,
  [frequencyScore] int,
  [monetaryScore] int,
  [rfmSegment] varchar(30),
  [totalPurchases] int NOT NULL DEFAULT (0),
  [totalSpent] decimal(18,4) NOT NULL DEFAULT (0),
  [averageOrderValue] decimal(18,4),
  [daysSinceLastPurchase] int,
  [preferredContactTimeKey] varchar(20),
  [calculatedAt] datetime2,
  [updatedAt] datetime2,
  [metadata] nvarchar(max),
  [preferredMediumId] int,
  [preferredChannelId] int,
  [mostFrequentDeviceTypeId] int
)
GO

CREATE TABLE [crm].[CommunicationChannels] (
  [communicationChannelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [communicationChannelKey] varchar(30) UNIQUE NOT NULL,
  [communicationChannelName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadCommunicationPreferences] (
  [leadId] int PRIMARY KEY,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [communicationChannelId] int NOT NULL
)
GO

CREATE TABLE [crm].[GdprRequestTypes] (
  [gdprRequestTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [gdprRequestTypeKey] varchar(30) UNIQUE NOT NULL,
  [gdprRequestTypeName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[GdprRequestStatuses] (
  [gdprRequestStatusId] int PRIMARY KEY IDENTITY(1, 1),
  [gdprRequeststatusKey] varchar(30) UNIQUE NOT NULL,
  [gdprRequestStatusName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadGdprRequests] (
  [gdprRequestId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [requestedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [processedAt] datetime2,
  [completedAt] datetime2,
  [metadata] nvarchar(max),
  [processedByUserId] int NOT NULL,
  [leadId] int NOT NULL,
  [gdprRequestTypeId] int NOT NULL,
  [gdprRequestStatusId] int NOT NULL
)
GO

CREATE TABLE [crm].[Funnels] (
  [funnelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [funnelKey] varchar(40) NOT NULL,
  [funnelName] nvarchar(80) NOT NULL,
  [description] nvarchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (0),
  [isDefault] bit NOT NULL DEFAULT (0),
  [subscriberId] int NOT NULL
)
GO

CREATE TABLE [crm].[FunnelStages] (
  [funnelStageId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [funnelStageOrder] int NOT NULL,
  [funnelStageKey] varchar(30) NOT NULL,
  [funnelStageName] varchar(60) NOT NULL,
  [description] varchar(255),
  [closeProbability] decimal(5,2) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [funnelId] int NOT NULL
)
GO

CREATE TABLE [crm].[LeadFunnelProgress] (
  [leadFunnelProgressId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [enteredAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [exitedAt] datetime2,
  [isCurrent] bit NOT NULL DEFAULT (1),
  [triggerMetadata] nvarchar(max),
  [triggerUserId] int NOT NULL,
  [leadId] int NOT NULL,
  [triggerEventId] bigint NOT NULL,
  [funnelStageId] int NOT NULL,
  [triggerCauseTypeId] int NOT NULL,
  [triggerRuleId] int NOT NULL,
  [funnelId] int NOT NULL
)
GO

CREATE TABLE [crm].[TriggerRules] (
  [triggerRuleId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [triggerRuleKey] varchar(60) NOT NULL,
  [triggerRuleName] varchar(120) NOT NULL,
  [description] varchar(512),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [subscriberId] int NOT NULL
)
GO

CREATE TABLE [crm].[TriggerCauseTypes] (
  [triggerCauseTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [triggerCauseKey] varchar(60) NOT NULL,
  [triggerCauseName] varchar(80) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[AutomationActionTypes] (
  [automationActionTypeId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [actionTypeKey] varchar(100) UNIQUE NOT NULL,
  [actionTypeName] varchar(120) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[ExternalSystems] (
  [externalSystemId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externalSystemKey] varchar(60) UNIQUE NOT NULL,
  [externalSystemName] nvarchar(120) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[ExternalWorkflows] (
  [externalWorkflowId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [externarlWorkflowKey] varchar(100) NOT NULL,
  [externalWorkflowName] varchar(150) NOT NULL,
  [description] nvarchar(255),
  [externalWorkflowRef] varchar(255) NOT NULL,
  [externalWorkflowConfig] nvarchar(max),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [subscriberId] int NOT NULL,
  [externalSystemId] int NOT NULL
)
GO

CREATE TABLE [crm].[AutomationActions] (
  [automationActionId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [automationActionKey] varchar(100) NOT NULL,
  [automationActionName] varchar(120) NOT NULL,
  [description] varchar(255),
  [actionConfig] nvarchar(max),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [subscriberId] int NOT NULL,
  [automationActionTypeId] int NOT NULL,
  [externalWorkflowId] int
)
GO

CREATE TABLE [crm].[TriggerRuleActions] (
  [triggerRuleActionId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [executionOrder] int NOT NULL DEFAULT (1),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1),
  [triggerRuleId] int NOT NULL,
  [automationActionId] int NOT NULL
)
GO

CREATE TABLE [crm].[AutomationExecutions] (
  [automationExecutionId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [startedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [finishedAt] datetime2,
  [executionStatus] varchar(30) NOT NULL,
  [errorMessage] varchar(512),
  [metadata] nvarchar(max),
  [automationActionId] int NOT NULL,
  [subscriberId] int NOT NULL,
  [leadFunnelProgressId] bigint NOT NULL,
  [leadId] int NOT NULL,
  [triggerRuleId] int NOT NULL,
  [triggerEventId] bigint NOT NULL
)
GO

CREATE TABLE [crm].[ApiRequestLog] (
  [apiRequestLogId] bigint IDENTITY(1, 1) NOT NULL, -- 1. Se quitó "PRIMARY KEY"
  [httpMethod] varchar(30) NOT NULL,
  [endpoint] nvarchar(255) NOT NULL,
  [requestPayload] nvarchar(max),
  [responsePayload] nvarchar(max),
  [requestAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()), -- Clave de partición
  [responseAt] datetime2,
  [subscriberId] int NOT NULL,
  [automationExecutionId] bigint NOT NULL,
  [leadId] int NOT NULL,
  [externalSystemId] int NOT NULL,
  [resultStatusId] int NOT NULL,
  -- 2. PK Compuesta usando requestAt
  CONSTRAINT [PK_ApiRequestLog] PRIMARY KEY CLUSTERED 
  (
    [requestAt] ASC,
    [apiRequestLogId] ASC
  )
) ON [PS_ApiLog_ByMonth]([requestAt]) -- 3. Asignación al esquema
GO

CREATE TABLE [crm].[ApiRequestResultStatuses] (
  [apiRequestResultStatusId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [resultStatusKey] varchar(30) UNIQUE NOT NULL,
  [resultStatusName] varchar(60) NOT NULL,
  [description] varchar(255),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [enabled] bit NOT NULL DEFAULT (1)
)
GO

CREATE TABLE [crm].[LeadDailyMetrics] (
  [leadDailyMetricsId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [subscriberId] int NOT NULL,
  [newLeadsCount] int NOT NULL DEFAULT (0),
  [activeLeadsCount] int NOT NULL DEFAULT (0),
  [convertedLeadsCount] int NOT NULL DEFAULT (0),
  [totalConversions] int NOT NULL DEFAULT (0),
  [totalConversionValue] decimal(18,4) NOT NULL DEFAULT (0),
  [spendAmount] decimal(18,4),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [statDate] datetime2 NOT NULL
)
GO

CREATE TABLE [crm].[LeadSourceDailyMetrics] (
  [leadSourceDailyMetricsId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [impressionsCount] int NOT NULL DEFAULT (0),
  [viewsCount] int NOT NULL DEFAULT (0),
  [clicksCount] int NOT NULL DEFAULT (0),
  [conversionsCount] int NOT NULL DEFAULT (0),
  [conversionValue] decimal(18,4) NOT NULL DEFAULT (0),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [statDate] datetime2 NOT NULL,
  [subscriberId] int NOT NULL,
  [leadSourceId] int NOT NULL
)
GO

CREATE TABLE [crm].[FunnelStageDailyMetrics] (
  [funnelStageDailyMetricsId] bigint PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [leadsInStageCount] int NOT NULL DEFAULT (0),
  [enteredCount] int NOT NULL DEFAULT (0),
  [exitedCount] int NOT NULL DEFAULT (0),
  [avgDaysInStage] decimal(10,2) NOT NULL,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [statDate] datetime2 NOT NULL,
  [subscriberId] int NOT NULL,
  [funnelStageId] int NOT NULL,
  [funnelId] int NOT NULL
)
GO

CREATE TABLE [crm].[aiModels] (
  [aiModelId] int PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [modelName] varchar(100),
  [modelVersion] varchar(30),
  [modelDescription] nvarchar(max),
  [modelProvider] varchar(60),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20) NOT NULL
)
GO

CREATE TABLE [crm].[aiModelParameters] (
  [parameterId] int PRIMARY KEY IDENTITY(1, 1),
  [aiModelId] int NOT NULL,
  [parameterName] varchar(60),
  [parameterType] varchar(20),
  [defaultValue] varchar(255),
  [minValue] varchar(20),
  [maxValue] varchar(20),
  [description] nvarchar(max),
  [isRequired] bit,
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [updatedAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20) NOT NULL
)
GO

CREATE TABLE [crm].[aiModelUsageLogs] (
  [usageLogId] BIGINT PRIMARY KEY NOT NULL IDENTITY(1, 1),
  [promptText] nvarchar(max),
  [responseText] nvarchar(max),
  [parametersUsed] nvarchar(max),
  [tokensInput] int,
  [tokensOutput] int,
  [processingTimeMs] int,
  [costAmount] decimal(10,4),
  [errorMessage] nvarchar(max),
  [createdAt] datetime2 NOT NULL DEFAULT (SYSUTCDATETIME()),
  [status] varchar(20),
  [checksum] varchar(64),
  [aiModelId] int NOT NULL,
  [userId] int NOT NULL,
  [subscriberId] int NOT NULL
)
GO

EXEC sp_addextendedproperty
@name = N'Column_Description',
@value = 'Score 0-100 calculado por IA',
@level0type = N'Schema', @level0name = 'crm',
@level1type = N'Table',  @level1name = 'Leads',
@level2type = N'Column', @level2name = 'lead_score';
GO
