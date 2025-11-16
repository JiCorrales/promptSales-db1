Use PromptAds;

/* Usuarios, compañías, marcas, productos, suscripciones, relaciones */

IF OBJECT_ID('dbo.sp_Seed_Users_Companies_Basics', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Seed_Users_Companies_Basics;
GO

CREATE PROCEDURE dbo.sp_Seed_Users_Companies_Basics
    @UsersCount      int = 50000,
    @CompaniesCount  int = 50000,
    @BrandsPerComp   int = 3,
    @ProductsPerBrand int = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @startUserId bigint, @startCompanyId bigint;

    /*-----------------------------
      Usuarios
    -----------------------------*/
    SELECT @startUserId = ISNULL(MAX(UserId),0) FROM dbo.Users;

    INSERT INTO dbo.Users
    (UserStatusId, firstName, lastName, email, createdAt, updatedAt, active,
     passwordHash, checksum, lastLogin, username)
    SELECT TOP (@UsersCount)
        1, -- Activo
        fn.Name,
        ln.Name,
        CONCAT('user', @startUserId + ROW_NUMBER() OVER (ORDER BY n.n),'@promptads.test'),
        dbo.fn_RandomDateTime(n.n),
        dbo.fn_RandomDateTime(n.n + 1000000),
        1,
        CONVERT(varbinary(256),
                HASHBYTES('SHA2_256', CONCAT('pwd', @startUserId + n.n))),
        CONVERT(char(64),
                HASHBYTES('SHA2_256', CONCAT('chk', @startUserId + n.n)),2),
        dbo.fn_RandomDateTime(n.n + 2000000),
        CONCAT('user', @startUserId + ROW_NUMBER() OVER (ORDER BY n.n))
    FROM dbo.Numbers n
    CROSS JOIN (SELECT TOP (100) * FROM dbo.FirstNames) fn
    CROSS JOIN (SELECT TOP (100) * FROM dbo.LastNames) ln;

    /* RolesPerUser y SubscriptionPerUser */
    DECLARE @RoleAdmin int = (SELECT RoleId FROM dbo.Roles WHERE name='Admin');
    DECLARE @RoleMgr   int = (SELECT RoleId FROM dbo.Roles WHERE name='CampaignManager');
    DECLARE @RoleAnal  int = (SELECT RoleId FROM dbo.Roles WHERE name='Analyst');

    INSERT INTO dbo.RolesPerUser(UserId, RoleId, createdAt, enabled, checksum)
    SELECT u.UserId,
           CASE WHEN u.UserId % 10 = 0 THEN @RoleAdmin
                WHEN u.UserId % 2 = 0 THEN @RoleMgr
                ELSE @RoleAnal
           END,
           dbo.fn_RandomDateTime(u.UserId),
           1,
           CONVERT(char(64),
                   HASHBYTES('SHA2_256', CONCAT('role', u.UserId)),2)
    FROM dbo.Users u
    WHERE u.UserId > @startUserId;

    INSERT INTO dbo.SubscriptionPerUser(UserId, SubscriptionId, enabled)
    SELECT u.UserId,
           CASE WHEN u.UserId % 10 = 0 THEN sEnt.SubscriptionId
                WHEN u.UserId % 2 = 0 THEN sGro.SubscriptionId
                ELSE sSta.SubscriptionId
           END,
           1
    FROM dbo.Users u
    CROSS JOIN dbo.Subscriptions sSta
    CROSS JOIN dbo.Subscriptions sGro
    CROSS JOIN dbo.Subscriptions sEnt
    WHERE sSta.name='Starter'
      AND sGro.name='Growth'
      AND sEnt.name='Enterprise'
      AND u.UserId > @startUserId;

    /*-----------------------------
      Companies + CompanyAddresses
    -----------------------------*/
    SELECT @startCompanyId = ISNULL(MAX(CompanyId),0) FROM dbo.Companies;

    INSERT INTO dbo.Companies(CompStatusId, name, legalName, email, active, createdAt)
    SELECT TOP (@CompaniesCount)
        CASE WHEN n.n % 10 = 0 THEN 1  -- Prospecto
             WHEN n.n % 10 <= 7 THEN 2 -- Activo
             ELSE 3                    -- Suspendido
        END,
        CONCAT('Empresa ', @startCompanyId + n.n),
        CONCAT('Empresa ', @startCompanyId + n.n, ' S.A.'),
        CONCAT('contacto', @startCompanyId + n.n, '@cliente.test'),
        CASE WHEN n.n % 13 = 0 THEN 0 ELSE 1 END,
        dbo.fn_RandomDateTime(n.n)
    FROM dbo.Numbers n;

    -- Relación CompanyAddresses (distribuimos direcciones existentes)
    INSERT INTO dbo.CompanyAddresses(CompanyId, AddressId, isPrimary, createdAt)
    SELECT c.CompanyId,
           ((c.CompanyId - @startCompanyId - 1) % 6) + 1,
           1,
           dbo.fn_RandomDateTime(c.CompanyId)
    FROM dbo.Companies c
    WHERE c.CompanyId > @startCompanyId;

    /*-----------------------------
      Brands 
    -----------------------------*/
    DECLARE @BrandsTarget int = @CompaniesCount * @BrandsPerComp;

    INSERT INTO dbo.Brands(CompanyId, name, description)
    SELECT TOP (@BrandsTarget)
        c.CompanyId,
        CONCAT('Marca ', c.CompanyId, '-', ROW_NUMBER() OVER (PARTITION BY c.CompanyId ORDER BY (SELECT NULL))),
        'Marca asociada a la empresa para campañas de marketing'
    FROM dbo.Companies c
    CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3) rep; -- 3 por compañía


    /*-----------------------------
      UserPerCompany (asignar usuarios a empresas)
    -----------------------------*/
    INSERT INTO dbo.UserPerCompany(CompanyId, UserId, enabled)
    SELECT c.CompanyId,
           u.UserId,
           1
    FROM dbo.Companies c
    JOIN dbo.Users u
      ON (u.UserId - @startUserId) % @CompaniesCount = (c.CompanyId - @startCompanyId) % @CompaniesCount
    WHERE c.CompanyId > @startCompanyId
      AND u.UserId > @startUserId;

