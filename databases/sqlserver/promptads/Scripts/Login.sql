-- Login a nivel instancia
CREATE LOGIN promptads_app WITH PASSWORD = 'PromptAdsCaso2', CHECK_POLICY = ON;
GO
-- Usuario dentro de la BD
USE PromptAds;
CREATE USER promptads_app FOR LOGIN promptads_app;
-- Rol (puedes ajustar a algo más restrictivo luego)
EXEC sp_addrolemember N'db_owner', N'promptads_app';
GO
