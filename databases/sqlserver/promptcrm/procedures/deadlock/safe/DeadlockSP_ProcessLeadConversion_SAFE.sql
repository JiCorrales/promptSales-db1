-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene deadlocks con orden consistente
--              Usa tablas reales: Transactions, LeadConversions
-- Escenario: Procesa conversión con orden consistente
-- SOLUTION: Orden consistente = Transactions → LeadConversions
--           Este orden DEBE ser respetado por TODOS los procedures
-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[DeadlockSP_ProcessLeadConversion_SAFE]
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
	DECLARE @RetryCount INT = 0
	DECLARE @MaxRetries INT = 3
	DECLARE @TransactionCount INT
	DECLARE @ConversionCount INT
	DECLARE @RowsAffected INT

	-- ✅ SOLUTION 1: Retry logic para manejar deadlocks raros
	RETRY_TRANSACTION:

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ProcessLeadConversion_SAFE] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Processing conversion for Lead ' + CAST(@LeadId AS VARCHAR(10))

		-- ✅ SOLUTION 2: ORDEN CONSISTENTE (Transactions → LeadConversions)
		-- Paso 1: Acceder a TRANSACTIONS primero (SIEMPRE PRIMERO)
		PRINT '[ProcessLeadConversion_SAFE] Step 1: Accessing Transactions first (consistent order)...'

		SELECT @TransactionCount = COUNT(*)
		FROM [crm].[Transactions] WITH (ROWLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ProcessLeadConversion_SAFE] Transactions accessed - Count: ' +
		      CAST(@TransactionCount AS VARCHAR(10))

		-- Simular procesamiento breve
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- Paso 2: Acceder a LEAD_CONVERSIONS segundo (SIEMPRE SEGUNDO)
		PRINT '[ProcessLeadConversion_SAFE] Step 2: Updating LeadConversions...'

		SELECT @ConversionCount = COUNT(*)
		FROM [crm].[LeadConversions] WITH (UPDLOCK)
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[ProcessLeadConversion_SAFE] Found ' + CAST(@ConversionCount AS VARCHAR(10)) +
		      ' conversions to update'

		UPDATE [crm].[LeadConversions] WITH (ROWLOCK)
		SET conversionValue = conversionValue + @ConversionValue,
		    updatedAt = @Now
		WHERE leadId = @LeadId
			AND enabled = 1

		SET @RowsAffected = @@ROWCOUNT

		PRINT '[ProcessLeadConversion_SAFE] Updated ' + CAST(@RowsAffected AS VARCHAR(10)) +
		      ' conversions with value increase of $' + CAST(@ConversionValue AS VARCHAR(20))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ProcessLeadConversion_SAFE] ✓ COMMITTED - No deadlock (consistent order)'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ProcessLeadConversion_SAFE] ROLLED BACK - ' + @Message
		END

		-- ✅ SOLUTION 3: Retry en caso de deadlock raro
		IF @ErrorNumber = 1205 AND @RetryCount < @MaxRetries BEGIN
			SET @RetryCount = @RetryCount + 1
			PRINT '[ProcessLeadConversion_SAFE] ⚠️ Deadlock detected. Retrying... (Attempt ' +
			      CAST(@RetryCount AS VARCHAR(2)) + '/' + CAST(@MaxRetries AS VARCHAR(2)) + ')'
			WAITFOR DELAY '00:00:00.100'
			GOTO RETRY_TRANSACTION
		END

		IF @ErrorNumber = 1205 BEGIN
			PRINT '[ProcessLeadConversion_SAFE] ❌ DEADLOCK: Max retries exceeded'
		END

		RAISERROR('ProcessLeadConversion_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[DeadlockSP_ProcessLeadConversion_SAFE]'
GO
