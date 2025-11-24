# 🔄 Lost Update Problem - PromptCRM

**Autor:** Alberto Bofi / Claude Code
**Fecha:** 2025-11-24
**Tabla Utilizada:** `SubscriberWallets` (nueva tabla específica para demos)

---

## 📋 Descripción del Problema

El **Lost Update** es un problema de concurrencia donde dos transacciones concurrentes **leen el mismo dato**, lo **modifican independientemente**, y luego **escriben** sus resultados. El resultado final solo refleja la **última escritura**, y todas las actualizaciones anteriores se **pierden**.

### Patrón Problemático: Read-Modify-Write

```
1. READ  → SELECT @valor = columna FROM tabla
2. MODIFY → SET @valor = @valor + delta  (en memoria)
3. WRITE  → UPDATE tabla SET columna = @valor
```

**Problema:** Entre el READ y el WRITE, otra sesión puede hacer lo mismo, causando que una actualización sobrescriba la otra.

---

## 🎯 Escenario de Negocio

**Situación:** Dos promociones aplicando créditos simultáneamente a la misma billetera de subscriber.

```
Balance inicial: $1,000

PROMOCIÓN 1:                    PROMOCIÓN 2:
1. Lee balance = $1,000         1. Lee balance = $1,000
2. Calcula: $1,000 + $500       2. Calcula: $1,000 + $300
   = $1,500                        = $1,300
3. Escribe $1,500               3. Escribe $1,300 (¡sobrescribe!)

Balance final: $1,300 (solo la segunda promoción)
Balance esperado: $1,000 + $500 + $300 = $1,800
Lost update: $500
```

---

## 🗂️ Archivos en esta Carpeta

| Archivo | Propósito |
|---------|-----------|
| `ConcurrencySP_ApplyCredit_UNSAFE.sql` | Demuestra el problema con read-modify-write |
| `ConcurrencySP_ApplyCredit_SAFE.sql` | Solución con UPDATE atómico + UPDLOCK |

---

## 📊 Tabla Utilizada: SubscriberWallets

```sql
CREATE TABLE [crm].[SubscriberWallets](
    [walletId] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [subscriberId] [int] NOT NULL,

    [creditsBalance] [decimal](18, 4) NOT NULL DEFAULT 0.00,  -- Para Lost Update
    [totalRevenue] [decimal](18, 4) NOT NULL DEFAULT 0.00,    -- Acumulador

    [lastUpdated] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [rowVersion] [rowversion] NOT NULL  -- Para optimistic locking
);
```

---

## ⚠️ Procedimiento UNSAFE

### ConcurrencySP_ApplyCredit_UNSAFE

**Problema:** Usa patrón **read-modify-write**

```sql
-- ⚠️ PASO 1: LEER
SELECT @OriginalCredits = creditsBalance
FROM [crm].[SubscriberWallets]
WHERE subscriberId = @SubscriberId

-- ⚠️ PASO 2: CALCULAR (en memoria, fuera de la DB)
SET @NewCredits = @OriginalCredits + @CreditAmount

WAITFOR DELAY '00:00:02'  -- Ventana para conflicto

-- ⚠️ PASO 3: ESCRIBIR (puede sobrescribir cambios concurrentes)
UPDATE [crm].[SubscriberWallets]
SET creditsBalance = @NewCredits  -- Valor calculado hace 2 segundos
WHERE subscriberId = @SubscriberId
```

**¿Qué hace mal?**

1. Lee el valor actual
2. Calcula nuevo valor **fuera de la base de datos**
3. Durante el cálculo, otra sesión puede modificar el mismo dato
4. Escribe el valor calculado, **sobrescribiendo** cambios concurrentes

**Timeline de Conflicto:**

```
TIME  SESSION 1 (Promoción A: +$500)      SESSION 2 (Promoción B: +$300)
----  --------------------------------     --------------------------------
0s    Lee balance = $1,000
1s                                         Lee balance = $1,000
2s    Calcula: $1,000 + $500 = $1,500
3s                                         Calcula: $1,000 + $300 = $1,300
4s    Escribe $1,500 → ✅ Guardado
5s                                         Escribe $1,300 → ⚠️ SOBRESCRIBE

Final: $1,300 (solo Promoción B)
Esperado: $1,800 (ambas promociones)
Pérdida: $500
```

---

## ✅ Procedimiento SAFE

### ConcurrencySP_ApplyCredit_SAFE

