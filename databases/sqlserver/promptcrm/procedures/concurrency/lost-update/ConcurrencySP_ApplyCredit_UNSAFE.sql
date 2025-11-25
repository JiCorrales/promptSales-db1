-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra Lost Update Problem
--              Aplica créditos a la billetera usando patrón read-modify-write
--              Esta versión CAUSA lost updates cuando se ejecuta concurrentemente
-- Problema: Lectura → Cálculo → Escritura = actualizaciones se pierden
-- Escenario: Dos promociones aplicando créditos simultáneamente
-- Tabla: SubscriberWallets
-----------------------------------------------------------

USE PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_ApplyCredit_UNSAFE]
	@SubscriberId INT,
	@CreditAmount DECIMAL(18,4), -- Monto de crédito a agregar
	@CreditReason VARCHAR(100) = 'Promotion',
	@ProcessingDelay INT = 2 -- Segundos para simular procesamiento
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()

	-- Variables para patrón read-modify-write
	DECLARE @OriginalCredits DECIMAL(18,4)
	DECLARE @OriginalRevenue DECIMAL(18,4)
	DECLARE @NewCredits DECIMAL(18,4)
	DECLARE @NewRevenue DECIMAL(18,4)

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ApplyCredit_UNSAFE] Starting credit application for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))
		PRINT '[ApplyCredit_UNSAFE] Credit Amount: $' + CAST(@CreditAmount AS VARCHAR(20)) + ' - Reason: ' + @CreditReason

		-- ⚠️ PASO 1: LEER el balance actual
		PRINT '[ApplyCredit_UNSAFE] Step 1: Reading current wallet balance...'

		SELECT
			@OriginalCredits = creditsBalance,
			@OriginalRevenue = totalRevenue
		FROM [crm].[SubscriberWallets]
		WHERE subscriberId = @SubscriberId

		PRINT '[ApplyCredit_UNSAFE] Current Credits: $' + CAST(@OriginalCredits AS VARCHAR(20))
		PRINT '[ApplyCredit_UNSAFE] Current Revenue: $' + CAST(@OriginalRevenue AS VARCHAR(20))

		-- ⚠️ PASO 2: CALCULAR nuevo balance (fuera de la base de datos)
		-- Durante este tiempo, OTRA sesión puede leer el mismo balance y hacer su propio cálculo
		PRINT '[ApplyCredit_UNSAFE] Step 2: Calculating new balance... (delay ' + CAST(@ProcessingDelay AS VARCHAR(5)) + 's)'

		SET @NewCredits = @OriginalCredits + @CreditAmount
		SET @NewRevenue = @OriginalRevenue + @CreditAmount

		PRINT '[ApplyCredit_UNSAFE] Calculated New Credits: $' + CAST(@NewCredits AS VARCHAR(20))
		PRINT '[ApplyCredit_UNSAFE] Calculated New Revenue: $' + CAST(@NewRevenue AS VARCHAR(20))

		-- Simular procesamiento complejo
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@ProcessingDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ PASO 3: ESCRIBIR el nuevo balance (puede sobrescribir cambios de otra sesión)
		PRINT '[ApplyCredit_UNSAFE] Step 3: Updating balance to new value...'
		PRINT '[ApplyCredit_UNSAFE] ⚠️ WARNING: This may overwrite changes from concurrent sessions!'

		UPDATE [crm].[SubscriberWallets]
		SET creditsBalance = @NewCredits, -- Valor calculado hace X segundos
		    totalRevenue = @NewRevenue,   -- Puede sobrescribir otro crédito aplicado durante el delay
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		-- Verificar si el balance actual es diferente al esperado (indica lost update)
		DECLARE @ActualCredits DECIMAL(18,4)
		DECLARE @ActualRevenue DECIMAL(18,4)
		SELECT
			@ActualCredits = creditsBalance,
			@ActualRevenue = totalRevenue
		FROM [crm].[SubscriberWallets]
		WHERE subscriberId = @SubscriberId

		IF @ActualCredits <> @NewCredits BEGIN
			PRINT '[ApplyCredit_UNSAFE] ⚠️ UNEXPECTED! Credits mismatch after update:'
			PRINT '  Expected: $' + CAST(@NewCredits AS VARCHAR(20))
			PRINT '  Actual:   $' + CAST(@ActualCredits AS VARCHAR(20))
		END ELSE BEGIN
			PRINT '[ApplyCredit_UNSAFE] ✓ Credit applied successfully'
			PRINT '[ApplyCredit_UNSAFE] Final Credits: $' + CAST(@ActualCredits AS VARCHAR(20))
			PRINT '[ApplyCredit_UNSAFE] Final Revenue: $' + CAST(@ActualRevenue AS VARCHAR(20))
		END

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ApplyCredit_UNSAFE] COMMITTED'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ApplyCredit_UNSAFE] ROLLED BACK - ' + @Message
		END

		RAISERROR('ApplyCredit_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_ApplyCredit_UNSAFE]'
GO
