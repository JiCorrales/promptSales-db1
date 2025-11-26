USE PromptAds;
GO

/*========================================================
  SP: sp_Seed_Campaigns_Ads_Markets
  PRE-REQUISITOS:
    1) Script DDL ejecutado.
    2) Script Specific Data ejecutado (Countries, States, Cities, Channels, AdTypes, etc.).
    3) Script Datos Auxiliares ejecutado (Numbers, funciones).
    4) sp_Seed_Users_Companies_Basics ejecutado (Companies, Brands).
========================================================*/

IF OBJECT_ID('dbo.sp_Seed_Campaigns_Ads_Markets', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Seed_Campaigns_Ads_Markets;
GO

CREATE PROCEDURE dbo.sp_Seed_Campaigns_Ads_Markets
    @CampaignsCount int = 60000,
    @AdsPerCampaign int = 5,
    @MarketsCount   int = 2000,
    @Influencers    int = 50000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @startCampId  bigint,
            @startAdId    bigint,
            @startInflId  bigint,
            @rows         int;

    BEGIN TRY
        BEGIN TRAN;

        /*-----------------------------
          Markets (coherentes con Country/State/City)
        -----------------------------*/
        IF NOT EXISTS (SELECT 1 FROM dbo.Markets)
        BEGIN
            INSERT INTO dbo.Markets(name, description, CountryId, StateId, CityId)
            SELECT TOP (@MarketsCount)
                CONCAT('Mercado ', ci.name),
                'Segmento geográfico/comercial objetivo',
                c.CountryId,
                s.StateId,
                ci.CityId
            FROM dbo.Cities ci
            JOIN dbo.States s    ON ci.StateId  = s.StateId
            JOIN dbo.Countries c ON s.CountryId = c.CountryId
            ORDER BY ci.CityId;

            SET @rows = @@ROWCOUNT;
            PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' Markets.');
        END
        ELSE
        BEGIN
            PRINT 'sp_Seed_Campaigns_Ads_Markets: Markets ya existen, no se insertan nuevos.';
        END

        /*-----------------------------
          Campaigns (nueva lógica)
          - 30% Activa, 70% Finalizada/Cancelada
          - Fechas entre 2024-07-01 y 2026-01-31
          - Picos en diciembre, enero y agosto
        -----------------------------*/
        DECLARE @MinStartDate   date = '2024-07-01';
        DECLARE @MaxEndDate     date = '2026-01-31';

        DECLARE @StatusActiva      int,
                @StatusFinalizada  int,
                @StatusCancelada   int;

        SELECT @startCampId = ISNULL(MAX(CampaignId),0)
        FROM dbo.Campaigns;

        -- IDs de status por nombre (no quemamos números)
        SELECT @StatusActiva     = CampaignStatusId FROM dbo.CampaignStatus WHERE name = 'Activa';
        SELECT @StatusFinalizada = CampaignStatusId FROM dbo.CampaignStatus WHERE name = 'Finalizada';
        SELECT @StatusCancelada  = CampaignStatusId FROM dbo.CampaignStatus WHERE name = 'Cancelada';

        IF @StatusActiva IS NULL OR @StatusFinalizada IS NULL OR @StatusCancelada IS NULL
        BEGIN
            RAISERROR('sp_Seed_Campaigns_Ads_Markets: Deben existir CampaignStatus Activa / Finalizada / Cancelada antes de ejecutar este procedimiento.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END

        -- Tabla de meses con pesos (100 filas, patrón que se repite)
        DECLARE @Months TABLE(
            MonthKey int IDENTITY(1,1) PRIMARY KEY,
            [Year]   int NOT NULL,
            [Month]  int NOT NULL
        );

        -- 30% Diciembre (15 x 2024-12, 15 x 2025-12)
        INSERT INTO @Months([Year], [Month])
        SELECT TOP (15) 2024, 12 FROM dbo.Numbers
        UNION ALL
        SELECT TOP (15) 2025, 12 FROM dbo.Numbers;

        -- 25% Enero (13 x 2025-01, 12 x 2026-01)
        INSERT INTO @Months([Year], [Month])
        SELECT TOP (13) 2025, 1  FROM dbo.Numbers
        UNION ALL
        SELECT TOP (12) 2026, 1  FROM dbo.Numbers;

        -- 20% Agosto (10 x 2024-08, 10 x 2025-08)
        INSERT INTO @Months([Year], [Month])
        SELECT TOP (10) 2024, 8  FROM dbo.Numbers
        UNION ALL
        SELECT TOP (10) 2025, 8  FROM dbo.Numbers;

        -- 25% otros meses dentro de la ventana: Jul, Sep, Oct 2024; Feb, Mar 2025
        INSERT INTO @Months([Year], [Month])
        SELECT TOP (5) 2024, 7 FROM dbo.Numbers
        UNION ALL
        SELECT TOP (5) 2024, 9 FROM dbo.Numbers
        UNION ALL
        SELECT TOP (5) 2024,10 FROM dbo.Numbers
        UNION ALL
        SELECT TOP (5) 2025, 2 FROM dbo.Numbers
        UNION ALL
        SELECT TOP (5) 2025, 3 FROM dbo.Numbers;

        DECLARE @MonthsCount int;
        SELECT @MonthsCount = COUNT(*) FROM @Months;

        -- Semillas de campañas: RowNum, StartDate, EndDate, Status
        IF OBJECT_ID('tempdb..#CampaignSeeds') IS NOT NULL
            DROP TABLE #CampaignSeeds;

        CREATE TABLE #CampaignSeeds(
            RowNum    int   NOT NULL PRIMARY KEY,
            StartDate date  NOT NULL,
            EndDate   date  NOT NULL,
            StatusId  int   NOT NULL
        );

        ;WITH CteN AS (
            SELECT TOP (@CampaignsCount)
                   ROW_NUMBER() OVER (ORDER BY n.n) AS RowNum,
                   n.n AS Seed
            FROM dbo.Numbers n
            ORDER BY n.n
        )
        INSERT INTO #CampaignSeeds(RowNum, StartDate, EndDate, StatusId)
        SELECT
            c.RowNum,
            sdt.StartDate,
            CASE 
                WHEN DATEADD(DAY, offDays, sdt.StartDate) > @MaxEndDate 
                     THEN @MaxEndDate
                ELSE DATEADD(DAY, offDays, sdt.StartDate)
            END AS EndDate,
            CASE 
                WHEN (c.RowNum - 1) % 10 < 3 THEN @StatusActiva      -- 30% Activa
                WHEN (c.RowNum - 1) % 10 < 9 THEN @StatusFinalizada  -- 60% Finalizada
                ELSE                          @StatusCancelada       -- 10% Cancelada
            END AS StatusId
        FROM CteN c
        CROSS APPLY (
            SELECT m.[Year], m.[Month]
            FROM @Months m
            WHERE m.MonthKey = ((c.RowNum - 1) % @MonthsCount) + 1
        ) mm
        CROSS APPLY (
            SELECT 
                DATEADD(
                    DAY,
                    ABS(CHECKSUM(c.Seed * 31)) % DAY(EOMONTH(DATEFROMPARTS(mm.[Year], mm.[Month], 1))),
                    DATEFROMPARTS(mm.[Year], mm.[Month], 1)
                ) AS StartDate
        ) sdt
        CROSS APPLY (
            SELECT dbo.fn_RandBetween(c.Seed, 7, 90) AS offDays
        ) o;

        -- Aseguramos no caer antes de 2024-07-01
        UPDATE #CampaignSeeds
        SET StartDate = CASE WHEN StartDate < @MinStartDate THEN @MinStartDate ELSE StartDate END,
            EndDate   = CASE WHEN EndDate   < @MinStartDate THEN DATEADD(DAY, 7, @MinStartDate) ELSE EndDate END;

        -- Tabla auxiliar: una marca por compañía (para BrandId simple y eficiente)
        DECLARE @CompanyRange bigint,
                @MinCompanyId bigint,
                @MaxCompanyId bigint;

        SELECT @MinCompanyId = MIN(CompanyId),
               @MaxCompanyId = MAX(CompanyId)
        FROM dbo.Companies;

        IF @MinCompanyId IS NULL
        BEGIN
            RAISERROR('sp_Seed_Campaigns_Ads_Markets: Deben existir Companies antes de generar campañas.', 16, 1);
            ROLLBACK TRAN;
            RETURN;
        END

        SET @CompanyRange = @MaxCompanyId - @MinCompanyId + 1;

        DECLARE @CompanyBrands TABLE(
            CompanyId     bigint PRIMARY KEY,
            SampleBrandId bigint NULL
        );

        INSERT INTO @CompanyBrands(CompanyId, SampleBrandId)
        SELECT c.CompanyId,
               MIN(b.BrandId) AS SampleBrandId
        FROM dbo.Companies c
        LEFT JOIN dbo.Brands b
            ON b.CompanyId = c.CompanyId
        GROUP BY c.CompanyId;

        -- Inserción final de campañas
        INSERT INTO dbo.Campaigns
            (name, description, createdAt, updatedAt,
             startDate, endDate, budget,
             CompanyId, CampaignStatusId, BrandId)
        SELECT
            CONCAT('Campaña ', @startCampId + cs.RowNum),
            'Campaña multicanal generada algorítmicamente',
            cs.StartDate,      -- createdAt
            cs.EndDate,        -- updatedAt
            cs.StartDate,
            cs.EndDate,
            CAST(dbo.fn_RandBetween(cs.RowNum, 500, 50000) AS decimal(18,2)) AS budget,
            comp.CompanyId,
            cs.StatusId,
            cb.SampleBrandId
        FROM #CampaignSeeds cs
        CROSS APPLY (
            SELECT @MinCompanyId + ((cs.RowNum - 1) % @CompanyRange) AS CompanyId
        ) comp
        LEFT JOIN @CompanyBrands cb
            ON cb.CompanyId = comp.CompanyId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT(
            'sp_Seed_Campaigns_Ads_Markets: Insertadas ',
            @rows,
            ' Campaigns (30% activas / 70% culminadas, fechas entre ',
            CONVERT(varchar(10), @MinStartDate, 120),
            ' y ',
            CONVERT(varchar(10), @MaxEndDate, 120),
            ').'
        );

        /*-----------------------------
          CampaignMarkets (2–5 mercados por campaña)
        -----------------------------*/
        INSERT INTO dbo.CampaignMarkets(CampaignId, MarketId)
        SELECT c.CampaignId,
               m.MarketId
        FROM dbo.Campaigns c
        CROSS APPLY (
            SELECT TOP (dbo.fn_RandBetween(c.CampaignId,2,5)) m2.MarketId
            FROM dbo.Markets m2
            ORDER BY CHECKSUM(m2.MarketId, c.CampaignId)
        ) m
        WHERE c.CampaignId > @startCampId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertadas ', @rows, ' CampaignMarkets.');

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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' Influencers.');

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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' Ads.');

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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' ChannelsPerAd.');

        /*-----------------------------
          Media y AdMedias
        -----------------------------*/
        INSERT INTO dbo.Media(MediaTypeId, URL)
        SELECT TOP (100000)
            ((n.n - 1) % (SELECT COUNT(*) FROM dbo.MediaTypes)) + 1,
            CONCAT('https://cdn.promptsales.test/media/', n.n, '.asset')
        FROM dbo.Numbers n;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' Media.');

        INSERT INTO dbo.AdMedias(AdId, MediaId, createdAt, deleted, enabled)
        SELECT TOP (200000)
            a.AdId,
            m.MediaId,
            dbo.fn_RandomDateTime(m.MediaId),
            0,
            1
        FROM dbo.Ads a
        CROSS JOIN dbo.Media m;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' AdMedias.');

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
            PRINT 'sp_Seed_Campaigns_Ads_Markets: Insertados TargetAudience iniciales.';
        END

        IF NOT EXISTS(SELECT 1 FROM dbo.AudienceFeatures)
        BEGIN
            INSERT INTO dbo.AudienceFeatures(name, datatype)
            VALUES ('Edad','int'),('País','string'),('Interés principal','string'),
                   ('Nivel de ingreso','string'),('Frecuencia de compra','int');
            PRINT 'sp_Seed_Campaigns_Ads_Markets: Insertados AudienceFeatures iniciales.';
        END

        IF NOT EXISTS(SELECT 1 FROM dbo.AudienceValues)
        BEGIN
            INSERT INTO dbo.AudienceValues(AudienceFeatureId, name, minValue, maxValue, value)
            SELECT af.AudienceFeatureId,
                   CONCAT('Segmento ', af.name, ' ', n.n),
                   CASE WHEN af.datatype='int' THEN n.n * 5 ELSE NULL END,
                   CASE WHEN af.datatype='int' THEN n.n * 5 + 4 ELSE NULL END,
                   CASE WHEN af.datatype='int' THEN n.n * 5 ELSE NULL END
            FROM dbo.AudienceFeatures af
            CROSS JOIN (SELECT TOP 20 n FROM dbo.Numbers) n;
            PRINT 'sp_Seed_Campaigns_Ads_Markets: Insertados AudienceValues iniciales.';
        END

        IF NOT EXISTS(SELECT 1 FROM dbo.TargetConfig)
        BEGIN
            INSERT INTO dbo.TargetConfig(TargetAudienceId, AudienceValueId, enabled)
            SELECT TOP (5000)
                ta.TargetAudienceId,
                av.AudienceValue,
                1
            FROM dbo.TargetAudience ta
            CROSS JOIN dbo.AudienceValues av;
            PRINT 'sp_Seed_Campaigns_Ads_Markets: Insertados TargetConfig iniciales.';
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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' AdAudience.');

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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' InfluencersPerAd.');

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

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: Insertados ', @rows, ' InfluencerContacts.');

        COMMIT TRAN;
        PRINT 'sp_Seed_Campaigns_Ads_Markets: COMMIT exitoso.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @ErrMsg nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity int       = ERROR_SEVERITY();
        DECLARE @ErrState int          = ERROR_STATE();

        PRINT CONCAT('sp_Seed_Campaigns_Ads_Markets: ERROR - ', @ErrMsg);
        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END;
GO

EXEC sp_Seed_Campaigns_Ads_Markets;
