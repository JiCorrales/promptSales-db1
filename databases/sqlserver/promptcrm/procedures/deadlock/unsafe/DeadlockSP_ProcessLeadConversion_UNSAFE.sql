-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra deadlock en procesamiento de conversiones
--              Usa tablas reales: Transactions, LeadConversions
-- Escenario: Procesa conversión de lead y actualiza transacciones
-- Orden de acceso: Transactions → LeadConversions
-- Problema: Orden inverso al de otros SPs causa deadlock
-----------------------------------------------------------
USE PromptCRM
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ProcessLeadConversion_UNSAFE]
	@LeadId INT,
	@SubscriberId INT,
	@ConversionValue DECIMAL(18,4),
	@DelaySeconds INT = 2
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()
	DECLARE @TransactionId INT
	DECLARE @TransactionAmount DECIMAL(18,4)
	DECLARE @OldCredits DECIMAL(18,4)
	DECLARE @NewCredits DECIMAL(18,4)

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		-- ⚠️ READ COMMITTED: Usa locks, propenso a deadlocks
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ProcessLeadConversion_UNSAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Processing conversion for Lead ' + CAST(@LeadId AS VARCHAR(10))

		-- ⚠️ PASO 1: Acceso a TRANSACTIONS primero (ORDEN INVERSO A SP1!)
		PRINT '[ProcessLeadConversion_UNSAFE] Step 1: Locking Transactions for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		-- Obtener y lockear una transacción específica del subscriber
		SELECT TOP 1 @TransactionId = transactionId, @TransactionAmount = amount
		FROM [crm].[Transactions] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId
		  AND transactionStatusId IN (1, 2) -- PENDING or PROCESSING
		ORDER BY createdAt DESC

		IF @TransactionId IS NOT NULL
		BEGIN
			PRINT '[ProcessLeadConversion_UNSAFE] Transaction locked - ID: ' +
			      CAST(@TransactionId AS VARCHAR(10)) + ', Amount: $' + CAST(@TransactionAmount AS VARCHAR(20))
		END
		ELSE
		BEGIN
			PRINT '[ProcessLeadConversion_UNSAFE] No transaction found to lock'
		END

		-- Simular procesamiento (ventana para deadlock)
		PRINT '[ProcessLeadConversion_UNSAFE] Processing conversion... (delay ' +
		      CAST(@DelaySeconds AS VARCHAR(5)) + 's)'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ PASO 2: Acceso a SUBSCRIBER_WALLETS (CONFLICTO CON SP1!)
		PRINT '[ProcessLeadConversion_UNSAFE] Step 2: Attempting to lock SubscriberWallets...'

		SELECT @OldCredits = creditsBalance
		FROM [crm].[SubscriberWallets] WITH (UPDLOCK, ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessLeadConversion_UNSAFE] SubscriberWallets locked - Credits: $' +
		      CAST(@OldCredits AS VARCHAR(20))

		-- Actualizar la billetera con el valor de la conversión
		SET @NewCredits = @OldCredits + @ConversionValue

		UPDATE [crm].[SubscriberWallets]
		SET totalRevenue = totalRevenue + @ConversionValue,
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessLeadConversion_UNSAFE] SubscriberWallets updated - New revenue added: $' +
		      CAST(@ConversionValue AS VARCHAR(20))

		-- Actualizar la transacción si existe
		IF @TransactionId IS NOT NULL
		BEGIN
			UPDATE [crm].[Transactions]
			SET metadata = JSON_MODIFY(
			        ISNULL(metadata, '{}'),
			        '$.conversionProcessed',
			        CAST(1 AS VARCHAR)
			    ),
			    updatedAt = @Now
			WHERE transactionId = @TransactionId

			PRINT '[ProcessLeadConversion_UNSAFE] Transaction metadata updated'
		END

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ProcessLeadConversion_UNSAFE] ✓ COMMITTED - Conversion processed successfully'
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
				PRINT '[ProcessLeadConversion_UNSAFE] ⚠️ DEADLOCK VICTIM - Session killed by SQL Server'
				PRINT '[ProcessLeadConversion_UNSAFE] Reason: Inconsistent lock order with other procedures'
			END ELSE BEGIN
				PRINT '[ProcessLeadConversion_UNSAFE] ROLLED BACK - ' + @Message
			END
		END

		RAISERROR('ProcessLeadConversion_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ProcessLeadConversion_UNSAFE]'
GO
