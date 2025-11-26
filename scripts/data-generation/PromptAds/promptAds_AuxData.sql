USE PromptAds;
GO

/*========================================================
  SCRIPT: Datos Auxiliares 
  PRE-REQUISITOS:
    1) Base de datos PromptAds ya creada.
    2) Tablas del esquema principal ya creadas (script DDL).
  ESTE SCRIPT DEBE EJECUTARSE:
    - Antes de los stored procedures de seeding de datos.
========================================================*/

IF OBJECT_ID('dbo.Numbers', 'U') IS NOT NULL
    DROP TABLE dbo.Numbers;
GO

CREATE TABLE dbo.Numbers (
    n int NOT NULL PRIMARY KEY
);
GO

;WITH NumbersCTE AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM NumbersCTE
    WHERE n < 1000000
)
INSERT INTO dbo.Numbers(n)
SELECT n
FROM NumbersCTE
OPTION (MAXRECURSION 0);
GO

/*---------------------------------------------------------
   Tablas de nombres y apellidos
---------------------------------------------------------*/
IF OBJECT_ID('dbo.FirstNames', 'U') IS NOT NULL DROP TABLE dbo.FirstNames;
IF OBJECT_ID('dbo.LastNames', 'U')  IS NOT NULL DROP TABLE dbo.LastNames;
GO

CREATE TABLE dbo.FirstNames (
    FirstNameId int IDENTITY(1,1) PRIMARY KEY,
    Name        varchar(80) NOT NULL
);

CREATE TABLE dbo.LastNames (
    LastNameId int IDENTITY(1,1) PRIMARY KEY,
    Name       varchar(80) NOT NULL
);
GO

INSERT INTO dbo.FirstNames(Name)
VALUES
('Andrés'),('María'),('José'),('Lucía'),('Carlos'),('Valeria'),('Ricardo'),
('Nicole'),('Daniel'),('Laura'),('Sofía'),('Diego'),('Camila'),('Pablo'),
('Fernanda'),('Luis'),('Ana'),('Javier'),('Elena'),('David'),
('Isabella'),('Jorge'),('Paula'),('Sebastián'),('Carolina'),
('Felipe'),('Gabriela'),('Mauricio'),('Adriana'),('Rodrigo'),
('Natalia'),('Marco'),('Alejandra'),('Héctor'),('Silvia'),
('Ignacio'),('Patricia'),('Roberto'),('Tatiana'),('Miguel'),
('Rebeca'),('Esteban'),('Verónica'),('Manuel'),('Mónica'),
('Oscar'),('Karina'),('Rafael'),('Priscila'),('Cristian'),
('Alejandro'),('Violeta'),('Emilia'),('Martín'),('Bruno');

INSERT INTO dbo.LastNames(Name)
VALUES
('Rodríguez'),('García'),('Martínez'),('López'),('Hernández'),
('González'),('Pérez'),('Sánchez'),('Ramírez'),('Flores'),
('Vargas'),('Jiménez'),('Mora'),('Castro'),('Rojas'),
('Alvarado'),('Campos'),('Solís'),('Chacón'),('Cordero'),
('Navarro'),('Monge'),('Leiva'),('Araya'),('Calderón'),
('Acosta'),('Salas'),('Méndez'),('Pacheco'),('Aguilar'),
('Carrillo'),('Esquivel'),('Herrera'),('Morales'),('Soto'),
('Quiros'),('Ruiz'),('Valverde'),('Zamora'),('Vega'),
('Suárez'),('Pineda'),('Moraes'),('Castillo'),('Benavides'),
('Barboza'),('Cruz'),('Murillo'),('Montoya'),('Villalobos'),
('Azofeifa'),('Rivers'),('Chinchilla'),('Obando'),('Mejía');
GO

/*---------------------------------------------------------
   Función para fecha aleatoria entre 2024-01-01 y 2025-12-31
---------------------------------------------------------*/
IF OBJECT_ID('dbo.fn_RandomDateTime', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_RandomDateTime;
GO

CREATE FUNCTION dbo.fn_RandomDateTime(@Seed bigint)
RETURNS datetime
AS
BEGIN
    DECLARE @start datetime = '2024-01-01T00:00:00';
    DECLARE @end   datetime = '2025-12-31T23:59:59';
    DECLARE @range int     = DATEDIFF(SECOND, @start, @end);
    DECLARE @offset int = ABS(CHECKSUM(@Seed)) % @range;
    RETURN DATEADD(SECOND, @offset, @start);
END;
GO

/*---------------------------------------------------------
   Función RandBetween para números
---------------------------------------------------------*/
IF OBJECT_ID('dbo.fn_RandBetween', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_RandBetween;
GO

CREATE FUNCTION dbo.fn_RandBetween (@Seed int, @Min int, @Max int)
RETURNS int
AS
BEGIN
    DECLARE @Diff int = @Max - @Min + 1;
    RETURN @Min + (ABS(CHECKSUM(@Seed)) % @Diff);
END;
GO
