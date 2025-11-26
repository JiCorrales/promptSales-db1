use PromptAds;

-- Companies que nunca han tenido campañas
SELECT c.CompanyId, c.name
FROM dbo.Companies c

EXCEPT

SELECT DISTINCT ca.CompanyId, c2.name
FROM dbo.Campaigns ca
JOIN dbo.Companies c2 ON c2.CompanyId = ca.CompanyId;


-- Marcas con campañas activas
SELECT DISTINCT c.BrandId
FROM dbo.Campaigns c
JOIN dbo.CampaignStatus cs ON cs.CampaignStatusId = c.CampaignStatusId
WHERE cs.name = 'Activa'

INTERSECT

-- Marcas con campañas de alto presupuesto (cualquier estado)
SELECT DISTINCT c2.BrandId
FROM dbo.Campaigns c2
WHERE c2.budget > 20000;



-- Actualizar / insertar watermark de un proceso ETL

SELECT 
    processName,
    LastSuccessAt,
    Notes
FROM dbo.ETLWatermark
WHERE processName = 'PromptAds_To_PromptSales_Summary';

USE PromptAds;
GO



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
SELECT TOP (10)
    c.CampaignId,
    c.name                         AS NombreOriginal,
    '   ' + c.name                 AS NombreConEspaciosSimulados,
    LTRIM('   ' + c.name)          AS NombreDespuesDeLTRIM
FROM dbo.Campaigns AS c;




-- Normalizar emails de usuarios (minúsculas y sin espacios a los lados)
SELECT
    UserId,
    LastName                                   AS Apellido,
    LOWER(LTRIM(RTRIM(lastName)))             AS ApellidoNormalizado
FROM dbo.Users;


-- Ejemplo de redondeo de costo en métricas de anuncios
SELECT TOP (20)
    AdId,
    AVG(cost)      AS AvgCost,
    FLOOR(AVG(cost))   AS CostFloor,
    CEILING(AVG(cost)) AS CostCeiling
FROM dbo.AdMetricsDaily
GROUP BY AdId
ORDER BY AdId;

SELECT TOP (20)
    AdId,
    COUNT(*) AS NumMedias
FROM dbo.AdMedias
GROUP BY AdId
ORDER BY NumMedias DESC;




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
