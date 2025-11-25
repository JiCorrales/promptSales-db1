-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene deadlock con orden consistente
--              Usa tablas reales: Transactions, SubscriberWallets, LeadConversions
-- Escenario: Reconcilia conversiones con billetera (versión SAFE)
-- SOLUTION: Orden consistente = Transactions → SubscriberWallets → LeadConversions
--           Este orden DEBE ser respetado por TODOS los procedures
-----------------------------------------------------------

USE PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ReconcileWallet_SAFE]
	@LeadId INT,
	@SubscriberId INT,
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
	DECLARE @ConversionCount INT
	DECLARE @CurrentCredits DECIMAL(18,4)
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
		PRINT '[ReconcileWallet_SAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Reconciling wallet for Lead ' + CAST(@LeadId AS VARCHAR(10))

		-- ✅ SOLUTION 2: ORDEN CONSISTENTE (Transactions → SubscriberWallets → LeadConversions)
		-- Paso 1: Acceder a TRANSACTIONS primero (SIEMPRE PRIMERO)
		PRINT '[ReconcileWallet_SAFE] Step 1: Accessing Transactions first (consistent order)...'

		SELECT @TransactionCount = COUNT(*)
		FROM [crm].[Transactions] WITH (ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ReconcileWallet_SAFE] Transactions accessed - Count: ' +
		      CAST(@TransactionCount AS VARCHAR(10))

		-- Simular procesamiento breve
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- Paso 2: Acceder a SUBSCRIBER_WALLETS segundo (SIEMPRE SEGUNDO)
		PRINT '[ReconcileWallet_SAFE] Step 2: Accessing SubscriberWallets...'

		SELECT @CurrentCredits = creditsBalance
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ReconcileWallet_SAFE] SubscriberWallets accessed - Credits: $' +
		      CAST(@CurrentCredits AS VARCHAR(20))

		-- Paso 3: Acceder a LEAD_CONVERSIONS tercero (SIEMPRE TERCERO)
		PRINT '[ReconcileWallet_SAFE] Step 3: Accessing LeadConversions...'

		SELECT @ConversionCount = COUNT(*)
		FROM [crm].[LeadConversions] WITH (ROWLOCK)
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[ReconcileWallet_SAFE] LeadConversions accessed - Count: ' +
		      CAST(@ConversionCount AS VARCHAR(10))

		PRINT '[ReconcileWallet_SAFE] Reconciliation completed for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ReconcileWallet_SAFE] ✓ COMMITTED - No deadlock (consistent order)'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ReconcileWallet_SAFE] ROLLED BACK - ' + @Message
		END

		-- ✅ SOLUTION 3: Retry en caso de deadlock raro
		IF @ErrorNumber = 1205 AND @RetryCount < @MaxRetries BEGIN
			SET @RetryCount = @RetryCount + 1
			PRINT '[ReconcileWallet_SAFE] ⚠️ Deadlock detected. Retrying... (Attempt ' +
			      CAST(@RetryCount AS VARCHAR(2)) + '/' + CAST(@MaxRetries AS VARCHAR(2)) + ')'
			WAITFOR DELAY '00:00:00.100'
			GOTO RETRY_TRANSACTION
		END

		IF @ErrorNumber = 1205 BEGIN
			PRINT '[ReconcileWallet_SAFE] ❌ DEADLOCK: Max retries exceeded'
		END

		RAISERROR('ReconcileWallet_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ReconcileWallet_SAFE]'
GO
