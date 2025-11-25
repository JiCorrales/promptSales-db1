-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra Incorrect Summary Problem
--              Calcula métricas de conversión leyendo LeadConversions múltiples veces
--              Esta versión CAUSA incorrect summary (unrepeatable read)
-- Problema: Lectura inconsistente - los datos cambian entre lecturas
-- Escenario: Calculador de métricas que lee conversiones mientras otras sesiones las actualizan
-- Tabla: LeadConversions
-----------------------------------------------------------

use PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_CalculateConversionMetrics_UNSAFE]
	@LeadId INT,
	@CalculationDelay INT = 2 -- Segundos para simular procesamiento
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()

	-- Variables para cálculo de métricas
	DECLARE @FirstReadTotal DECIMAL(18,4)
	DECLARE @FirstReadCount INT
	DECLARE @FirstReadAvg DECIMAL(18,4)
	DECLARE @SecondReadTotal DECIMAL(18,4)
	DECLARE @SecondReadCount INT
	DECLARE @SecondReadAvg DECIMAL(18,4)
	DECLARE @MetricScore INT

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		-- ⚠️ PROBLEMA: READ COMMITTED permite que los datos cambien entre lecturas
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[CalculateConversionMetrics_UNSAFE] Starting metrics calculation for Lead ' + CAST(@LeadId AS VARCHAR(10))

		-- ⚠️ PRIMERA LECTURA: Contar conversiones y sumar totales
		PRINT '[CalculateConversionMetrics_UNSAFE] Step 1: First read of conversions...'

		SELECT
			@FirstReadCount = COUNT(*),
			@FirstReadTotal = ISNULL(SUM(conversionValue), 0),
			@FirstReadAvg = ISNULL(AVG(conversionValue), 0)
		FROM [crm].[LeadConversions]
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[CalculateConversionMetrics_UNSAFE] First Read:'
		PRINT '  Count: ' + CAST(@FirstReadCount AS VARCHAR(10))
		PRINT '  Total: $' + CAST(@FirstReadTotal AS VARCHAR(20))
		PRINT '  Average: $' + CAST(@FirstReadAvg AS VARCHAR(20))

		-- Simular procesamiento complejo (aquí otras sesiones pueden modificar los datos)
		PRINT '[CalculateConversionMetrics_UNSAFE] Processing... (delay ' + CAST(@CalculationDelay AS VARCHAR(5)) + 's)'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@CalculationDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ SEGUNDA LECTURA: Releer las mismas conversiones
		PRINT '[CalculateConversionMetrics_UNSAFE] Step 2: Second read of conversions...'

		SELECT
			@SecondReadCount = COUNT(*),
			@SecondReadTotal = ISNULL(SUM(conversionValue), 0),
			@SecondReadAvg = ISNULL(AVG(conversionValue), 0)
		FROM [crm].[LeadConversions]
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[CalculateConversionMetrics_UNSAFE] Second Read:'
		PRINT '  Count: ' + CAST(@SecondReadCount AS VARCHAR(10))
		PRINT '  Total: $' + CAST(@SecondReadTotal AS VARCHAR(20))
		PRINT '  Average: $' + CAST(@SecondReadAvg AS VARCHAR(20))

		-- ⚠️ DETECTAR INCONSISTENCIA
		IF @FirstReadCount <> @SecondReadCount OR @FirstReadTotal <> @SecondReadTotal BEGIN
			PRINT '[CalculateConversionMetrics_UNSAFE] ⚠️ INCORRECT SUMMARY DETECTED!'
			PRINT '[CalculateConversionMetrics_UNSAFE] Data changed between reads (Unrepeatable Read):'
			PRINT '  First:  ' + CAST(@FirstReadCount AS VARCHAR(10)) + ' conversions, Total: $' +
			      CAST(@FirstReadTotal AS VARCHAR(20)) + ', Avg: $' + CAST(@FirstReadAvg AS VARCHAR(20))
			PRINT '  Second: ' + CAST(@SecondReadCount AS VARCHAR(10)) + ' conversions, Total: $' +
			      CAST(@SecondReadTotal AS VARCHAR(20)) + ', Avg: $' + CAST(@SecondReadAvg AS VARCHAR(20))
			PRINT '  Delta:  ' + CAST(ABS(@SecondReadCount - @FirstReadCount) AS VARCHAR(10)) +
			      ' conversions, $' + CAST(ABS(@SecondReadTotal - @FirstReadTotal) AS VARCHAR(20))
			PRINT ''
			PRINT '  ⚠️ The metrics calculation is based on INCONSISTENT data!'
		END ELSE BEGIN
			PRINT '[CalculateConversionMetrics_UNSAFE] Reads were consistent (no concurrent updates detected)'
		END

		-- Calcular score basado en la SEGUNDA lectura (datos potencialmente inconsistentes)
		SET @MetricScore = CASE
			WHEN @SecondReadCount >= 10 AND @SecondReadAvg >= 100 THEN 5
			WHEN @SecondReadCount >= 5 AND @SecondReadAvg >= 50 THEN 4
			WHEN @SecondReadCount >= 3 THEN 3
			ELSE 2
		END

		PRINT '[CalculateConversionMetrics_UNSAFE] Step 3: Calculated Metric Score: ' + CAST(@MetricScore AS VARCHAR(2))
		PRINT '[CalculateConversionMetrics_UNSAFE] ⚠️ WARNING: This score may be based on inconsistent data!'

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[CalculateConversionMetrics_UNSAFE] COMMITTED'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[CalculateConversionMetrics_UNSAFE] ROLLED BACK - ' + @Message
		END

		RAISERROR('CalculateConversionMetrics_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_CalculateConversionMetrics_UNSAFE]'
GO
