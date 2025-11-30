-- =============================================
-- Migration: Create X.509 Certificate in PROMPTCRM Database
-- =============================================
-- IMPORTANTE: Este script debe ejecutarse en la base de datos PROMPTCRM
-- Crea el certificado y la llave simétrica en la base de datos PROMPTCRM
-- para uso específico de encriptación en esta base de datos.
-- =============================================

USE PromptCRM;
GO

SET XACT_ABORT ON;

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT 'Configuración de Certificado X.509 en PROMPTCRM';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';

PRINT '1. Creando Master Key de la Base de Datos PROMPTCRM...';
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    -- NOTA: En producción, esta contraseña debe guardarse en un gestor de secretos
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'AleeCR27_PromptCRM_2025';
    PRINT '   ✓ Master Key Creada en PROMPTCRM.';
END
ELSE
BEGIN
    PRINT '   → Master Key ya existía en PROMPTCRM.';
END
PRINT '';

PRINT '2. Creando Certificado X.509 (Cert_PromptCRM_Master_PII)...';
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'Cert_PromptCRM_Master_PII')
BEGIN
    CREATE CERTIFICATE Cert_PromptCRM_Master_PII
    WITH SUBJECT = 'PromptCRM PII Data Encryption - Database Certificate',
    EXPIRY_DATE = '20301231';
    PRINT '   ✓ Certificado Creado en PROMPTCRM.';
END
ELSE
BEGIN
    PRINT '   → Certificado ya existía en PROMPTCRM.';
END
PRINT '';

PRINT '3. Creando Symmetric Key (SK_PromptCRM_Master_Key)...';
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'SK_PromptCRM_Master_Key')
BEGIN
    CREATE SYMMETRIC KEY SK_PromptCRM_Master_Key
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;
    PRINT '   ✓ Symmetric Key Creada en PROMPTCRM.';
END
ELSE
BEGIN
    PRINT '   → Symmetric Key [SK_PromptCRM_Master_Key] ya existía en PROMPTCRM.';
END
PRINT '';

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✓ CONFIGURACIÓN DE SEGURIDAD EN PROMPTCRM COMPLETADA';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT 'Objetos creados en PROMPTCRM:';
PRINT '  • Database Master Key';
PRINT '  • Certificado: Cert_PromptCRM_Master_PII';
PRINT '  • Symmetric Key: SK_PromptCRM_Master_Key (AES_256)';
GO