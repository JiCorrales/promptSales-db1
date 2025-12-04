USE PromptAds;
GO

IF TYPE_ID('dbo.TVP_CampaignMarkets') IS NOT NULL
    DROP TYPE dbo.TVP_CampaignMarkets;
GO

CREATE TYPE dbo.TVP_CampaignMarkets AS TABLE
(
    MarketId bigint NOT NULL
);
GO


IF TYPE_ID('dbo.TVP_CampaignAds') IS NOT NULL
    DROP TYPE dbo.TVP_CampaignAds;
GO

CREATE TYPE dbo.TVP_CampaignAds AS TABLE
(
    TempAdKey     int           NOT NULL,          -- Identificador temporal del anuncio en el TVP
    [name]        varchar(100)  NOT NULL,
    [description] varchar(400)  NULL,
    AdTypeId      int           NOT NULL,          
    AdStatusId    int           NULL               
);
GO


IF TYPE_ID('dbo.TVP_AdChannels') IS NOT NULL
    DROP TYPE dbo.TVP_AdChannels;
GO

CREATE TYPE dbo.TVP_AdChannels AS TABLE
(
    TempAdKey int     NOT NULL,   
    ChannelId bigint  NOT NULL    
);
GO


IF OBJECT_ID('dbo.CAMSP_CreateCampaign', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CAMSP_CreateCampaign;
GO

CREATE PROCEDURE dbo.CAMSP_CreateCampaign
    @CompanyId        bigint,
    @BrandId          bigint = NULL,
    @Name             varchar(150),
    @Description      varchar(400) = NULL,
    @StartDate        datetime,
    @EndDate          datetime,
    @Budget           decimal(18,2),
    @CampaignStatusId int = NULL,                          
    @Markets          dbo.TVP_CampaignMarkets READONLY,    -- Lista de mercados
    @Ads              dbo.TVP_CampaignAds      READONLY,   -- Lista de anuncios
    @AdChannels       dbo.TVP_AdChannels       READONLY    -- Canales por anuncio (TempAdKey)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @NewCampaignId      bigint,
        @Now                datetime = GETDATE(),
        @DefaultStatusId    int,
        @DefaultAdStatusId  int;

    -- tabla staging para los Ads (copiamos el TVP y le damos un orden fijo)
    DECLARE @AdsOrdered TABLE
    (
        rn         int IDENTITY(1,1) PRIMARY KEY,
        TempAdKey  int           NOT NULL,
        [name]     varchar(100)  NOT NULL,
        [description] varchar(400) NULL,
        AdTypeId   int           NOT NULL,
        AdStatusId int           NULL
    );

    -- tabla para mapear TempAdKey -> AdId
    DECLARE @NewAds TABLE
    (
        TempAdKey int NOT NULL,
        AdId      bigint NOT NULL
    );

    BEGIN TRY
        BEGIN TRAN;

        
        -- 1) VALIDACIONES BÁSICAS
        

        IF @StartDate > @EndDate
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: La fecha de inicio no puede ser mayor que la fecha de fin.', 16, 1);
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Companies c WHERE c.CompanyId = @CompanyId AND c.active = 1)
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: La compañía indicada no existe o no está activa.', 16, 1);
        END;

        IF @BrandId IS NOT NULL
        BEGIN
            IF NOT EXISTS (
                SELECT 1 
                FROM dbo.Brands b 
                WHERE b.BrandId = @BrandId 
                  AND b.CompanyId = @CompanyId
            )
            BEGIN
                RAISERROR('CAMSP_CreateCampaign: La marca indicada no pertenece a la compañía.', 16, 1);
            END;
        END;

        IF NOT EXISTS (SELECT 1 FROM @Markets)
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Debe indicar al menos un MarketId en el TVP @Markets.', 16, 1);
        END;

        IF NOT EXISTS (SELECT 1 FROM @Ads)
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Debe indicar al menos un anuncio en el TVP @Ads.', 16, 1);
        END;

        -- Validar que todos los MarketId existan
        IF EXISTS (
            SELECT m.MarketId
            FROM @Markets m
            LEFT JOIN dbo.Markets mk ON mk.MarketId = m.MarketId
            WHERE mk.MarketId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen MarketId en @Markets que no están registrados en dbo.Markets.', 16, 1);
        END;

        -- Validar que todos los AdTypeId existan
        IF EXISTS (
            SELECT a.AdTypeId
            FROM @Ads a
            LEFT JOIN dbo.AdTypes t ON t.AdTypeId = a.AdTypeId
            WHERE t.AdTypeId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen AdTypeId en @Ads que no están registrados en dbo.AdTypes.', 16, 1);
        END;

        -- Validar que todos los ChannelId existan (si se envía algo en @AdChannels)
        IF EXISTS (
            SELECT ac.ChannelId
            FROM @AdChannels ac
            LEFT JOIN dbo.Channels ch ON ch.ChannelId = ac.ChannelId
            WHERE ch.ChannelId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen ChannelId en @AdChannels que no están registrados en dbo.Channels.', 16, 1);
        END;

        -- Validar que TempAdKey de @AdChannels exista en @Ads
        IF EXISTS (
            SELECT ac.TempAdKey
            FROM @AdChannels ac
            LEFT JOIN @Ads a ON a.TempAdKey = ac.TempAdKey
            WHERE a.TempAdKey IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Hay filas en @AdChannels cuyo TempAdKey no existe en @Ads.', 16, 1);
        END;


        
        -- 2) RESOLVER IDs POR DEFECTO (Campaña y Ads)
        

        -- Estado por defecto para campañas: 'Planificada'
        IF @CampaignStatusId IS NULL
        BEGIN
            SELECT @DefaultStatusId = cs.CampaignStatusId
            FROM dbo.CampaignStatus cs
            WHERE cs.name = 'Planificada';

            IF @DefaultStatusId IS NULL
            BEGIN
                RAISERROR('CAMSP_CreateCampaign: No se encontró CampaignStatus con nombre ''Planificada''.', 16, 1);
            END;

            SET @CampaignStatusId = @DefaultStatusId;
        END;

        -- Estado por defecto para Ads: 'Borrador'
        SELECT @DefaultAdStatusId = s.AdStatusId
        FROM dbo.AdStatus s
        WHERE s.name = 'Borrador';

        IF @DefaultAdStatusId IS NULL
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: No se encontró AdStatus con nombre ''Borrador''.', 16, 1);
        END;


        
        -- 3) INSERTAR CAMPAÑA
        

        INSERT INTO dbo.Campaigns
        (
            [name],
            [description],
            [createdAt],
            [updatedAt],
            [startDate],
            [endDate],
            [budget],
            [CompanyId],
            [CampaignStatusId],
            [BrandId]
        )
        VALUES
        (
            @Name,
            @Description,
            @Now,
            NULL,
            @StartDate,
            @EndDate,
            @Budget,
            @CompanyId,
            @CampaignStatusId,
            @BrandId
        );

        SET @NewCampaignId = SCOPE_IDENTITY();
        PRINT CONCAT('CAMSP_CreateCampaign: Campaign creada con CampaignId = ', @NewCampaignId, '.');


        
        -- 4) INSERTAR CAMPAIGNMARKETS
        

        INSERT INTO dbo.CampaignMarkets (CampaignId, MarketId)
        SELECT
            @NewCampaignId,
            m.MarketId
        FROM @Markets m
        GROUP BY m.MarketId;   -- Evitamos duplicados

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' CampaignMarkets.');


        
        -- 5) PREPARAR ADS (STAGING con rn)
        

        INSERT INTO @AdsOrdered
        (
            TempAdKey, [name], [description], AdTypeId, AdStatusId
        )
        SELECT
            TempAdKey,
            [name],
            [description],
            AdTypeId,
            AdStatusId
        FROM @Ads
        ORDER BY TempAdKey;  -- definimos un orden determinista


        
        -- 6) INSERTAR ADS REALES
        

        INSERT INTO dbo.Ads
        (
            CampaignId,
            [name],
            [description],
            [createdAt],
            [updatedAt],
            AdStatusId,
            AdTypeId
        )
        SELECT
            @NewCampaignId,
            ao.[name],
            ao.[description],
            @Now,
            NULL,
            ISNULL(ao.AdStatusId, @DefaultAdStatusId),
            ao.AdTypeId
        FROM @AdsOrdered ao
        ORDER BY ao.rn;

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' Ads.');


        
        -- 7) CONSTRUIR MAPPING TempAdKey -> AdId USANDO rn
        

        ;WITH NewAdsCTE AS
        (
            SELECT
                AdId,
                ROW_NUMBER() OVER (ORDER BY AdId) AS rn
            FROM dbo.Ads
            WHERE CampaignId = @NewCampaignId
        )
        INSERT INTO @NewAds (TempAdKey, AdId)
        SELECT
            ao.TempAdKey,
            n.AdId
        FROM @AdsOrdered ao
        JOIN NewAdsCTE  n ON n.rn = ao.rn;

        PRINT 'CAMSP_CreateCampaign: Mapping TempAdKey -> AdId construido.';


        
        -- 8) INSERTAR CHANNELS POR AD
        

        INSERT INTO dbo.ChannelsPerAd
        (
            AdId,
            ChannelId
            -- enabled usa default
        )
        SELECT
            na.AdId,
            ac.ChannelId
        FROM @AdChannels ac
        JOIN @NewAds     na ON na.TempAdKey = ac.TempAdKey;

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' ChannelsPerAd.');


        
        -- 9) COMMIT Y RESULTADOS
        

        COMMIT TRAN;

        -- Devolvemos info de la campaña
        SELECT
            @NewCampaignId AS CampaignId,
            @Name          AS CampaignName,
            @StartDate     AS StartDate,
            @EndDate       AS EndDate,
            @Budget        AS Budget;

        -- Devolvemos mapping de Ads creados
        SELECT
            na.AdId,
            na.TempAdKey
        FROM @NewAds na;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        DECLARE 
            @ErrMsg      nvarchar(4000) = ERROR_MESSAGE(),
            @ErrSeverity int           = ERROR_SEVERITY(),
            @ErrState    int           = ERROR_STATE();

        PRINT CONCAT('CAMSP_CreateCampaign: ERROR - ', @ErrMsg);
        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END;
