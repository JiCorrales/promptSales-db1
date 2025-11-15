USE PromptAds;

-- Parámetros globales de la generación
DECLARE @FechaInicio DATE = '2024-07-01';
DECLARE @FechaFin    DATE = '2025-10-31';
DECLARE @Campanias   INT  = 100000;

-- Meses con picos (ajusta si quieres)
DECLARE @MesPico1 INT = 12; -- Dic 2024
DECLARE @MesPico2 INT = 1;  -- Ene 2025
DECLARE @MesPico3 INT = 7;  -- Jul 2025

-- Porcentajes de estado
DECLARE @PctActivas   DECIMAL(5,2) = 0.35;  -- 30% activas (EndDate NULL)
DECLARE @PctTerminadas DECIMAL(5,2) = 0.65; -- 70% con EndDate

-- Helper: tabla calendario en memoria
IF OBJECT_ID('tempdb..#Calendario') IS NOT NULL DROP TABLE #Calendario;
CREATE TABLE #Calendario(Fecha DATE PRIMARY KEY, Anio INT, Mes INT, Dia INT);
WITH d AS (
  SELECT @FechaInicio AS dt
  UNION ALL
  SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < @FechaFin
)
INSERT INTO #Calendario(Fecha, Anio, Mes, Dia)
SELECT dt, YEAR(dt), MONTH(dt), DAY(dt)
FROM d
OPTION (MAXRECURSION 0);

