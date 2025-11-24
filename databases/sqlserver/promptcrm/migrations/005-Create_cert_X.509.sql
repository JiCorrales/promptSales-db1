-- =============================================
-- Migration: Create X.509 Certificate in MASTER Database
-- =============================================
-- IMPORTANTE: Este script debe ejecutarse ANTES de 006-Create_bridge_SP.sql
-- Crea el certificado y la llave simétrica en la base de datos MASTER
-- para uso centralizado de encriptación en PromptCRM.
-- =============================================

USE master;
GO

SET XACT_ABORT ON;

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Configuración de Certificado X.509 en MASTER';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

PRINT '1. Creando Master Key de la Base de Datos MASTER...';
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    -- NOTA: En producción, esta contraseña debe guardarse en un gestor de secretos
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'AleeCR27_MasterDB_2025';
    PRINT '   ✓ Master Key Creada en MASTER.';
END
ELSE
BEGIN
    PRINT '   → Master Key ya existía en MASTER.';
END
PRINT '';

PRINT '2. Creando Certificado X.509 (Cert_PromptCRM_Master_PII)...';
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'Cert_PromptCRM_Master_PII')
BEGIN
    CREATE CERTIFICATE Cert_PromptCRM_Master_PII
    WITH SUBJECT = 'PromptCRM PII Data Encryption - Master Certificate',
    EXPIRY_DATE = '20301231';
    PRINT '   ✓ Certificado Creado en MASTER.';
END
ELSE
BEGIN
    PRINT '   → Certificado ya existía en MASTER.';
END
PRINT '';

PRINT '3. Creando Symmetric Key (SK_PromptCRM_Master_Key)...';
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'SK_PromptCRM_Master_Key')
BEGIN
    CREATE SYMMETRIC KEY SK_PromptCRM_Master_Key
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;
    PRINT '   ✓ Symmetric Key Creada en MASTER.';
END
ELSE
BEGIN
    PRINT '   → Symmetric Key [SK_PromptCRM_Master_Key] ya existía en MASTER.';
END
PRINT '';

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ CONFIGURACIÓN DE SEGURIDAD EN MASTER COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT 'Objetos creados en MASTER:';
PRINT '  • Database Master Key';
PRINT '  • Certificado: Cert_PromptCRM_Master_PII';
PRINT '  • Symmetric Key: SK_PromptCRM_Master_Key (AES_256)';
PRINT '';
PRINT 'Siguiente paso: Ejecutar 006-Create_bridge_SP.sql';
PRINT '';
GO