GO




----------------- EJEMPLO -----------------

DECLARE @Markets dbo.TVP_CampaignMarkets;
DECLARE @Ads     dbo.TVP_CampaignAds;
DECLARE @AdCh    dbo.TVP_AdChannels;

-- Mercados
INSERT INTO @Markets (MarketId)
VALUES (1), (2), (3);

-- Anuncios
INSERT INTO @Ads (TempAdKey, [name], [description], AdTypeId, AdStatusId)
VALUES 
    (1, 'Ad lanzamiento', 'Anuncio principal', 1, NULL),   -- usará AdStatus 'Borrador'
    (2, 'Ad remarketing', 'Seguimiento a interesados', 2, NULL);

-- Canales por anuncio
INSERT INTO @AdCh (TempAdKey, ChannelId)
VALUES
    (1, 1),    -- Ad 1 en Facebook
    (1, 2),    -- Ad 1 en Instagram
    (2, 3);    -- Ad 2 en TikTok

EXEC dbo.CAMSP_CreateCampaign
    @CompanyId        = 1,
    @BrandId          = 1,
    @Name             = 'Campaña Black Friday',
    @Description      = 'Campaña para ventas de Black Friday',
    @StartDate        = '2025-11-01',
    @EndDate          = '2025-11-30',
    @Budget           = 50000,
    @CampaignStatusId = NULL,       -- se usa 'Planificada'
    @Markets          = @Markets,
    @Ads              = @Ads,
    @AdChannels       = @AdCh;
