USE PromptAds;
GO

/* ============================================================
   DEFINICIÓN DE TIPOS DE TABLA (TVPs)
   Estos TVPs se usan para pasar datos "en lote" al SP:
   - @Markets: lista de MarketId para la campaña.
   - @Ads:     lista de anuncios de la campaña.
   - @AdChannels: canales para cada anuncio (ligados por TempAdKey).
============================================================ */


IF TYPE_ID('dbo.TVP_CampaignMarkets') IS NOT NULL
    DROP TYPE dbo.TVP_CampaignMarkets;
GO

-- TVP para la lista de mercados de la campaña
CREATE TYPE dbo.TVP_CampaignMarkets AS TABLE
(
    MarketId bigint NOT NULL   -- Debe existir en dbo.Markets
);
GO



IF TYPE_ID('dbo.TVP_CampaignAds') IS NOT NULL
    DROP TYPE dbo.TVP_CampaignAds;
GO

-- TVP para la lista de anuncios de la campaña
CREATE TYPE dbo.TVP_CampaignAds AS TABLE
(
    TempAdKey     int           NOT NULL,   -- Identificador temporal del anuncio en el TVP
    [name]        varchar(100)  NOT NULL,   -- Nombre del anuncio
    [description] varchar(400)  NULL,       -- Descripción del anuncio
    AdTypeId      int           NOT NULL,   -- Debe existir en dbo.AdTypes
    AdStatusId    int           NULL        -- Si viene NULL se usará 'Borrador' dentro del SP
);
GO



IF TYPE_ID('dbo.TVP_AdChannels') IS NOT NULL
    DROP TYPE dbo.TVP_AdChannels;
GO

-- TVP para canales por anuncio, enlazados por TempAdKey
CREATE TYPE dbo.TVP_AdChannels AS TABLE
(
    TempAdKey int     NOT NULL,   -- Debe existir en TVP_CampaignAds.TempAdKey
    ChannelId bigint  NOT NULL    -- Debe existir en dbo.Channels
);
GO


/* 
   SP_CreateCampaign
   Objetivo:
     - Crear una campaña completa (Campaigns) de forma TRANSACCIONAL.
     - Insertar:
         * Campaign
         * CampaignMarkets (mercados asociados)
         * Ads de la campaña
         * ChannelsPerAd (canales por anuncio)
     - Usar TVPs para recibir la info de mercados, anuncios y canales.
   Convención de nombre:
     - CAMSP_  = "Stored Procedure de Campaign"
     - CreateCampaign = verbo + entidad
*/


