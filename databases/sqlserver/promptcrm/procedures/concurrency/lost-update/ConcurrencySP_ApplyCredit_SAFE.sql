-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene Lost Update Problem
--              Aplica créditos a la billetera usando UPDATE inline
--              Esta versión PREVIENE lost updates con cálculo atómico
-- Solucion: UPDATE con cálculo inline en una sola operación
-- Escenario: Aplicador de créditos mejorado con operaciones atómicas
-- Tabla: SubscriberWallets
-----------------------------------------------------------

USE PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_ApplyCredit_SAFE]
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

	-- Variables para reporte
	DECLARE @OriginalCredits DECIMAL(18,4)
	DECLARE @OriginalRevenue DECIMAL(18,4)
	DECLARE @NewCredits DECIMAL(18,4)
	DECLARE @NewRevenue DECIMAL(18,4)
	DECLARE @RetryCount INT = 0
	DECLARE @MaxRetries INT = 3

	-- ✅ SOLUCION 1: Retry logic
	RETRY_TRANSACTION:

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ApplyCredit_SAFE] Starting credit application for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))
		PRINT '[ApplyCredit_SAFE] Credit Amount: $' + CAST(@CreditAmount AS VARCHAR(20)) + ' - Reason: ' + @CreditReason

		-- Leer balance SOLO para logging (no para cálculo)
		PRINT '[ApplyCredit_SAFE] Step 1: Reading current balance (for logging only)...'

		SELECT
			@OriginalCredits = creditsBalance,
			@OriginalRevenue = totalRevenue
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK) -- Lock para prevenir lecturas concurrentes
		WHERE subscriberId = @SubscriberId

		PRINT '[ApplyCredit_SAFE] Current Credits: $' + CAST(@OriginalCredits AS VARCHAR(20))
		PRINT '[ApplyCredit_SAFE] Current Revenue: $' + CAST(@OriginalRevenue AS VARCHAR(20))

		-- Simular procesamiento (pero el cálculo se hará atómicamente en el UPDATE)
		PRINT '[ApplyCredit_SAFE] Step 2: Processing... (delay ' + CAST(@ProcessingDelay AS VARCHAR(5)) + 's)'
		PRINT '[ApplyCredit_SAFE] Holding UPDLOCK - other sessions will wait'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@ProcessingDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ✅ SOLUCION 2: UPDATE con cálculo INLINE (operación atómica)
		PRINT '[ApplyCredit_SAFE] Step 3: Applying credit with atomic UPDATE...'

		UPDATE [crm].[SubscriberWallets]
		SET
		    -- ✅ Cálculo inline - usa el valor ACTUAL de creditsBalance (no el leído hace X segundos)
		    creditsBalance = creditsBalance + @CreditAmount,
		    totalRevenue = totalRevenue + @CreditAmount,
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		-- Leer valores finales para reporte
		SELECT
			@NewCredits = creditsBalance,
			@NewRevenue = totalRevenue
		FROM [crm].[SubscriberWallets]
		WHERE subscriberId = @SubscriberId

		PRINT '[ApplyCredit_SAFE] ✓ Credit applied successfully (atomic operation)'
		PRINT '[ApplyCredit_SAFE] Original Credits: $' + CAST(@OriginalCredits AS VARCHAR(20))
		PRINT '[ApplyCredit_SAFE] Credit Applied:   $' + CAST(@CreditAmount AS VARCHAR(20))
		PRINT '[ApplyCredit_SAFE] Final Credits:    $' + CAST(@NewCredits AS VARCHAR(20))
		PRINT '[ApplyCredit_SAFE] Final Revenue:    $' + CAST(@NewRevenue AS VARCHAR(20))
		PRINT '[ApplyCredit_SAFE] No updates were lost - calculation was atomic'

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ApplyCredit_SAFE] COMMITTED (releasing UPDLOCK)'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ApplyCredit_SAFE] ROLLED BACK - ' + @Message
		END

		-- ✅ SOLUCION 3: Retry en caso de deadlock
		IF @ErrorNumber = 1205 AND @RetryCount < @MaxRetries BEGIN
			SET @RetryCount = @RetryCount + 1
			PRINT '[ApplyCredit_SAFE] ⚠️ Deadlock detected. Retrying... (Attempt ' +
			      CAST(@RetryCount AS VARCHAR(2)) + '/' + CAST(@MaxRetries AS VARCHAR(2)) + ')'
			WAITFOR DELAY '00:00:00.100'
			GOTO RETRY_TRANSACTION
		END

		IF @ErrorNumber = 1205 BEGIN
			PRINT '[ApplyCredit_SAFE] ❌ DEADLOCK: Max retries exceeded'
		END

		RAISERROR('ApplyCredit_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_ApplyCredit_SAFE]'
GO
