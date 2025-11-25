-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene Incorrect Summary Problem
--              Calcula métricas de conversión con lecturas repetibles
--              Esta versión PREVIENE incorrect summary usando REPEATABLE READ
-- Solucion: REPEATABLE READ + HOLDLOCK garantiza consistencia de lecturas
-- Escenario: Calculador de métricas mejorado con lecturas consistentes
-- Tabla: LeadConversions
-----------------------------------------------------------

use PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_CalculateConversionMetrics_SAFE]
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
		-- ✅ SOLUCION: REPEATABLE READ previene que los datos cambien entre lecturas
		SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[CalculateConversionMetrics_SAFE] Starting metrics calculation for Lead ' + CAST(@LeadId AS VARCHAR(10))
		PRINT '[CalculateConversionMetrics_SAFE] Using REPEATABLE READ (prevents unrepeatable reads)'

		-- ✅ PRIMERA LECTURA: Contar conversiones y sumar totales
		PRINT '[CalculateConversionMetrics_SAFE] Step 1: First read of conversions (with HOLDLOCK)...'

		SELECT
			@FirstReadCount = COUNT(*),
			@FirstReadTotal = ISNULL(SUM(conversionValue), 0),
			@FirstReadAvg = ISNULL(AVG(conversionValue), 0)
		FROM [crm].[LeadConversions] WITH (HOLDLOCK) -- Mantiene shared locks hasta COMMIT
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[CalculateConversionMetrics_SAFE] First Read:'
		PRINT '  Count: ' + CAST(@FirstReadCount AS VARCHAR(10))
		PRINT '  Total: $' + CAST(@FirstReadTotal AS VARCHAR(20))
		PRINT '  Average: $' + CAST(@FirstReadAvg AS VARCHAR(20))
		PRINT '[CalculateConversionMetrics_SAFE] Shared locks held - other sessions cannot modify this data'

		-- Simular procesamiento complejo (los datos NO pueden cambiar debido a HOLDLOCK)
		PRINT '[CalculateConversionMetrics_SAFE] Processing... (delay ' + CAST(@CalculationDelay AS VARCHAR(5)) + 's)'
		PRINT '[CalculateConversionMetrics_SAFE] Data is LOCKED - no updates possible until COMMIT'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@CalculationDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ✅ SEGUNDA LECTURA: Releer las mismas conversiones (datos garantizados iguales)
		PRINT '[CalculateConversionMetrics_SAFE] Step 2: Second read of conversions...'

		SELECT
			@SecondReadCount = COUNT(*),
			@SecondReadTotal = ISNULL(SUM(conversionValue), 0),
			@SecondReadAvg = ISNULL(AVG(conversionValue), 0)
		FROM [crm].[LeadConversions] WITH (HOLDLOCK)
		WHERE leadId = @LeadId
			AND enabled = 1

		PRINT '[CalculateConversionMetrics_SAFE] Second Read:'
		PRINT '  Count: ' + CAST(@SecondReadCount AS VARCHAR(10))
		PRINT '  Total: $' + CAST(@SecondReadTotal AS VARCHAR(20))
		PRINT '  Average: $' + CAST(@SecondReadAvg AS VARCHAR(20))

		-- ✅ VERIFICAR: Los datos DEBEN ser idénticos
		IF @FirstReadCount <> @SecondReadCount OR @FirstReadTotal <> @SecondReadTotal BEGIN
			PRINT '[CalculateConversionMetrics_SAFE] ❌ UNEXPECTED! Data changed (should never happen with REPEATABLE READ):'
			PRINT '  First:  ' + CAST(@FirstReadCount AS VARCHAR(10)) + ' conversions, Total: $' +
			      CAST(@FirstReadTotal AS VARCHAR(20))
			PRINT '  Second: ' + CAST(@SecondReadCount AS VARCHAR(10)) + ' conversions, Total: $' +
			      CAST(@SecondReadTotal AS VARCHAR(20))
		END ELSE BEGIN
			PRINT '[CalculateConversionMetrics_SAFE] ✓ Reads were CONSISTENT (as expected with REPEATABLE READ)'
			PRINT '[CalculateConversionMetrics_SAFE] Data integrity guaranteed throughout transaction'
		END

		-- Calcular score basado en lecturas CONSISTENTES
		SET @MetricScore = CASE
			WHEN @SecondReadCount >= 10 AND @SecondReadAvg >= 100 THEN 5
			WHEN @SecondReadCount >= 5 AND @SecondReadAvg >= 50 THEN 4
			WHEN @SecondReadCount >= 3 THEN 3
			ELSE 2
		END

		PRINT '[CalculateConversionMetrics_SAFE] Step 3: Calculated Metric Score: ' + CAST(@MetricScore AS VARCHAR(2))
		PRINT '[CalculateConversionMetrics_SAFE] ✓ This score is based on CONSISTENT data (safe)'

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[CalculateConversionMetrics_SAFE] COMMITTED (releasing locks)'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[CalculateConversionMetrics_SAFE] ROLLED BACK - ' + @Message
		END

		RAISERROR('CalculateConversionMetrics_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_CalculateConversionMetrics_SAFE]'
GO
