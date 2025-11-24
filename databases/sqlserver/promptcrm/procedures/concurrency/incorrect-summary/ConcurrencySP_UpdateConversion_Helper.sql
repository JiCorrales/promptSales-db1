-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: HELPER - SP para actualizar conversiones durante cálculos
--              Actualiza el valor de conversiones para simular el problema
--              Este SP sirve para demostrar el Incorrect Summary Problem
-- Propósito: Modificar datos mientras otro SP los está leyendo múltiples veces
-- Tabla: LeadConversions
-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_UpdateConversion_Helper]
	@LeadId INT,
	@NewConversionValue DECIMAL(18,4),
	@DelaySeconds INT = 1 -- Tiempo antes de hacer UPDATE
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()

	-- Variables para tracking
	DECLARE @ConversionsUpdated INT
	DECLARE @OldTotal DECIMAL(18,4)
	DECLARE @NewTotal DECIMAL(18,4)

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[UpdateConversion_Helper] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Starting UPDATE for Lead ' + CAST(@LeadId AS VARCHAR(10))

		-- Leer valores actuales
		SELECT
			@OldTotal = ISNULL(SUM(conversionValue), 0),
			@ConversionsUpdated = COUNT(*)
		FROM [crm].[LeadConversions]
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[UpdateConversion_Helper] Current state:'
		PRINT '  Conversions: ' + CAST(@ConversionsUpdated AS VARCHAR(10))
		PRINT '  Total Value: $' + CAST(@OldTotal AS VARCHAR(20))

		-- Esperar antes de actualizar
		IF @DelaySeconds > 0 BEGIN
			PRINT '[UpdateConversion_Helper] Waiting ' + CAST(@DelaySeconds AS VARCHAR(5)) + 's before UPDATE...'
			DECLARE @WaitTime VARCHAR(12)
			IF @DelaySeconds < 10
				SET @WaitTime = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
			ELSE
				SET @WaitTime = '00:00:' + CAST(@DelaySeconds AS VARCHAR(2))
			WAITFOR DELAY @WaitTime
		END

		-- Actualizar TODAS las conversiones de este lead
		PRINT '[UpdateConversion_Helper] Step 1: Updating conversion values...'

		UPDATE [crm].[LeadConversions]
		SET conversionValue = @NewConversionValue,
		    updatedAt = @Now
		WHERE leadId = @LeadId
			AND enabled = 1

		SET @ConversionsUpdated = @@ROWCOUNT

		-- Calcular nuevo total
		SELECT @NewTotal = ISNULL(SUM(conversionValue), 0)
		FROM [crm].[LeadConversions]
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[UpdateConversion_Helper] Updated ' + CAST(@ConversionsUpdated AS VARCHAR(10)) + ' conversions'
		PRINT '[UpdateConversion_Helper] Old Total: $' + CAST(@OldTotal AS VARCHAR(20))
		PRINT '[UpdateConversion_Helper] New Total: $' + CAST(@NewTotal AS VARCHAR(20))
		PRINT '[UpdateConversion_Helper] Delta:     $' + CAST(ABS(@NewTotal - @OldTotal) AS VARCHAR(20))

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[UpdateConversion_Helper] ✓ COMMITTED - Changes are now visible'
			PRINT '[UpdateConversion_Helper] Other sessions reading with READ COMMITTED will see these changes'
		END

	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[UpdateConversion_Helper] ROLLED BACK - ' + @Message
		END

		RAISERROR('UpdateConversion_Helper Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_UpdateConversion_Helper]'
GO
