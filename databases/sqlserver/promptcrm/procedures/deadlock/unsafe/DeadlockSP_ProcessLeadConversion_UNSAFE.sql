-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra deadlock en procesamiento de conversiones
--              Usa tablas reales: Transactions, LeadConversions
-- Escenario: Procesa conversión de lead y actualiza transacciones
-- Orden de acceso: Transactions → LeadConversions
-- Problema: Orden inverso al de otros SPs causa deadlock
-----------------------------------------------------------
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
	DECLARE @TransactionCount INT
	DECLARE @ConversionCount INT

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

		-- ⚠️ PASO 1: Acceso a TRANSACTIONS primero
		PRINT '[ProcessLeadConversion_UNSAFE] Step 1: Locking Transactions for Subscriber ' +
		      CAST(@SubscriberId AS VARCHAR(10))

		SELECT @TransactionCount = COUNT(*)
		FROM [crm].[Transactions] WITH (UPDLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessLeadConversion_UNSAFE] Transactions locked - Count: ' +
		      CAST(@TransactionCount AS VARCHAR(10))

		-- Simular procesamiento (ventana para deadlock)
		PRINT '[ProcessLeadConversion_UNSAFE] Processing conversion... (delay ' +
		      CAST(@DelaySeconds AS VARCHAR(5)) + 's)'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ PASO 2: Acceso a LEAD_CONVERSIONS (CONFLICTO!)
		PRINT '[ProcessLeadConversion_UNSAFE] Step 2: Attempting to access LeadConversions...'

		SELECT @ConversionCount = COUNT(*)
		FROM [crm].[LeadConversions] WITH (UPDLOCK)
		WHERE leadId = @LeadId

		PRINT '[ProcessLeadConversion_UNSAFE] Found ' + CAST(@ConversionCount AS VARCHAR(10)) +
		      ' existing conversions for this lead'

		-- Actualizar conversiones
		UPDATE [crm].[LeadConversions]
		SET conversionValue = conversionValue + @ConversionValue,
		    updatedAt = @Now
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[ProcessLeadConversion_UNSAFE] Updated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) +
		      ' conversions'

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
