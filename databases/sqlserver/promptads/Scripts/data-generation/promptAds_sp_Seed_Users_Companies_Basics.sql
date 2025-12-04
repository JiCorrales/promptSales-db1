USE PromptAds;
GO

/*========================================================
  SP: sp_Seed_Users_Companies_Basics
  PRE-REQUISITOS:
    1) Script DDL (tablas) ejecutado.
    2) Script Specific Data ejecutado (Roles, Subscriptions, CompanyStatus, etc.).
    3) Script Datos Auxiliares ejecutado (Numbers, fn_RandomDateTime, fn_RandBetween).
========================================================*/


IF OBJECT_ID('dbo.sp_Seed_Users_Companies_Basics', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Seed_Users_Companies_Basics;
GO


CREATE PROCEDURE dbo.sp_Seed_Users_Companies_Basics
    @UsersCount      int = 50000,
    @CompaniesCount  int = 50000,
    @BrandsPerComp   int = 3
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @startUserId bigint, @startCompanyId bigint;
    DECLARE @rows int;

    BEGIN TRY
        BEGIN TRAN;

        /*-----------------------------
          Usuarios
        -----------------------------*/
        SELECT @startUserId = ISNULL(MAX(UserId),0) FROM dbo.Users;

        INSERT INTO dbo.Users
        (UserStatusId, firstName, lastName, email, createdAt, updatedAt, active,
         passwordHash, checksum, lastLogin, username)
        SELECT TOP (@UsersCount)
            1, -- Activo
            fn.Name,
            ln.Name,
            CONCAT('user', @startUserId + ROW_NUMBER() OVER (ORDER BY n.n),'@promptads.test'),
            dbo.fn_RandomDateTime(n.n),
            dbo.fn_RandomDateTime(n.n + 1000000),
            1,
            CONVERT(varbinary(256),
                    HASHBYTES('SHA2_256', CONCAT('pwd', @startUserId + n.n))),
            CONVERT(char(64),
                    HASHBYTES('SHA2_256', CONCAT('chk', @startUserId + n.n)),2),
            dbo.fn_RandomDateTime(n.n + 2000000),
            CONCAT('user', @startUserId + ROW_NUMBER() OVER (ORDER BY n.n))
        FROM dbo.Numbers n
        CROSS JOIN (SELECT TOP (100) * FROM dbo.FirstNames ORDER BY FirstNameId) fn
        CROSS JOIN (SELECT TOP (100) * FROM dbo.LastNames  ORDER BY LastNameId) ln;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertados ', @rows, ' Usuarios.');

        /* RolesPerUser y SubscriptionPerUser */
        DECLARE @RoleAdmin int = (SELECT RoleId FROM dbo.Roles WHERE name='Admin');
        DECLARE @RoleMgr   int = (SELECT RoleId FROM dbo.Roles WHERE name='CampaignManager');
        DECLARE @RoleAnal  int = (SELECT RoleId FROM dbo.Roles WHERE name='Analyst');

        INSERT INTO dbo.RolesPerUser(UserId, RoleId, createdAt, enabled, checksum)
        SELECT u.UserId,
               CASE WHEN u.UserId % 10 = 0 THEN @RoleAdmin
                    WHEN u.UserId % 2 = 0 THEN @RoleMgr
                    ELSE @RoleAnal
               END,
               dbo.fn_RandomDateTime(u.UserId),
               1,
               CONVERT(char(64),
                       HASHBYTES('SHA2_256', CONCAT('role', u.UserId)),2)
        FROM dbo.Users u
        WHERE u.UserId > @startUserId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertados ', @rows, ' RolesPerUser.');

        INSERT INTO dbo.SubscriptionPerUser(UserId, SubscriptionId, enabled)
        SELECT u.UserId,
               CASE WHEN u.UserId % 10 = 0 THEN sEnt.SubscriptionId
                    WHEN u.UserId % 2 = 0 THEN sGro.SubscriptionId
                    ELSE sSta.SubscriptionId
               END,
               1
        FROM dbo.Users u
        CROSS JOIN dbo.Subscriptions sSta
        CROSS JOIN dbo.Subscriptions sGro
        CROSS JOIN dbo.Subscriptions sEnt
        WHERE sSta.name='Starter'
          AND sGro.name='Growth'
          AND sEnt.name='Enterprise'
          AND u.UserId > @startUserId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertados ', @rows, ' SubscriptionPerUser.');

        /*-----------------------------
          Companies + CompanyAddresses
        -----------------------------*/
        SELECT @startCompanyId = ISNULL(MAX(CompanyId),0) FROM dbo.Companies;

        INSERT INTO dbo.Companies(CompStatusId, name, legalName, email, active, createdAt)
        SELECT TOP (@CompaniesCount)
            CASE WHEN n.n % 10 = 0 THEN 1  -- Prospecto
                 WHEN n.n % 10 <= 7 THEN 2 -- Activo
                 ELSE 3                    -- Suspendido
            END,
            CONCAT('Empresa ', @startCompanyId + n.n),
            CONCAT('Empresa ', @startCompanyId + n.n, ' S.A.'),
            CONCAT('contacto', @startCompanyId + n.n, '@cliente.test'),
            CASE WHEN n.n % 13 = 0 THEN 0 ELSE 1 END,
            dbo.fn_RandomDateTime(n.n)
        FROM dbo.Numbers n;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertadas ', @rows, ' Companies.');

        -- CompanyAddresses
        INSERT INTO dbo.CompanyAddresses(CompanyId, AddressId, isPrimary, createdAt)
        SELECT c.CompanyId,
               ((c.CompanyId - @startCompanyId - 1) % 6) + 1,
               1,
               dbo.fn_RandomDateTime(c.CompanyId)
        FROM dbo.Companies c
        WHERE c.CompanyId > @startCompanyId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertadas ', @rows, ' CompanyAddresses.');

        /*-----------------------------
          Brands 
        -----------------------------*/
        DECLARE @BrandsTarget int = @CompaniesCount * @BrandsPerComp;

        INSERT INTO dbo.Brands(CompanyId, name, description)
        SELECT TOP (@BrandsTarget)
            c.CompanyId,
            CONCAT('Marca ', c.CompanyId, '-', ROW_NUMBER() OVER (PARTITION BY c.CompanyId ORDER BY (SELECT NULL))),
            'Marca asociada a la empresa para campañas de marketing'
        FROM dbo.Companies c
        CROSS JOIN (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3) rep;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertadas ', @rows, ' Brands.');

        /*-----------------------------
          UserPerCompany
        -----------------------------*/
        INSERT INTO dbo.UserPerCompany(CompanyId, UserId, enabled)
        SELECT c.CompanyId,
               u.UserId,
               1
        FROM dbo.Companies c
        JOIN dbo.Users u
          ON (u.UserId - @startUserId) % @CompaniesCount = (c.CompanyId - @startCompanyId) % @CompaniesCount
        WHERE c.CompanyId > @startCompanyId
          AND u.UserId > @startUserId;

        SET @rows = @@ROWCOUNT;
        PRINT CONCAT('sp_Seed_Users_Companies_Basics: Insertadas ', @rows, ' UserPerCompany.');

        COMMIT TRAN;
        PRINT 'sp_Seed_Users_Companies_Basics: COMMIT exitoso.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @ErrMsg nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @ErrSeverity int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();

        PRINT CONCAT('sp_Seed_Users_Companies_Basics: ERROR - ', @ErrMsg);
        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH
END;
GO


EXEC sp_Seed_Users_Companies_Basics;