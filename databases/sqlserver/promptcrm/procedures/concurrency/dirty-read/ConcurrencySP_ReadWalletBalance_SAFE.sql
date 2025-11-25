-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: SAFE - Previene Dirty Read Problem
--              Lee balances de billetera solo cuando están confirmados
--              Esta versión PREVIENE dirty reads usando READ COMMITTED
-- Solucion: READ COMMITTED solo lee datos confirmados
-- Escenario: Reporteador de balances mejorado que espera commits
-- Tabla: SubscriberWallets (tabla específica para demos de concurrencia)

USE PromptCRM
GO

-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_ReadWalletBalance_SAFE]
	@SubscriberId INT,
	@ReadDelay INT = 1 -- Segundos para simular procesamiento
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()

	-- Variables para lectura de balance
	DECLARE @CreditsBeforeDelay DECIMAL(18,4)
	DECLARE @CreditsAfterDelay DECIMAL(18,4)
	DECLARE @RevenueBeforeDelay DECIMAL(18,4)
	DECLARE @RevenueAfterDelay DECIMAL(18,4)
	DECLARE @LastUpdatedBefore DATETIME2
	DECLARE @LastUpdatedAfter DATETIME2

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		-- ✅ SOLUCION: READ COMMITTED garantiza que solo lee datos confirmados
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ReadWalletBalance_SAFE] Starting balance read for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))
		PRINT '[ReadWalletBalance_SAFE] Using READ COMMITTED (prevents dirty reads)'

		-- ✅ PRIMERA LECTURA: Lee el balance (solo datos confirmados)
		PRINT '[ReadWalletBalance_SAFE] Step 1: Reading wallet balance (waits for commit if needed)...'

		SELECT
			@CreditsBeforeDelay = creditsBalance,
			@RevenueBeforeDelay = totalRevenue,
			@LastUpdatedBefore = lastUpdated
		FROM [crm].[SubscriberWallets] WITH (READCOMMITTED) -- Explícito para claridad
		WHERE subscriberId = @SubscriberId

		PRINT '[ReadWalletBalance_SAFE] Credits Read: $' + CAST(ISNULL(@CreditsBeforeDelay, 0) AS VARCHAR(20))
		PRINT '[ReadWalletBalance_SAFE] Revenue Read: $' + CAST(ISNULL(@RevenueBeforeDelay, 0) AS VARCHAR(20))
		PRINT '[ReadWalletBalance_SAFE] This data is GUARANTEED to be committed'

		-- Esperar (durante este tiempo, los datos pueden cambiar, pero NO podemos leer datos no confirmados)
		PRINT '[ReadWalletBalance_SAFE] Waiting ' + CAST(@ReadDelay AS VARCHAR(5)) + 's...'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@ReadDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ✅ SEGUNDA LECTURA: Releer el balance (solo datos confirmados)
		PRINT '[ReadWalletBalance_SAFE] Step 2: Re-reading wallet balance...'

		SELECT
			@CreditsAfterDelay = creditsBalance,
			@RevenueAfterDelay = totalRevenue,
			@LastUpdatedAfter = lastUpdated
		FROM [crm].[SubscriberWallets] WITH (READCOMMITTED)
		WHERE subscriberId = @SubscriberId

		PRINT '[ReadWalletBalance_SAFE] Credits Re-read: $' + CAST(ISNULL(@CreditsAfterDelay, 0) AS VARCHAR(20))
		PRINT '[ReadWalletBalance_SAFE] Revenue Re-read: $' + CAST(ISNULL(@RevenueAfterDelay, 0) AS VARCHAR(20))

		-- ✅ VERIFICAR: Los datos pueden cambiar, pero NUNCA leemos datos no confirmados
		IF @CreditsBeforeDelay <> @CreditsAfterDelay OR @RevenueBeforeDelay <> @RevenueAfterDelay BEGIN
			PRINT '[ReadWalletBalance_SAFE] ℹ️ Data changed between reads (normal with READ COMMITTED):'
			PRINT '  Credits Before: $' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ' | After: $' + CAST(@CreditsAfterDelay AS VARCHAR(20))
			PRINT '  Revenue Before: $' + CAST(@RevenueBeforeDelay AS VARCHAR(20)) +
			      ' | After: $' + CAST(@RevenueAfterDelay AS VARCHAR(20))
			PRINT ''
			PRINT '  ✓ BUT: All data read was COMMITTED (no dirty reads possible)'
		END ELSE BEGIN
			PRINT '[ReadWalletBalance_SAFE] Reads were consistent (no changes occurred)'
		END

		-- Usar el balance CORRECTO para tomar decisión de negocio
		PRINT '[ReadWalletBalance_SAFE] Step 3: Making business decision based on COMMITTED balance...'

		IF @CreditsBeforeDelay >= 5000 BEGIN
			PRINT '[ReadWalletBalance_SAFE] ✓ Subscriber has high credits ($' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ') - approving premium feature access'
			PRINT '[ReadWalletBalance_SAFE] This decision is based on COMMITTED data (safe)'
		END ELSE BEGIN
			PRINT '[ReadWalletBalance_SAFE] Subscriber has low credits ($' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ') - denying premium feature access'
			PRINT '[ReadWalletBalance_SAFE] This decision is based on COMMITTED data (safe)'
		END

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ReadWalletBalance_SAFE] COMMITTED'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ReadWalletBalance_SAFE] ROLLED BACK - ' + @Message
		END

		RAISERROR('ReadWalletBalance_SAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_ReadWalletBalance_SAFE]'
GO
