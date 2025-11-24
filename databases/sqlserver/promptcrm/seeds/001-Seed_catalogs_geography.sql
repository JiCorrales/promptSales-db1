-- =============================================
-- PromptCRM - Seed Data: Geography Catalogs
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Populate Countries, States, and Cities
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'SEEDING GEOGRAPHY CATALOGS';
PRINT '========================================';
PRINT '';

-- =============================================
-- COUNTRIES
-- =============================================
PRINT 'Inserting Countries...';

SET IDENTITY_INSERT [crm].[Countries] ON;

INSERT INTO [crm].[Countries] (countryId, countryName, countryCode, enabled)
VALUES
    (1, 'United States', 'USA', 1),
    (2, 'Spain', 'ESP', 1),
    (3, 'Costa Rica', 'CRI', 1);

SET IDENTITY_INSERT [crm].[Countries] OFF;

PRINT '  ✓ Inserted 3 countries';

-- =============================================
-- STATES - USA
-- =============================================
PRINT 'Inserting States (USA)...';

SET IDENTITY_INSERT [crm].[States] ON;

INSERT INTO [crm].[States] (stateId, stateName, countryId, enabled)
VALUES
    (1, 'California', 1, 1),
    (2, 'Texas', 1, 1),
    (3, 'Florida', 1, 1),
    (4, 'New York', 1, 1),
    (5, 'Pennsylvania', 1, 1),
    (6, 'Illinois', 1, 1),
    (10, 'Michigan', 1, 1),
    (13, 'Washington', 1, 1),
    (15, 'Massachusetts', 1, 1);

SET IDENTITY_INSERT [crm].[States] OFF;

PRINT '  ✓ Inserted 9 USA states';

-- =============================================
-- STATES - Spain
-- =============================================
PRINT 'Inserting States (Spain)...';

SET IDENTITY_INSERT [crm].[States] ON;

INSERT INTO [crm].[States] (stateId, stateName, countryId, enabled)
VALUES
    (101, 'Madrid', 2, 1),
    (102, 'Cataluña', 2, 1),
    (103, 'Andalucía', 2, 1),
    (104, 'Valencia', 2, 1),
    (105, 'País Vasco', 2, 1);

SET IDENTITY_INSERT [crm].[States] OFF;

PRINT '  ✓ Inserted 5 Spain regions';

-- =============================================
-- STATES - Costa Rica
-- =============================================
PRINT 'Inserting States (Costa Rica)...';

SET IDENTITY_INSERT [crm].[States] ON;

INSERT INTO [crm].[States] (stateId, stateName, countryId, enabled)
VALUES
    (201, 'San José', 3, 1),
    (202, 'Alajuela', 3, 1),
    (203, 'Cartago', 3, 1),
    (204, 'Heredia', 3, 1),
    (205, 'Guanacaste', 3, 1),
    (206, 'Puntarenas', 3, 1),
    (207, 'Limón', 3, 1);

SET IDENTITY_INSERT [crm].[States] OFF;

PRINT '  ✓ Inserted 7 Costa Rica provinces';

-- =============================================
-- CITIES - USA
-- =============================================
PRINT 'Inserting Cities (USA)...';

SET IDENTITY_INSERT [crm].[Cities] ON;

INSERT INTO [crm].[Cities] (cityId, cityName, stateId, enabled)
VALUES
    -- California
    (1, 'Los Angeles', 1, 1),
    (2, 'San Francisco', 1, 1),
    (3, 'San Diego', 1, 1),

    -- Texas
    (10, 'Houston', 2, 1),
    (11, 'Dallas', 2, 1),
    (12, 'Austin', 2, 1),

    -- Florida
    (20, 'Miami', 3, 1),
    (21, 'Orlando', 3, 1),

    -- New York
    (30, 'New York City', 4, 1),
    (31, 'Buffalo', 4, 1),

    -- Pennsylvania
    (40, 'Philadelphia', 5, 1),
    (41, 'Pittsburgh', 5, 1),

    -- Illinois
    (50, 'Chicago', 6, 1),

    -- Michigan
    (60, 'Detroit', 10, 1),

    -- Washington
    (70, 'Seattle', 13, 1),

    -- Massachusetts
    (80, 'Boston', 15, 1);

SET IDENTITY_INSERT [crm].[Cities] OFF;

PRINT '  ✓ Inserted 16 USA cities';

-- =============================================
-- CITIES - Spain
-- =============================================
PRINT 'Inserting Cities (Spain)...';

SET IDENTITY_INSERT [crm].[Cities] ON;

INSERT INTO [crm].[Cities] (cityId, cityName, stateId, enabled)
VALUES
    (1001, 'Madrid', 101, 1),
    (1002, 'Barcelona', 102, 1),
    (1003, 'Sevilla', 103, 1),
    (1004, 'Valencia', 104, 1),
    (1005, 'Bilbao', 105, 1);

SET IDENTITY_INSERT [crm].[Cities] OFF;

PRINT '  ✓ Inserted 5 Spain cities';

-- =============================================
-- CITIES - Costa Rica
-- =============================================
PRINT 'Inserting Cities (Costa Rica)...';

SET IDENTITY_INSERT [crm].[Cities] ON;

INSERT INTO [crm].[Cities] (cityId, cityName, stateId, enabled)
VALUES
    (2001, 'San José', 201, 1),
    (2002, 'Escazú', 201, 1),
    (2003, 'Santa Ana', 201, 1),
    (2010, 'Alajuela', 202, 1),
    (2020, 'Cartago', 203, 1),
    (2030, 'Heredia', 204, 1),
    (2040, 'Liberia', 205, 1),
    (2050, 'Puntarenas', 206, 1),
    (2060, 'Limón', 207, 1);

SET IDENTITY_INSERT [crm].[Cities] OFF;

PRINT '  ✓ Inserted 9 Costa Rica cities';

PRINT '';
PRINT '========================================';
PRINT 'GEOGRAPHY CATALOGS SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT 'Summary:';
PRINT '  - Countries: 3 (USA, Spain, Costa Rica)';
PRINT '  - States/Provinces: 21 (9 USA + 5 Spain + 7 Costa Rica)';
PRINT '  - Cities: 30 (16 USA + 5 Spain + 9 Costa Rica)';
PRINT '';

GO
