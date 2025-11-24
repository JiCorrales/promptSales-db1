-----------------------------------------------------------
-- Autor: Alberto Bofi / Claude Code
-- Fecha: 2025-11-24
-- Descripcion: HELPER - SP para simular un UPDATE con ROLLBACK
--              Actualiza el balance de la billetera, espera, y hace ROLLBACK
--              Este SP sirve para demostrar el Dirty Read Problem
-- Propósito: Crear datos "fantasma" que serán leídos por otros SPs
-- Tabla: SubscriberWallets
-----------------------------------------------------------
CREATE OR ALTER PROCEDURE [crm].[ConcurrencySP_UpdateWalletWithRollback_Helper]
	@SubscriberId INT,
	@NewCredits DECIMAL(18,4),
	@NewRevenue DECIMAL(18,4),
	@DelaySeconds INT = 3 -- Tiempo antes de hacer ROLLBACK
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @ErrorNumber INT, @ErrorSeverity INT, @ErrorState INT
	DECLARE @Message VARCHAR(200)
	DECLARE @InicieTransaccion BIT
	DECLARE @Now DATETIME2 = GETUTCDATE()

	-- Variables para tracking
	DECLARE @OldCredits DECIMAL(18,4)
	DECLARE @OldRevenue DECIMAL(18,4)

	SET @InicieTransaccion = 0
	IF @@TRANCOUNT=0 BEGIN
		SET @InicieTransaccion = 1
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRANSACTION
	END

	BEGIN TRY
		PRINT '[UpdateWalletWithRollback_Helper] Session ' + CAST(@@SPID AS VARCHAR(10)) +
		      ': Starting UPDATE for Subscriber ' + CAST(@SubscriberId AS VARCHAR(10))

		-- Leer valores actuales
		SELECT
			@OldCredits = creditsBalance,
			@OldRevenue = totalRevenue
		FROM [crm].[SubscriberWallets]
		WHERE subscriberId = @SubscriberId

		PRINT '[UpdateWalletWithRollback_Helper] Current values:'
		PRINT '  Credits: $' + CAST(@OldCredits AS VARCHAR(20))
		PRINT '  Revenue: $' + CAST(@OldRevenue AS VARCHAR(20))

		-- Actualizar a nuevos valores (estos datos NO serán confirmados)
		PRINT '[UpdateWalletWithRollback_Helper] Step 1: Updating to new values (will ROLLBACK)...'

		UPDATE [crm].[SubscriberWallets]
		SET creditsBalance = @NewCredits,
		    totalRevenue = @NewRevenue,
		    lastUpdated = @Now
		WHERE subscriberId = @SubscriberId

		PRINT '[UpdateWalletWithRollback_Helper] Updated to:'
		PRINT '  Credits: $' + CAST(@NewCredits AS VARCHAR(20))
		PRINT '  Revenue: $' + CAST(@NewRevenue AS VARCHAR(20))
		PRINT '[UpdateWalletWithRollback_Helper] ⚠️ Data is UNCOMMITTED - other sessions with NOLOCK can see it!'

		-- Esperar para dar tiempo a que otros SPs lean los datos "fantasma"
		PRINT '[UpdateWalletWithRollback_Helper] Step 2: Waiting ' + CAST(@DelaySeconds AS VARCHAR(5)) +
		      's (window for dirty reads)...'
		DECLARE @WaitTime VARCHAR(12)
		IF @DelaySeconds < 10
			SET @WaitTime = '00:00:0' + CAST(@DelaySeconds AS VARCHAR(1))
		ELSE
			SET @WaitTime = '00:00:' + CAST(@DelaySeconds AS VARCHAR(2))
		WAITFOR DELAY @WaitTime

		-- ⚠️ ROLLBACK: Los cambios se revierten
		PRINT '[UpdateWalletWithRollback_Helper] Step 3: ROLLING BACK changes...'

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[UpdateWalletWithRollback_Helper] ⚠️ ROLLED BACK - Data reverted to original values!'
			PRINT '[UpdateWalletWithRollback_Helper] Any session that read the uncommitted data saw PHANTOM data!'
		END

		-- Verificar que los datos volvieron a su estado original
		SELECT
			@OldCredits = creditsBalance,
			@OldRevenue = totalRevenue
		FROM [crm].[SubscriberWallets]
		WHERE subscriberId = @SubscriberId

		PRINT '[UpdateWalletWithRollback_Helper] Final values (after ROLLBACK):'
		PRINT '  Credits: $' + CAST(@OldCredits AS VARCHAR(20))
		PRINT '  Revenue: $' + CAST(@OldRevenue AS VARCHAR(20))

	END TRY
	BEGIN CATCH
		SET @ErrorNumber = ERROR_NUMBER()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @Message = ERROR_MESSAGE()

		IF @InicieTransaccion=1 BEGIN
			ROLLBACK
			PRINT '[UpdateWalletWithRollback_Helper] ROLLED BACK (ERROR) - ' + @Message
		END

		RAISERROR('UpdateWalletWithRollback_Helper Error - %s (Error Number: %i)',
			@ErrorSeverity, @ErrorState, @Message, @ErrorNumber)
	END CATCH
END
GO

PRINT '✓ Created [crm].[ConcurrencySP_UpdateWalletWithRollback_Helper]'
GO
