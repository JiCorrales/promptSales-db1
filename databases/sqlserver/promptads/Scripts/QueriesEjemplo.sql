use PromptAds;



-- Companies que nunca han tenido campañas
SELECT c.CompanyId, c.name
FROM dbo.Companies c

EXCEPT

SELECT DISTINCT ca.CompanyId, c2.name
FROM dbo.Campaigns ca
JOIN dbo.Companies c2 ON c2.CompanyId = ca.CompanyId;


-- BrandId que aparecen tanto en campañas activas como en pausadas
SELECT DISTINCT cActive.BrandId
FROM dbo.Campaigns cActive
JOIN dbo.CampaignStatus csA ON csA.CampaignStatusId = cActive.CampaignStatusId
WHERE csA.name = 'Activa'

INTERSECT

SELECT DISTINCT cPaused.BrandId
FROM dbo.Campaigns cPaused
JOIN dbo.CampaignStatus csP ON csP.CampaignStatusId = cPaused.CampaignStatusId
WHERE csP.name = 'Pausada';



-- Actualizar / insertar watermark de un proceso ETL
MERGE dbo.ETLWatermark AS target
USING (
    SELECT
        'PromptAds_To_PromptSales_Summary' AS processName,
        GETDATE()                           AS LastSuccessAt,
        'Actualización desde proceso ETL'   AS Notes
) AS src
ON target.processName = src.processName
WHEN MATCHED THEN
    UPDATE SET
        target.LastSuccessAt = src.LastSuccessAt,
        target.Notes        = src.Notes
WHEN NOT MATCHED BY TARGET THEN
    INSERT (processName, LastSuccessAt, Notes)
    VALUES (src.processName, src.LastSuccessAt, src.Notes);


    -- Ver cómo LTRIM limpia espacios iniciales en el nombre de campaña
SELECT
    CampaignId,
    name                  AS NombreOriginal,
    LTRIM(name)           AS NombreSinEspaciosIniciales
FROM dbo.Campaigns;



-- Normalizar emails de usuarios (minúsculas y sin espacios a los lados)
SELECT
    UserId,
    email                                   AS EmailOriginal,
    LOWER(LTRIM(RTRIM(email)))             AS EmailNormalizado
FROM dbo.Users;


-- Ejemplo de redondeo de costo en métricas de anuncios
SELECT TOP (20)
    AdId,
    cost,
    FLOOR(cost)    AS CostFloor,   -- redondea hacia abajo
    CEILING(cost)  AS CostCeiling  -- redondea hacia arriba
FROM dbo.AdMetricsDaily
ORDER BY AdId;


-- Bucket de impresiones en miles
SELECT
    AdId,
    impressions,
    FLOOR(impressions / 1000.0)  AS MilesImpresionesFloor,
    CEILING(impressions / 1000.0) AS MilesImpresionesCeil
FROM dbo.AdMetricsDaily;


;WITH ReachCalc AS (
    SELECT
        AdId,
        posttime,
        FLOOR(impressions * 0.8) AS NewReach
    FROM dbo.AdMetricsDaily
)
UPDATE amd
SET amd.publicReach = rc.NewReach
FROM dbo.AdMetricsDaily amd
JOIN ReachCalc rc
  ON amd.AdId     = rc.AdId
 AND amd.posttime = rc.posttime;