**Solución 1:** UPDATE con cálculo **inline** (operación atómica)

```sql
-- ✅ LECTURA con UPDLOCK (previene lecturas concurrentes para actualización)
SELECT @OriginalCredits = creditsBalance
FROM [crm].[SubscriberWallets] WITH (UPDLOCK)
WHERE subscriberId = @SubscriberId

WAITFOR DELAY '00:00:02'  -- Otras sesiones ESPERAN

-- ✅ UPDATE ATÓMICO: cálculo inline usando valor ACTUAL
UPDATE [crm].[SubscriberWallets]
SET creditsBalance = creditsBalance + @CreditAmount,  -- Usa valor ACTUAL
    totalRevenue = totalRevenue + @CreditAmount
WHERE subscriberId = @SubscriberId
```

**¿Qué hace bien?**

1. **UPDLOCK**: Adquiere lock de actualización en la lectura
   - Previene que otras sesiones lean para actualizar
   - Otras sesiones ESPERAN hasta que terminemos
2. **Cálculo inline**: `creditsBalance + @CreditAmount`
   - No calculamos fuera de la DB
   - Usa el valor **ACTUAL** en el momento del UPDATE
3. **Operación atómica**: READ + MODIFY + WRITE en un solo statement

**Timeline Sin Conflicto:**

```
TIME  SESSION 1 (Promoción A: +$500)      SESSION 2 (Promoción B: +$300)
----  --------------------------------     --------------------------------
0s    Lee balance = $1,000 (UPDLOCK)
1s                                         Intenta leer → ⏳ ESPERA (bloqueado)
2s    Procesa...
4s    UPDATE: $1,000 + $500 = $1,500
5s    COMMIT (libera lock) → ✅
6s                                         Lee balance = $1,500 (UPDLOCK)
8s                                         UPDATE: $1,500 + $300 = $1,800 ✅
9s                                         COMMIT

Final: $1,800 ✅ (ambas promociones aplicadas)
Pérdida: $0
```

**Solución 2:** Retry logic para deadlocks

```sql
RETRY_TRANSACTION:
BEGIN TRANSACTION
    -- operaciones...
    COMMIT
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 1205 AND @RetryCount < 3 BEGIN
        SET @RetryCount = @RetryCount + 1
        WAITFOR DELAY '00:00:00.100'
        GOTO RETRY_TRANSACTION
    END
END CATCH
```

---

## 🧪 Cómo Ejecutar la Demo

### Prerrequisitos

1. Base de datos PromptCRM con tabla SubscriberWallets
2. Al menos 1 subscriber con balance inicial
3. SSMS con 2 ventanas de Query

### Demo UNSAFE (Demuestra el problema)

**Ventana 1 (Promoción A: +$500):**
```sql
-- Ejecutar primero
EXEC [crm].[ConcurrencySP_ApplyCredit_UNSAFE]
    @SubscriberId = 1,
    @CreditAmount = 500.00,
    @CreditReason = 'Black Friday Promo',
    @ProcessingDelay = 3
```

**Ventana 2 (Promoción B: +$300) - Ejecutar 1 segundo después:**
```sql
-- Ejecutar 1 segundo después
EXEC [crm].[ConcurrencySP_ApplyCredit_UNSAFE]
    @SubscriberId = 1,
    @CreditAmount = 300.00,
    @CreditReason = 'Loyalty Bonus',
    @ProcessingDelay = 3
```

**Resultado Esperado:**
- Balance inicial: $1,000
- Balance final: $1,300 (solo una promoción aplicada)
- ⚠️ **LOST UPDATE: $500**

**Verificar:**
```sql
SELECT creditsBalance, totalRevenue
FROM [crm].[SubscriberWallets]
WHERE subscriberId = 1
```

### Demo SAFE (Previene el problema)

**Resetear datos primero:**
```sql
UPDATE [crm].[SubscriberWallets]
SET creditsBalance = 1000.00, totalRevenue = 5000.00
WHERE subscriberId = 1
```

**Ventana 1 (Promoción A: +$500):**
```sql
-- Ejecutar primero
EXEC [crm].[ConcurrencySP_ApplyCredit_SAFE]
    @SubscriberId = 1,
    @CreditAmount = 500.00,
    @CreditReason = 'Black Friday Promo',
    @ProcessingDelay = 3
```