IF OBJECT_ID('dbo.CAMSP_CreateCampaign', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CAMSP_CreateCampaign;
GO

CREATE PROCEDURE dbo.CAMSP_CreateCampaign
    @CompanyId        bigint,                           -- Compañía dueña de la campaña
    @BrandId          bigint = NULL,                    -- Marca (puede ser NULL)
    @Name             varchar(150),                     -- Nombre de la campaña
    @Description      varchar(400) = NULL,              -- Descripción de la campaña
    @StartDate        datetime,                         -- Fecha de inicio
    @EndDate          datetime,                         -- Fecha de fin
    @Budget           decimal(18,2),                    -- Presupuesto de la campaña
    @CampaignStatusId int = NULL,                       -- Estado de campaña (si NULL se usa 'Planificada')
    @Markets          dbo.TVP_CampaignMarkets READONLY, -- Lista de mercados
    @Ads              dbo.TVP_CampaignAds      READONLY, -- Lista de anuncios
    @AdChannels       dbo.TVP_AdChannels       READONLY  -- Canales por anuncio (TempAdKey)
AS
BEGIN
    SET NOCOUNT ON;  

    DECLARE 
        @NewCampaignId      bigint,          -- Id de la campaña recién creada
        @Now                datetime = GETDATE(), -- Timestamp de creación
        @DefaultStatusId    int,             -- Id de CampaignStatus 'Planificada'
        @DefaultAdStatusId  int;             -- Id de AdStatus 'Borrador'

    /* Tabla staging para los Ads:
       - Copia el contenido del TVP @Ads
       - Agrega una columna rn para tener un orden fijo
       - Ayuda a mapear luego TempAdKey -> AdId de forma determinista
    */
    DECLARE @AdsOrdered TABLE
    (
        rn         int IDENTITY(1,1) PRIMARY KEY,   -- índice secuencial
        TempAdKey  int           NOT NULL,
        [name]     varchar(100)  NOT NULL,
        [description] varchar(400) NULL,
        AdTypeId   int           NOT NULL,
        AdStatusId int           NULL
    );

    /* Tabla temporal para mapear TempAdKey (del TVP) con el AdId real
       que se genera en Ads
    */
    DECLARE @NewAds TABLE
    (
        TempAdKey int NOT NULL,
        AdId      bigint NOT NULL
    );

    BEGIN TRY
        BEGIN TRAN;  -- Inicio transacción

        
        -- VALIDACIONES BÁSICAS DE ENTRADA
        

        -- Validar que la fecha de inicio no sea mayor que la de fin
        IF @StartDate > @EndDate
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: La fecha de inicio no puede ser mayor que la fecha de fin.', 16, 1);
        END;

        -- Validar que la compañía exista y esté activa
        IF NOT EXISTS (
            SELECT 1 
            FROM dbo.Companies c 
            WHERE c.CompanyId = @CompanyId 
              AND c.active = 1
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: La compañía indicada no existe o no está activa.', 16, 1);
        END;

        -- Si viene BrandId, validar que esa marca pertenezca a la compañía
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

        -- Debe venir al menos un MarketId en el TVP @Markets
        IF NOT EXISTS (SELECT 1 FROM @Markets)
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Debe indicar al menos un MarketId en el TVP @Markets.', 16, 1);
        END;

        -- Debe venir al menos un Ad en el TVP @Ads
        IF NOT EXISTS (SELECT 1 FROM @Ads)
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Debe indicar al menos un anuncio en el TVP @Ads.', 16, 1);
        END;

        -- Validar que todos los MarketId existan en dbo.Markets
        IF EXISTS (
            SELECT m.MarketId
            FROM @Markets m
            LEFT JOIN dbo.Markets mk ON mk.MarketId = m.MarketId
            WHERE mk.MarketId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen MarketId en @Markets que no están registrados en dbo.Markets.', 16, 1);
        END;

        -- Validar que todos los AdTypeId existan en dbo.AdTypes
        IF EXISTS (
            SELECT a.AdTypeId
            FROM @Ads a
            LEFT JOIN dbo.AdTypes t ON t.AdTypeId = a.AdTypeId
            WHERE t.AdTypeId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen AdTypeId en @Ads que no están registrados en dbo.AdTypes.', 16, 1);
        END;

        -- Validar que todos los ChannelId de @AdChannels existan en dbo.Channels
        IF EXISTS (
            SELECT ac.ChannelId
            FROM @AdChannels ac
            LEFT JOIN dbo.Channels ch ON ch.ChannelId = ac.ChannelId
            WHERE ch.ChannelId IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Existen ChannelId en @AdChannels que no están registrados en dbo.Channels.', 16, 1);
        END;

        -- Validar que todos los TempAdKey en @AdChannels existan en @Ads
        IF EXISTS (
            SELECT ac.TempAdKey
            FROM @AdChannels ac
            LEFT JOIN @Ads a ON a.TempAdKey = ac.TempAdKey
            WHERE a.TempAdKey IS NULL
        )
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: Hay filas en @AdChannels cuyo TempAdKey no existe en @Ads.', 16, 1);
        END;


        
        -- RESOLVER IDs POR DEFECTO (Campaña y Ads)
        

        -- Si no se pasó CampaignStatusId, usar el estado 'Planificada'
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

        -- Obtener el estado por defecto para Ads = 'Borrador'
        SELECT @DefaultAdStatusId = s.AdStatusId
        FROM dbo.AdStatus s
        WHERE s.name = 'Borrador';

        IF @DefaultAdStatusId IS NULL
        BEGIN
            RAISERROR('CAMSP_CreateCampaign: No se encontró AdStatus con nombre ''Borrador''.', 16, 1);
        END;


        
        -- INSERTAR CAMPAÑA PRINCIPAL
        

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
            NULL,             -- updatedAt inicialmente NULL
            @StartDate,
            @EndDate,
            @Budget,
            @CompanyId,
            @CampaignStatusId,
            @BrandId
        );

        -- Obtenemos el ID generado por identidad
        SET @NewCampaignId = SCOPE_IDENTITY();
        PRINT CONCAT('CAMSP_CreateCampaign: Campaign creada con CampaignId = ', @NewCampaignId, '.');


        
        -- INSERTAR CAMPAIGNMARKETS (MERCADOS ASOCIADOS)
        

        INSERT INTO dbo.CampaignMarkets (CampaignId, MarketId)
        SELECT
            @NewCampaignId,
            m.MarketId
        FROM @Markets m
        GROUP BY m.MarketId;   -- Por si en el TVP vienen repetidos

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' CampaignMarkets.');


        
        -- PREPARAR ADS EN TABLA STAGING (@AdsOrdered)
        

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
        ORDER BY TempAdKey;  -- definimos un orden determinista por TempAdKey


        
        -- INSERTAR ADS REALES EN dbo.Ads
        

        INSERT INTO dbo.Ads
        (
            CampaignId,
            [name],
            [description],
            [createdAt],
            [updatedAt],
            AdStatusId,
            AdTypeId
            -- enabled, deleted, processed usan sus DEFAULTs
        )
        SELECT
            @NewCampaignId,
            ao.[name],
            ao.[description],
            @Now,
            NULL,
            ISNULL(ao.AdStatusId, @DefaultAdStatusId), -- si viene NULL se usa 'Borrador'
            ao.AdTypeId
        FROM @AdsOrdered ao
        ORDER BY ao.rn;  -- mismo orden que en @AdsOrdered

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' Ads.');


        
        -- CONSTRUIR MAPPING TempAdKey -> AdId USANDO rn
        

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


        
        -- INSERTAR CHANNELS POR AD EN dbo.ChannelsPerAd
        

        INSERT INTO dbo.ChannelsPerAd
        (
            AdId,
            ChannelId
            -- enabled utiliza el default de la tabla
        )
        SELECT
            na.AdId,        -- Ad real (Identity)
            ac.ChannelId    -- Canal que venía en el TVP, ligado por TempAdKey
        FROM @AdChannels ac
        JOIN @NewAds     na ON na.TempAdKey = ac.TempAdKey;

        PRINT CONCAT('CAMSP_CreateCampaign: Insertados ', @@ROWCOUNT, ' ChannelsPerAd.');


        
        -- COMMIT DE LA TRANSACCIÓN Y RESULTADOS
        

        COMMIT TRAN;

        -- Devolvemos un resumen de la campaña creada
        SELECT
            @NewCampaignId AS CampaignId,
            @Name          AS CampaignName,
            @StartDate     AS StartDate,
            @EndDate       AS EndDate,
            @Budget        AS Budget;

        -- Devolvemos el mapping de Ads creados (AdId real vs TempAdKey)
        SELECT
            na.AdId,
            na.TempAdKey
        FROM @NewAds na;

    END TRY
    BEGIN CATCH
        -- En caso de error, revertimos la transacción y propagamos mensaje
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


/*
   EJEMPLO DE USO DEL SP CON TVPs
*/

DECLARE @Markets dbo.TVP_CampaignMarkets;
DECLARE @Ads     dbo.TVP_CampaignAds;
DECLARE @AdCh    dbo.TVP_AdChannels;

-- Mercados de la campaña
INSERT INTO @Markets (MarketId)
VALUES (1), (2), (3);

-- Anuncios de la campaña
INSERT INTO @Ads (TempAdKey, [name], [description], AdTypeId, AdStatusId)
VALUES 
    (1, 'Ad lanzamiento',  'Anuncio principal',           1, NULL), -- usará AdStatus 'Borrador'
    (2, 'Ad remarketing', 'Seguimiento a interesados',    2, NULL);

-- Canales por anuncio (usando TempAdKey)
INSERT INTO @AdCh (TempAdKey, ChannelId)
VALUES
    (1, 1),    -- Ad 1 en canal 1 (ej. Facebook)
    (1, 2),    -- Ad 1 en canal 2 (ej. Instagram)
    (2, 3);    -- Ad 2 en canal 3 (ej. TikTok)

-- Llamada al SP de negocio
EXEC dbo.CAMSP_CreateCampaign
    @CompanyId        = 1,
    @BrandId          = 1,
    @Name             = 'Campaña Navidad',
    @Description      = 'Campaña para ventas de Navidad',
    @StartDate        = '2025-11-01',
    @EndDate          = '2025-12-25',
    @Budget           = 50000,
    @CampaignStatusId = NULL,       -- se usará estado 'Planificada'
    @Markets          = @Markets,
    @Ads              = @Ads,
    @AdChannels       = @AdCh;
