use PromptAds;

IF OBJECT_ID('dbo.sp_Seed_Metrics_Social_Logs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Seed_Metrics_Social_Logs;
GO

CREATE PROCEDURE dbo.sp_Seed_Metrics_Social_Logs
    @MetricsRows int = 300000,
    @SocialRows  int = 200000,
    @Payments    int = 150000,
    @LogsRows    int = 300000,
    @AuditRows   int = 100000
AS
BEGIN
    SET NOCOUNT ON;

    /*-----------------------------
      Payments
    -----------------------------*/
    DECLARE @startPayId bigint = ISNULL((SELECT MAX(PaymentId) FROM dbo.Payments),0);

    INSERT INTO dbo.Payments(PayMethodId, PayTypeId, payAmount, CurrencyId,
                             description, createdAt, checksum, PayStatusId)
    SELECT TOP (@Payments)
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.PaymentMethods)) + 1,
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.PaymentTypes)) + 1,
        CAST(dbo.fn_RandBetween(n.n, 50, 50000) AS decimal(18,2)),
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.Currencies)) + 1,
        'Pago generado aleatoriamente para campaña',
        dbo.fn_RandomDateTime(n.n),
        CONVERT(char(64),
                HASHBYTES('SHA2_256', CONCAT('pay', n.n)),2),
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.PaymentStatuses)) + 1
    FROM dbo.Numbers n;

    /*-----------------------------
      CampaignTransactionTypes
    -----------------------------*/
    IF NOT EXISTS(SELECT 1 FROM dbo.CampaignTransactionTypes)
    BEGIN
        INSERT INTO dbo.CampaignTransactionTypes(name, enabled)
        VALUES ('Compra de impresiones',1),
               ('Compra de clicks',1),
               ('Fee de influencer',1),
               ('Comisión de plataforma',1),
               ('Ajuste contable',1);
    END

    /*-----------------------------
      CampaignTransactions
    -----------------------------*/
    INSERT INTO dbo.CampaignTransactions
    (description, amount, CampaignTransTypeId, AdId, PaymentId, MediaId,
     checksum, updatedAt)
    SELECT TOP (@Payments)
        'Transacción asociada al pago y anuncio',
        p.payAmount,
        ((p.PaymentId - @startPayId - 1) % (SELECT COUNT(*) FROM dbo.CampaignTransactionTypes)) + 1,
        a.AdId,
        p.PaymentId,
        m.MediaId,
        CONVERT(char(64),
                HASHBYTES('SHA2_256', CONCAT('ctrx', p.PaymentId)),2),
        dbo.fn_RandomDateTime(p.PaymentId)
    FROM dbo.Payments p
    CROSS JOIN (SELECT TOP 1 AdId FROM dbo.Ads ORDER BY NEWID()) a
    CROSS JOIN (SELECT TOP 1 MediaId FROM dbo.Media ORDER BY NEWID()) m;

    /*-----------------------------
      AdMetricsDaily
    -----------------------------*/
    INSERT INTO dbo.AdMetricsDaily
    (AdId, AdMediaId, posttime, impressions, clicks, interactions, publicReach,
     hoursViewed, cost, revenue, updatedAt, likes, salesCount)
    SELECT TOP (@MetricsRows)
        am.AdId,
        am.AdMediaId,
        dbo.fn_RandomDateTime(n.n + am.AdId),
        CAST(dbo.fn_RandBetween(n.n, 100, 500000) AS bigint),                          -- impressions
        CAST(dbo.fn_RandBetween(n.n, 10, 50000) AS bigint),                            -- clicks
        CAST(dbo.fn_RandBetween(n.n, 5, 100000) AS bigint),                            -- interactions
        CAST(dbo.fn_RandBetween(n.n, 50, 400000) AS bigint),                           -- publicReach
        CAST(dbo.fn_RandBetween(n.n, 1, 2000) / 10.0 AS decimal(18,3)),                -- hoursViewed
        CAST(dbo.fn_RandBetween(n.n, 10, 2000) AS decimal(18,2)),                      -- cost
        CAST(dbo.fn_RandBetween(n.n, 20, 10000) AS decimal(18,2)),                     -- revenue
        dbo.fn_RandomDateTime(n.n + 500000),
        CAST(dbo.fn_RandBetween(n.n, 0, 100000) AS bigint),                            -- likes
        CAST(dbo.fn_RandBetween(n.n, 0, 5000) AS bigint)                               -- salesCount
    FROM dbo.Numbers n
    CROSS JOIN (
        SELECT TOP (100000) AdMediaId, AdId
        FROM dbo.AdMedias
        ORDER BY NEWID()
    ) am;

    /*-----------------------------
      SocialFeeling
    -----------------------------*/
    INSERT INTO dbo.SocialFeeling
    (AdId, InfluencerId, AdMediaId, feelingScore, sampleSize,
     details, posttime, updatedAt, SentimentTypeId)
    SELECT TOP (@SocialRows)
        ipa.AdId,
        ipa.InfluencerId,
        am.AdMediaId,
        CAST(dbo.fn_RandBetween(n.n, -50, 100) / 10.0 AS decimal(4,2)),  -- puede ser negativo
        dbo.fn_RandBetween(n.n, 50, 5000),
        'Muestra de comentarios y reacciones',
        dbo.fn_RandomDateTime(n.n + ipa.AdId),
        dbo.fn_RandomDateTime(n.n + ipa.AdId + 500000),
        CASE 
            WHEN dbo.fn_RandBetween(n.n, -50, 100) < 0 THEN 3  -- Negative
            WHEN dbo.fn_RandBetween(n.n, -50, 100) < 30 THEN 2 -- Neutral
            ELSE 1                                             -- Positive
        END
    FROM dbo.Numbers n
    CROSS JOIN (
        SELECT TOP (100000) InfluencerId, AdId
        FROM dbo.InfluencersPerAd
        ORDER BY NEWID()
    ) ipa
    CROSS JOIN (
        SELECT TOP 1 AdMediaId FROM dbo.AdMedias ORDER BY NEWID()
    ) am;

    /*-----------------------------
      ReactionsPerAd (conteos globales por tipo)
    -----------------------------*/
    INSERT INTO dbo.ReactionsPerAd(ReactionTypeId, AdId)
    SELECT TOP (200000)
        rt.ReactionTypeId,
        a.AdId
    FROM dbo.ReactionTypes rt
    CROSS JOIN dbo.Ads a;

    /*-----------------------------
      Logs
    -----------------------------*/
    INSERT INTO dbo.Logs
    (description, computer, username, LogTypeId, LogLevelId, LogSourceId,
     RefId, UserId, toolName, createdAt)
    SELECT TOP (@LogsRows)
        'Evento de sistema generado para prueba',
        CONCAT('PC-', n.n % 200),
        CONCAT('user', (n.n % (SELECT COUNT(*) FROM dbo.Users)) + 1),
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.LogTypes)) + 1,
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.LogLevels)) + 1,
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.LogSources)) + 1,
        NULL,
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.Users)) + 1,
        CASE WHEN n.n % 3 = 0 THEN 'MCP-Server'
             WHEN n.n % 3 = 1 THEN 'ETL-Job'
             ELSE 'Web-Portal'
        END,
        dbo.fn_RandomDateTime(n.n)
    FROM dbo.Numbers n;

    /*-----------------------------
      AuditAI
    -----------------------------*/
    INSERT INTO dbo.AuditAI
    (UserId, tool, prompt, output, ValidMethodId, createdAt,
     comments, model, entryTokens, outputTokens)
    SELECT TOP (@AuditRows)
        u.UserId,
        CASE WHEN n.n % 2 = 0 THEN 'generateCampaign'
             ELSE 'optimizeBid' END,
        'Prompt usado para la prueba de IA con parámetros simulados',
        'Respuesta generada automáticamente por un modelo de prueba',
        ((n.n - 1) % (SELECT COUNT(*) FROM dbo.ValidationMethods)) + 1,
        dbo.fn_RandomDateTime(n.n),
        'Validación realizada según el método indicado',
        CASE WHEN n.n % 2 = 0 THEN 'gpt-5.1' ELSE 'ads-optimizer-v1' END,
        dbo.fn_RandBetween(n.n, 50, 2000),
        dbo.fn_RandBetween(n.n, 50, 3000)
    FROM dbo.Numbers n
    CROSS JOIN (
        SELECT TOP (1000) UserId FROM dbo.Users ORDER BY NEWID()
    ) u;
END;
GO


select * from Logs;

EXEC dbo.sp_Seed_Metrics_Social_Logs;