**Ventana 2 (Promoción B: +$300) - Ejecutar 1 segundo después:**
```sql
-- Ejecutar 1 segundo después
EXEC [crm].[ConcurrencySP_ApplyCredit_SAFE]
    @SubscriberId = 1,
    @CreditAmount = 300.00,
    @CreditReason = 'Loyalty Bonus',
    @ProcessingDelay = 3
```

**Resultado Esperado:**
- Balance inicial: $1,000
- Balance final: $1,800 (ambas promociones aplicadas)
- ✅ **NO HAY LOST UPDATE**

**Verificar:**
```sql
SELECT creditsBalance, totalRevenue
FROM [crm].[SubscriberWallets]
WHERE subscriberId = 1
-- creditsBalance debe ser 1,800.00
```

---

## 📊 Comparación Visual

| Aspecto | UNSAFE (Read-Modify-Write) | SAFE (Atomic Update) |
|---------|---------------------------|---------------------|
| Patrón | SELECT → CALCULAR → UPDATE | UPDATE con cálculo inline |
| Cálculo | Fuera de la DB (memoria) | Dentro del UPDATE |
| Lock strategy | Sin UPDLOCK | UPDLOCK en SELECT |
| Bloqueo | No bloquea otras lecturas | Bloquea otras actualizaciones |
| Riesgo de lost update | ✅ Alto | ❌ Ninguno |
| Concurrencia | ⚡⚡⚡ Alta (peligroso) | ⚡⚡ Media (seguro) |
| Retry logic | ❌ No | ✅ Sí (deadlocks) |

---

## 💡 Best Practices

### ✅ DO

1. **Usar UPDATE con cálculo inline:**
   ```sql
   -- ✅ CORRECTO
   UPDATE Tabla SET balance = balance + @amount
   ```

2. **Usar UPDLOCK cuando lees para actualizar:**
   ```sql
   SELECT @valor = columna
   FROM Tabla WITH (UPDLOCK)
   WHERE id = @id
   ```

3. **Operaciones atómicas para contadores:**
   ```sql
   UPDATE Tabla
   SET totalPurchases = totalPurchases + 1,
       totalSpent = totalSpent + @amount
   ```

4. **Implementar retry logic para deadlocks**

### ❌ DON'T

1. ❌ **Patrón read-modify-write:**
   ```sql
   -- ❌ INCORRECTO
   SELECT @balance = balance FROM Tabla
   SET @balance = @balance + @amount
   UPDATE Tabla SET balance = @balance
   ```

2. ❌ **Cálculos largos entre READ y WRITE**

3. ❌ **Asumir que el valor leído es aún el actual al escribir**

4. ❌ **Ignorar @@ROWCOUNT después de UPDATE**

---

## 🔍 Técnicas Avanzadas

### Optimistic Concurrency Control con RowVersion

```sql
-- Leer con rowVersion
DECLARE @RowVersion rowversion
SELECT @Balance = balance, @RowVersion = rowVersion
FROM [crm].[SubscriberWallets]
WHERE subscriberId = @Id

-- Calcular...
SET @NewBalance = @Balance + @Amount

-- UPDATE solo si rowVersion no cambió
UPDATE [crm].[SubscriberWallets]
SET balance = @NewBalance,
    lastUpdated = GETUTCDATE()
WHERE subscriberId = @Id
    AND rowVersion = @RowVersion  -- ✅ Solo actualiza si no cambió

IF @@ROWCOUNT = 0 BEGIN
    -- Alguien más actualizó, reintentar
    RAISERROR('Concurrent update detected', 16, 1)
END
```

---

## 📚 Referencias

- [Lost Updates and Snapshot Isolation](https://docs.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)
- [UPDLOCK Table Hint](https://docs.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)
- [Optimistic Concurrency Control](https://docs.microsoft.com/en-us/sql/relational-databases/sql/optimistic-data-concurrency-control)

---

## ✅ Checklist de Validación

- [ ] Tabla SubscriberWallets con datos
- [ ] SP UNSAFE creado y ejecutable
- [ ] SP SAFE creado y ejecutable
- [ ] Demo UNSAFE pierde una actualización ($500)
- [ ] Demo SAFE aplica ambas actualizaciones ($800 total)
- [ ] UPDLOCK funciona correctamente
- [ ] Retry logic maneja deadlocks
- [ ] Logs muestran diferencia clara

---

**🎓 Entregable para:** Bases de Datos I - TEC
**👥 Desarrollado por:** Alberto Bofi con asistencia de Claude Code
