-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Tercer procedure para deadlock en cascada
--              Usa tablas reales: LeadConversions, SubscriberWallets, Transactions
-- Escenario: Reconcilia conversiones con billetera (3er proceso)
-- Orden de acceso: LeadConversions → SubscriberWallets → Transactions
-- Problema: Orden diferente causa deadlock en cascada con otros 2 procesos
-----------------------------------------------------------

USE PromptCRM
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ReconcileWallet_UNSAFE]
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
	DECLARE @CurrentCredits DECIMAL(18,4)
	DECLARE @TransactionId INT
	DECLARE @TransactionAmount DECIMAL(18,4)

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		-- ⚠️ READ COMMITTED: Usa locks, propenso a deadlocks
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ReconcileWallet_UNSAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Reconciling wallet for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))

		-- ⚠️ PASO 1: Acceso a SUBSCRIBER_WALLETS primero
		PRINT '[ReconcileWallet_UNSAFE] Step 1: Locking SubscriberWallets for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		SELECT @CurrentCredits = creditsBalance
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ReconcileWallet_UNSAFE] SubscriberWallets locked - Credits: $' +
		      CAST(@CurrentCredits AS VARCHAR(20))

		-- Simular procesamiento (ventana para deadlock)
		PRINT '[ReconcileWallet_UNSAFE] Processing reconciliation... (delay ' +
		      CAST(@DelaySeconds AS VARCHAR(5)) + 's)'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ PASO 2: Acceso a TRANSACTIONS (CONFLICTO CON SP1 y SP2!)
		PRINT '[ReconcileWallet_UNSAFE] Step 2: Attempting to lock Transactions...'

		-- Obtener y lockear una transacción específica del subscriber
		SELECT TOP 1 @TransactionId = transactionId, @TransactionAmount = amount
		FROM [crm].[Transactions] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId
		  AND transactionStatusId IN (1, 2, 4) -- PENDING, PROCESSING, or CAPTURED
		ORDER BY createdAt DESC

		IF @TransactionId IS NOT NULL
		BEGIN
			PRINT '[ReconcileWallet_UNSAFE] Transaction locked - ID: ' +
			      CAST(@TransactionId AS VARCHAR(10)) + ', Amount: $' + CAST(@TransactionAmount AS VARCHAR(20))

			-- Actualizar la transacción con metadata de reconciliación
			UPDATE [crm].[Transactions]
			SET metadata = JSON_MODIFY(
			        ISNULL(metadata, '{}'),
			        '$.reconciledAt',
			        FORMAT(@Now, 'yyyy-MM-dd HH:mm:ss')
			    ),
			    updatedAt = @Now
			WHERE transactionId = @TransactionId

			PRINT '[ReconcileWallet_UNSAFE] Transaction reconciled'
		END
		ELSE
		BEGIN
			PRINT '[ReconcileWallet_UNSAFE] No transaction found to reconcile'
		END

		-- Actualizar wallet con metadata de reconciliación
		UPDATE [crm].[SubscriberWallets]
		SET lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		PRINT '[ReconcileWallet_UNSAFE] Reconciliation completed for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ReconcileWallet_UNSAFE] ✓ COMMITTED - Reconciliation completed'
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
				PRINT '[ReconcileWallet_UNSAFE] ⚠️ DEADLOCK VICTIM - Session killed by SQL Server'
				PRINT '[ReconcileWallet_UNSAFE] Reason: Inconsistent lock order with other procedures'
			END ELSE BEGIN
				PRINT '[ReconcileWallet_UNSAFE] ROLLED BACK - ' + @Message
			END
		END

		RAISERROR('ReconcileWallet_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ReconcileWallet_UNSAFE]'
GO
