use PromptAds;


-- EXCEPT
-- CampaignStatus NO usados aún en ninguna campaña
-- Todos los estados de campaña definidos en el catálogo
SELECT 
    cs.CampaignStatusId,
    cs.name
FROM dbo.CampaignStatus cs

EXCEPT

-- Estados de campaña que ya están siendo utilizados por al menos una campaña
SELECT DISTINCT
    c.CampaignStatusId,
    cs2.name
FROM dbo.Campaigns c
JOIN dbo.CampaignStatus cs2
    ON cs2.CampaignStatusId = c.CampaignStatusId;



/*
INTERSECT
-- Encontrar BrandId (marcas) que cumplan AMBAS condiciones:
         a) Tienen al menos una campaña Activa.
         b) Tienen al menos una campaña (de cualquier estado)
            con presupuesto mayor a 20000.
*/
-- Marcas con campañas activas
SELECT b.BrandId, b.name AS BrandName
FROM dbo.Brands b
WHERE b.BrandId IN (
    SELECT DISTINCT c.BrandId
FROM dbo.Campaigns c
JOIN dbo.CampaignStatus cs ON cs.CampaignStatusId = c.CampaignStatusId
WHERE cs.name = 'Activa'

INTERSECT

-- Marcas con campañas de alto presupuesto (cualquier estado)
SELECT DISTINCT c2.BrandId
FROM dbo.Campaigns c2
WHERE c2.budget > 20000
);



/*
MERGE
- Mantener un "watermark" de ETL en la tabla dbo.ETLWatermark
para el proceso PromptAds_To_PromptSales_Summary.
- Si ya existe la fila → se hace UPDATE (fecha y notas).
- Si no existe → se inserta una nueva fila.
*/

-- Actualizar / insertar watermark de un proceso ETL

SELECT 
    processName,
    LastSuccessAt,
    Notes
FROM dbo.ETLWatermark
WHERE processName = 'PromptAds_To_PromptSales_Summary';


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



-- LTRIM
-- Eliminar espacios en blanco a la izquierda de un texto.
SELECT TOP (10)
    c.CampaignId,
    c.name                         AS NombreOriginal,
    '   ' + c.name                 AS NombreConEspaciosSimulados,
    LTRIM('   ' + c.name)          AS NombreDespuesDeLTRIM
FROM dbo.Campaigns AS c;



--LOWERCASE
-- Normalizar apellidos de usuarios (minúsculas y sin espacios a los lados)
SELECT
    UserId,
    LastName                                   AS Apellido,
    LOWER(LTRIM(RTRIM(lastName)))             AS ApellidoNormalizado
FROM dbo.Users;



-- FLOOR/CEILING
/*
Demostrar funciones de redondeo:
    - AVG(cost): promedio exacto.
    - FLOOR(AVG(cost)): redondeo hacia abajo.
    - CEILING(AVG(cost)): redondeo hacia arriba.
*/
SELECT TOP (20)
    AdId,
    AVG(cost)          AS AvgCost,         -- promedio real
    FLOOR(AVG(cost))   AS CostFloor,       -- redondeo hacia abajo
    CEILING(AVG(cost)) AS CostCeiling      -- redondeo hacia arriba
FROM dbo.AdMetricsDaily
GROUP BY AdId
ORDER BY AdId;



-- UPDATE DE SELECT
/*
- Demostrar un patrón clásico de "UPDATE basado en SELECT":
     1) Se calcula un valor derivado en un CTE (ReachCalc).
     2) Se utiliza ese CTE para actualizar la tabla base usando un JOIN.
*/

WITH ReachCalc AS (
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
