-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra deadlock en procesamiento de pagos
--              Usa tablas reales: SubscriberWallets, Transactions
-- Escenario: Procesa pago de subscripción del Subscriber
-- Orden de acceso: SubscriberWallets → Transactions
-- Problema: Orden diferente a otros SPs causa deadlock
-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ProcessSubscriptionPayment_UNSAFE]
	@SubscriberId INT,
	@Amount DECIMAL(18,4),
	@DelaySeconds INT = 2
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()
	DECLARE @OldCredits DECIMAL(18,4)
	DECLARE @NewCredits DECIMAL(18,4)
	DECLARE @TransactionCount INT

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		-- ⚠️ READ COMMITTED: Usa locks, propenso a deadlocks
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ProcessSubscriptionPayment_UNSAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Processing payment for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))

		-- ⚠️ PASO 1: Acceso a SUBSCRIBER_WALLETS (primer recurso)
		PRINT '[ProcessSubscriptionPayment_UNSAFE] Step 1: Locking SubscriberWallets for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		SELECT @OldCredits = creditsBalance
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessSubscriptionPayment_UNSAFE] Wallet locked - Current Credits: $' +
		      CAST(@OldCredits AS VARCHAR(20))

		-- Simular procesamiento (ventana para deadlock)
		PRINT '[ProcessSubscriptionPayment_UNSAFE] Processing payment... (delay ' +
		      CAST(@DelaySeconds AS VARCHAR(5)) + 's)'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ PASO 2: Acceso a TRANSACTIONS (segundo recurso - CONFLICTO!)
		PRINT '[ProcessSubscriptionPayment_UNSAFE] Step 2: Attempting to access Transactions...'

		SELECT @TransactionCount = COUNT(*)
		FROM [crm].[Transactions] WITH (UPDLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessSubscriptionPayment_UNSAFE] Found ' + CAST(@TransactionCount AS VARCHAR(10)) +
		      ' existing transactions'

		-- Actualizar la billetera
		SET @NewCredits = @OldCredits + @Amount

		UPDATE [crm].[SubscriberWallets]
		SET creditsBalance = @NewCredits,
		    totalRevenue = totalRevenue + @Amount,
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessSubscriptionPayment_UNSAFE] Wallet updated - New Credits: $' +
		      CAST(@NewCredits AS VARCHAR(20))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ProcessSubscriptionPayment_UNSAFE] ✓ COMMITTED - Payment processed successfully'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			IF @ErrorNumber = 1205 BEGIN
				PRINT '[ProcessSubscriptionPayment_UNSAFE] ⚠️ DEADLOCK VICTIM - Session killed by SQL Server'
				PRINT '[ProcessSubscriptionPayment_UNSAFE] Reason: Inconsistent lock order with other procedures'
			END ELSE BEGIN
				PRINT '[ProcessSubscriptionPayment_UNSAFE] ROLLED BACK - ' + @Message
			END
		END

		RAISERROR('ProcessSubscriptionPayment_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ProcessSubscriptionPayment_UNSAFE]'
GO