END;
GO





/* Campañas, mercados, anuncios, audiencia, influencers */



IF OBJECT_ID('dbo.sp_Seed_Campaigns_Ads_Markets', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Seed_Campaigns_Ads_Markets;
GO

CREATE PROCEDURE dbo.sp_Seed_Campaigns_Ads_Markets
    @CampaignsCount int = 60000,     -- ? 50k
    @AdsPerCampaign int = 5,         -- genera 300k Ads
    @MarketsCount   int = 2000,
    @Influencers    int = 50000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @startCampId bigint, @startAdId bigint, @startInflId bigint;

    /*-----------------------------
      Markets
    -----------------------------*/
    IF NOT EXISTS (SELECT 1 FROM dbo.Markets)
    BEGIN
        INSERT INTO dbo.Markets(name, description, CountryId, StateId, CityId)
        SELECT TOP (@MarketsCount)
            CONCAT('Mercado ', n.n),
            'Segmento geográfico/comercial objetivo',
            c.CountryId,
            s.StateId,
            ci.CityId
        FROM dbo.Numbers n
        CROSS JOIN dbo.Countries c
        CROSS JOIN dbo.States s
        CROSS JOIN dbo.Cities ci;
    END

    /*-----------------------------
      Campaigns
    -----------------------------*/
    SELECT @startCampId = ISNULL(MAX(CampaignId),0) FROM dbo.Campaigns;

    INSERT INTO dbo.Campaigns
    (name, description, createdAt, updatedAt, startDate, endDate,
     budget, CompanyId, CampaignStatusId, BrandId)
    SELECT TOP (@CampaignsCount)
        CONCAT('Campaña ', @startCampId + n.n),
        'Campaña multicanal generada aleatoriamente',
        dbo.fn_RandomDateTime(n.n),
        dbo.fn_RandomDateTime(n.n + 100000),
        dbo.fn_RandomDateTime(n.n),
        DATEADD(DAY, dbo.fn_RandBetween(n.n, 7, 90), dbo.fn_RandomDateTime(n.n)),
        CAST(dbo.fn_RandBetween(n.n, 500, 50000) AS decimal(18,2)),
        (SELECT TOP 1 CompanyId FROM dbo.Companies ORDER BY NEWID()),
        CASE WHEN n.n % 10 = 0 THEN 1 -- Planificada
             WHEN n.n % 10 <= 6 THEN 2 -- Activa
             WHEN n.n % 10 <= 8 THEN 3 -- Pausada
             ELSE 4                    -- Finalizada
        END,
        (SELECT TOP 1 BrandId FROM dbo.Brands ORDER BY NEWID())
    FROM dbo.Numbers n;

    -- CampaignMarkets (2–5 mercados por campaña)
    INSERT INTO dbo.CampaignMarkets(CampaignId, MarketId)
    SELECT c.CampaignId,
           m.MarketId
    FROM dbo.Campaigns c
    CROSS APPLY (
        SELECT TOP (dbo.fn_RandBetween(c.CampaignId,2,5)) m.MarketId
        FROM dbo.Markets m
        ORDER BY NEWID()
    ) m
    WHERE c.CampaignId > @startCampId;

    /*-----------------------------
      Influencers
    -----------------------------*/
    SELECT @startInflId = ISNULL(MAX(InfluencerId),0) FROM dbo.Influencers;

    INSERT INTO dbo.Influencers(username, followers, bio, ChannelId,
                                createdAt, updatedAt, active)
    SELECT TOP (@Influencers)
        CONCAT('influencer_', @startInflId + n.n),
        CAST(dbo.fn_RandBetween(n.n, 1000, 500000) AS bigint),
        'Influencer generado aleatoriamente para pruebas',
        ch.ChannelId,
        dbo.fn_RandomDateTime(n.n),
        dbo.fn_RandomDateTime(n.n + 500000),
        CASE WHEN n.n % 11 = 0 THEN 0 ELSE 1 END
    FROM dbo.Numbers n
    CROSS JOIN dbo.Channels ch;

    /*-----------------------------
      Ads y ChannelsPerAd
    -----------------------------*/
    SELECT @startAdId = ISNULL(MAX(AdId),0) FROM dbo.Ads;

    INSERT INTO dbo.Ads
    (CampaignId, name, description, createdAt, updatedAt,
     AdStatusId, AdTypeId, enabled, deleted)
    SELECT
        c.CampaignId,
        CONCAT('Ad ', c.CampaignId, '-', ROW_NUMBER() OVER (PARTITION BY c.CampaignId ORDER BY n.n)),
        'Anuncio asociado a la campaña',
        dbo.fn_RandomDateTime(n.n + c.CampaignId),
        dbo.fn_RandomDateTime(n.n + c.CampaignId + 100000),
        CASE WHEN n.n % 10 = 0 THEN 1 -- Borrador
             WHEN n.n % 10 <= 6 THEN 3 -- Activo
             WHEN n.n % 10 <= 8 THEN 4 -- Pausado
             ELSE 5                    -- Finalizado
        END,
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.AdTypes)) + 1,
        1,
        CASE WHEN n.n % 23 = 0 THEN 1 ELSE 0 END
    FROM dbo.Campaigns c
    JOIN dbo.Numbers n ON n.n <= @AdsPerCampaign
    WHERE c.CampaignId > @startCampId;

    -- ChannelsPerAd (2–3 canales por Ad)
    INSERT INTO dbo.ChannelsPerAd(AdId, ChannelId, enabled)
    SELECT a.AdId,
           ch.ChannelId,
           1
    FROM dbo.Ads a
    CROSS APPLY (
        SELECT TOP (dbo.fn_RandBetween(a.AdId,2,3)) ch.ChannelId
        FROM dbo.Channels ch
        ORDER BY NEWID()
    ) ch
    WHERE a.AdId > @startAdId;

    /*-----------------------------
      Media y AdMedias
    -----------------------------*/
    INSERT INTO dbo.Media(MediaTypeId, URL)
    SELECT TOP (100000)
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.MediaTypes)) + 1,
        CONCAT('https://cdn.promptsales.test/media/', n.n, '.asset')
    FROM dbo.Numbers n;

    INSERT INTO dbo.AdMedias(AdId, MediaId, createdAt, deleted, enabled)
    SELECT TOP (200000)
        a.AdId,
        m.MediaId,
        dbo.fn_RandomDateTime(m.MediaId),
        0,
        1
    FROM dbo.Ads a
    CROSS JOIN dbo.Media m;

    /*-----------------------------
      TargetAudience, AudienceFeatures, AudienceValues, TargetConfig, AdAudience
    -----------------------------*/
    IF NOT EXISTS(SELECT 1 FROM dbo.TargetAudience)
    BEGIN
        INSERT INTO dbo.TargetAudience(name, description)
        VALUES ('Jóvenes urbanos','Personas de 18-30 en ciudades'),
               ('Profesionales','Personas con trabajo formal'),
               ('Padres y madres','Hogares con hijos'),
               ('Estudiantes universitarios','Matriculados en universidad'),
               ('Emprendedores','Dueños de pequeños negocios');
    END

    IF NOT EXISTS(SELECT 1 FROM dbo.AudienceFeatures)
    BEGIN
        INSERT INTO dbo.AudienceFeatures(name, datatype)
        VALUES ('Edad','int'),('País','string'),('Interés principal','string'),
               ('Nivel de ingreso','string'),('Frecuencia de compra','int');
    END

    IF NOT EXISTS(SELECT 1 FROM dbo.AudienceValues)
    BEGIN
        -- Ejemplo simple: rangos de edad e intereses
        INSERT INTO dbo.AudienceValues(AudienceFeatureId, name, minValue, maxValue, value)
        SELECT af.AudienceFeatureId,
               CONCAT('Segmento ', af.name, ' ', n.n),
               CASE WHEN af.datatype='int' THEN n.n * 5 ELSE NULL END,
               CASE WHEN af.datatype='int' THEN n.n * 5 + 4 ELSE NULL END,
               CASE WHEN af.datatype='int' THEN n.n * 5 ELSE NULL END
        FROM dbo.AudienceFeatures af
        CROSS JOIN (SELECT TOP 20 n FROM dbo.Numbers) n;
    END

    -- TargetConfig
    IF NOT EXISTS(SELECT 1 FROM dbo.TargetConfig)
    BEGIN
        INSERT INTO dbo.TargetConfig(TargetAudienceId, AudienceValueId, enabled)
        SELECT TOP (5000)
            ta.TargetAudienceId,
            av.AudienceValue,
            1
        FROM dbo.TargetAudience ta
        CROSS JOIN dbo.AudienceValues av;
    END

    -- AdAudience (asignar 1–3 audiencias por Ad)
    INSERT INTO dbo.AdAudience(AdId, TargetAudienceId, enabled)
    SELECT a.AdId,
           ta.TargetAudienceId,
           1
    FROM dbo.Ads a
    CROSS APPLY (
        SELECT TOP (dbo.fn_RandBetween(a.AdId,1,3)) ta.TargetAudienceId
        FROM dbo.TargetAudience ta
        ORDER BY NEWID()
    ) ta
    WHERE a.AdId > @startAdId;

    /*-----------------------------
      InfluencersPerAd y contactos
    -----------------------------*/
    INSERT INTO dbo.InfluencersPerAd(InfluencerId, AdId, enabled, fee, contractRef,
                                     posttime, updatedAt)
    SELECT TOP (200000)
        i.InfluencerId,
        a.AdId,
        1,
        CAST(dbo.fn_RandBetween(a.AdId, 100, 3000) AS decimal(18,2)),
        CONCAT('CTR-', i.InfluencerId, '-', a.AdId),
        dbo.fn_RandomDateTime(a.AdId + i.InfluencerId),
        dbo.fn_RandomDateTime(a.AdId + i.InfluencerId + 500000)
    FROM dbo.Influencers i
    CROSS JOIN dbo.Ads a;

    INSERT INTO dbo.InfluencerContacts(InfluencerId, ContactTypeId, value, number, createdAt, enabled, deleted)
    SELECT TOP (100000)
        i.InfluencerId,
        ct.ContactTypeId,
        CASE ct.name
            WHEN 'Email' THEN CONCAT(i.username, '@influencers.test')
            WHEN 'Teléfono' THEN CONCAT('+506', RIGHT('8'+CAST(i.InfluencerId AS varchar(10)),8))
            ELSE CONCAT(ct.name, ':', i.username)
        END,
        NULL,
        dbo.fn_RandomDateTime(i.InfluencerId),
        1,
        0
    FROM dbo.Influencers i
    CROSS JOIN dbo.ContactTypes ct;
END;
GO

