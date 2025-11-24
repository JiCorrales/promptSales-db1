-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene deadlocks con orden consistente
--              Usa tablas reales: SubscriberWallets, Transactions
-- Escenario: Procesa pagos con orden consistente
-- SOLUTION: Orden consistente = Transactions → SubscriberWallets
--           Este orden DEBE ser respetado por TODOS los procedures
-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ProcessSubscriptionPayment_SAFE]
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
	DECLARE @RetryCount INT = 0
	DECLARE @MaxRetries INT = 3
	DECLARE @OldCredits DECIMAL(18,4)
	DECLARE @NewCredits DECIMAL(18,4)
	DECLARE @TransactionCount INT

	-- ✅ SOLUTION 1: Retry logic para manejar deadlocks raros
	RETRY_TRANSACTION:

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ProcessSubscriptionPayment_SAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Processing payment for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))

		-- ✅ SOLUTION 2: ORDEN CONSISTENTE (Transactions → SubscriberWallets)
		-- Paso 1: Acceder a TRANSACTIONS primero (SIEMPRE PRIMERO)
		PRINT '[ProcessSubscriptionPayment_SAFE] Step 1: Accessing Transactions first (consistent order)...'

		SELECT @TransactionCount = COUNT(*)
		FROM [crm].[Transactions] WITH (ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessSubscriptionPayment_SAFE] Transactions accessed - Count: ' +
		      CAST(@TransactionCount AS VARCHAR(10))

		-- Simular procesamiento breve
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- Paso 2: Acceder a SUBSCRIBER_WALLETS segundo (SIEMPRE SEGUNDO)
		PRINT '[ProcessSubscriptionPayment_SAFE] Step 2: Updating SubscriberWallets...'

		SELECT @OldCredits = creditsBalance
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId

		SET @NewCredits = @OldCredits + @Amount

		UPDATE [crm].[SubscriberWallets] WITH (ROWLOCK)
		SET creditsBalance = @NewCredits,
		    totalRevenue = totalRevenue + @Amount,
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessSubscriptionPayment_SAFE] Wallet updated:'
		PRINT '  Old Credits: $' + CAST(@OldCredits AS VARCHAR(20))
		PRINT '  New Credits: $' + CAST(@NewCredits AS VARCHAR(20))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ProcessSubscriptionPayment_SAFE] ✓ COMMITTED - No deadlock (consistent order)'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ProcessSubscriptionPayment_SAFE] ROLLED BACK - ' + @Message
		END

		-- ✅ SOLUTION 3: Retry en caso de deadlock raro
		IF @ErrorNumber = 1205 AND @RetryCount < @MaxRetries BEGIN
			SET @RetryCount = @RetryCount + 1
			PRINT '[ProcessSubscriptionPayment_SAFE] ⚠️ Deadlock detected. Retrying... (Attempt ' +
			      CAST(@RetryCount AS VARCHAR(2)) + '/' + CAST(@MaxRetries AS VARCHAR(2)) + ')'
			WAITFOR DELAY '00:00:00.100'
			GOTO RETRY_TRANSACTION
		END

		IF @ErrorNumber = 1205 BEGIN
			PRINT '[ProcessSubscriptionPayment_SAFE] ❌ DEADLOCK: Max retries exceeded'
		END

		RAISERROR('ProcessSubscriptionPayment_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ProcessSubscriptionPayment_SAFE]'
GO
