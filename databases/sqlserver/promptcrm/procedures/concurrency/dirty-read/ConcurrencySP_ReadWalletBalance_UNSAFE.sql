-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: UNSAFE - Demuestra Dirty Read Problem
--              Lee balances de billetera sin esperar commits
--              Esta versión CAUSA dirty reads (lee datos no confirmados)
-- Problema: Lee datos que pueden ser revertidos (rollback)
-- Escenario: Reporteador de balances que lee datos no confirmados
-- Tabla: SubscriberWallets (tabla específica para demos de concurrencia)
-----------------------------------------------------------

USE PromptCRM
GO

CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_ReadWalletBalance_UNSAFE]
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
		-- ⚠️ PROBLEMA: READ UNCOMMITTED permite leer datos no confirmados
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[ReadWalletBalance_UNSAFE] Starting balance read for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))
		PRINT '[ReadWalletBalance_UNSAFE] Using READ UNCOMMITTED (allows dirty reads)'

		-- ⚠️ PRIMERA LECTURA: Lee el balance (puede leer datos no confirmados)
		PRINT '[ReadWalletBalance_UNSAFE] Step 1: Reading wallet balance (may read uncommitted data)...'

		SELECT
			@CreditsBeforeDelay = creditsBalance,
			@RevenueBeforeDelay = totalRevenue,
			@LastUpdatedBefore = lastUpdated
		FROM [crm].[SubscriberWallets] WITH (NOLOCK) -- NOLOCK = READ UNCOMMITTED
		WHERE subscriberId = @SubscriberId

		PRINT '[ReadWalletBalance_UNSAFE] Credits Read: $' + CAST(ISNULL(@CreditsBeforeDelay, 0) AS VARCHAR(20))
		PRINT '[ReadWalletBalance_UNSAFE] Revenue Read: $' + CAST(ISNULL(@RevenueBeforeDelay, 0) AS VARCHAR(20))

		-- Esperar (durante este tiempo, otra transacción puede hacer rollback)
		PRINT '[ReadWalletBalance_UNSAFE] Waiting ' + CAST(@ReadDelay AS VARCHAR(5)) + 's...'
		DECLARE @WaitTime1 VARCHAR(12) = '00:00:0' + CAST(@ReadDelay AS VARCHAR(1))
		WAITFOR DELAY @WaitTime1

		-- ⚠️ SEGUNDA LECTURA: Releer el balance
		PRINT '[ReadWalletBalance_UNSAFE] Step 2: Re-reading wallet balance...'

		SELECT
			@CreditsAfterDelay = creditsBalance,
			@RevenueAfterDelay = totalRevenue,
			@LastUpdatedAfter = lastUpdated
		FROM [crm].[SubscriberWallets] WITH (NOLOCK)
		WHERE subscriberId = @SubscriberId

		PRINT '[ReadWalletBalance_UNSAFE] Credits Re-read: $' + CAST(ISNULL(@CreditsAfterDelay, 0) AS VARCHAR(20))
		PRINT '[ReadWalletBalance_UNSAFE] Revenue Re-read: $' + CAST(ISNULL(@RevenueAfterDelay, 0) AS VARCHAR(20))

		-- ⚠️ DETECTAR DIRTY READ
		IF @CreditsBeforeDelay <> @CreditsAfterDelay OR @RevenueBeforeDelay <> @RevenueAfterDelay BEGIN
			PRINT '[ReadWalletBalance_UNSAFE] ⚠️ DIRTY READ DETECTED!'
			PRINT '[ReadWalletBalance_UNSAFE] Data changed between reads - possible rollback occurred:'
			PRINT '  Credits Before: $' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ' | After: $' + CAST(@CreditsAfterDelay AS VARCHAR(20))
			PRINT '  Revenue Before: $' + CAST(@RevenueBeforeDelay AS VARCHAR(20)) +
			      ' | After: $' + CAST(@RevenueAfterDelay AS VARCHAR(20))
			PRINT ''
			PRINT '  This means we read UNCOMMITTED data that was later ROLLED BACK!'
		END ELSE BEGIN
			PRINT '[ReadWalletBalance_UNSAFE] Reads were consistent (no rollback detected)'
		END

		-- Usar el balance potencialmente incorrecto para tomar decisión de negocio
		PRINT '[ReadWalletBalance_UNSAFE] Step 3: Making business decision based on wallet balance...'

		IF @CreditsBeforeDelay >= 5000 BEGIN
			PRINT '[ReadWalletBalance_UNSAFE] ⚠️ Subscriber has high credits ($' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ') - approving premium feature access'
			PRINT '[ReadWalletBalance_UNSAFE] WARNING: This decision may be based on dirty (rolled back) data!'
		END ELSE BEGIN
			PRINT '[ReadWalletBalance_UNSAFE] Subscriber has low credits ($' + CAST(@CreditsBeforeDelay AS VARCHAR(20)) +
			      ') - denying premium feature access'
		END

		IF @InicieTransaccion=1 BEGIN
			COMMIT
			PRINT '[ReadWalletBalance_UNSAFE] COMMITTED'
		END
	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[ReadWalletBalance_UNSAFE] ROLLED BACK - ' + @Message
		END

		RAISERROR('ReadWalletBalance_UNSAFE Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_ReadWalletBalance_UNSAFE]'
GO
