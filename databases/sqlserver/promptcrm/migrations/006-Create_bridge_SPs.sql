USE master;
GO

-- A. Procedimiento para ENCRIPTAR (Input: Texto -> Output: Binario)
CREATE OR ALTER PROCEDURE sp_PromptCRM_Encrypt_Bridge
    @ClearText NVARCHAR(MAX),
    @EncryptedData VARBINARY(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Abrimos la llave AQUÍ, en el contexto de Master
    OPEN SYMMETRIC KEY SK_PromptCRM_Master_Key
    DECRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;

    -- Encriptamos
    SET @EncryptedData = EncryptByKey(Key_GUID('SK_PromptCRM_Master_Key'), @ClearText);

    -- Cerramos
    CLOSE SYMMETRIC KEY SK_PromptCRM_Master_Key;
END
GO

-- B. Procedimiento para DESENCRIPTAR (Input: Binario -> Output: Texto)
CREATE OR ALTER PROCEDURE sp_PromptCRM_Decrypt_Bridge
    @CipherData VARBINARY(255),
    @DecryptedText NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SK_PromptCRM_Master_Key
    DECRYPTION BY CERTIFICATE Cert_PromptCRM_Master_PII;

    -- Desencriptamos
    SET @DecryptedText = CONVERT(NVARCHAR(MAX), DecryptByKey(@CipherData));

    CLOSE SYMMETRIC KEY SK_PromptCRM_Master_Key;
END
GO

PRINT '   -> SPs Puente creados en MASTER.';