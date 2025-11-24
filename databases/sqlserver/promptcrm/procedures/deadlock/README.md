# ⚔️ Deadlock Scenarios - PromptCRM

**Autor:** Alberto Bofi / Claude Code
**Fecha:** 2025-11-24
**Tablas Utilizadas:** `SubscriberWallets`, `Transactions`, `LeadConversions`

---

## 📋 Descripción del Problema

Un **deadlock** ocurre cuando dos o más transacciones se bloquean mutuamente esperando por recursos que la otra tiene bloqueados, creando un ciclo de espera que nunca se resuelve naturalmente.

### Analogía del Mundo Real

Imagina dos personas en puertas diferentes:

```
PERSONA A                    PERSONA B
Entra por puerta 1 🚪        Entra por puerta 2 🚪
(bloquea puerta 1)           (bloquea puerta 2)

Intenta abrir puerta 2 ⏳    Intenta abrir puerta 1 ⏳
(espera a B)                 (espera a A)

⚠️ DEADLOCK: Ninguno puede avanzar
```

---

## 🎯 Escenario de Negocio

**Situación:** Dos procesos accediendo a las mismas tablas en **orden diferente**

### Escenario 1: ProcessSubscriptionPayment vs ProcessLeadConversion

```
PROCESO A: ProcessSubscriptionPayment
1. Lock SubscriberWallets (subscriberId=1)
2. Espera...
3. Intenta lock Transactions (subscriberId=1) ⏳

PROCESO B: ProcessLeadConversion
1. Lock Transactions (subscriberId=1)
2. Espera...
3. Intenta lock LeadConversions (leadId=X) ⏳

Si hay dependencias cruzadas → DEADLOCK
```

---

## 🗂️ Archivos en esta Carpeta

```
procedures/deadlock/
├── README.md (este archivo)
│
├── unsafe/
│   ├── DeadlockSP_ProcessSubscriptionPayment_UNSAFE.sql
│   └── DeadlockSP_ProcessLeadConversion_UNSAFE.sql
│
└── safe/
    ├── DeadlockSP_ProcessSubscriptionPayment_SAFE.sql
    └── DeadlockSP_ProcessLeadConversion_SAFE.sql
```

---

## 📊 Tablas Utilizadas

### 1. SubscriberWallets (Billeteras de créditos)

```sql
CREATE TABLE [crm].[SubscriberWallets](
    [walletId] [int] PRIMARY KEY,
    [subscriberId] [int] NOT NULL,
    [creditsBalance] [decimal](18, 4),
    [totalRevenue] [decimal](18, 4),
    [lastUpdated] [datetime2],
    [rowVersion] [rowversion]
);
```

### 2. Transactions (Transacciones financieras)

```sql
CREATE TABLE [crm].[Transactions](
    [transactionId] [int],
    [subscriberId] [int] NOT NULL,
    [amount] [decimal](18,4),
    [transactionStatusId] [int],
    [createdAt] [datetime2],
    ...
);
```

### 3. LeadConversions (Conversiones de leads)

```sql
CREATE TABLE [crm].[LeadConversions](
    [leadConversionId] [bigint] PRIMARY KEY,
    [leadId] [int] NOT NULL,
    [conversionValue] [decimal](18,4),
    [enabled] [bit],
    ...
);
```

---

## ⚠️ Procedures UNSAFE

### Causa del Deadlock: Orden Inconsistente de Locks

#### DeadlockSP_ProcessSubscriptionPayment_UNSAFE

**Orden de acceso:**
```
1. SubscriberWallets (UPDLOCK) 🔒
2. Espera 2 segundos ⏰
3. Transactions (UPDLOCK) 🔒
```

#### DeadlockSP_ProcessLeadConversion_UNSAFE

**Orden de acceso:**
```
1. Transactions (UPDLOCK) 🔒
2. Espera 2 segundos ⏰
3. LeadConversions (UPDLOCK) 🔒
```

### Timeline del Deadlock

```
TIME  SESSION 1 (Payment)                   SESSION 2 (Conversion)
----  ------------------------------------   -----------------------------
0s    Lock SubscriberWallets (Sub 1) 🔒

1s                                           Lock Transactions (Sub 1) 🔒

2s    Intenta lock Transactions (Sub 1)
      ⏳ ESPERA (bloqueado por S2)

3s                                           Intenta lock LeadConversions
                                             ⏳ ESPERA (si hay relación)

      ⚠️ DEADLOCK DETECTADO
      SQL Server mata una sesión (victim)
```

---

## ✅ Procedures SAFE

### Solución 1: Orden Consistente de Locks

**REGLA DE ORO:** Todos los procedures deben acceder a las tablas en el **MISMO ORDEN**

#### Orden Consistente Definido:

```
1. Transactions (SIEMPRE PRIMERO)
2. SubscriberWallets (SIEMPRE SEGUNDO)
3. LeadConversions (SIEMPRE TERCERO)
```

#### DeadlockSP_ProcessSubscriptionPayment_SAFE

```sql
-- ✅ Orden consistente
1. Transactions (ROWLOCK) 🔒
2. SubscriberWallets (UPDLOCK) 🔒
```

#### DeadlockSP_ProcessLeadConversion_SAFE

```sql
-- ✅ Orden consistente
1. Transactions (ROWLOCK) 🔒
2. LeadConversions (UPDLOCK) 🔒
```

### Timeline Sin Deadlock

```
TIME  SESSION 1 (Payment SAFE)              SESSION 2 (Conversion SAFE)
----  ------------------------------------   -----------------------------
0s    Lock Transactions (Sub 1) 🔒

1s                                           Intenta lock Transactions
                                             ⏳ ESPERA (orden correcto)

2s    Lock SubscriberWallets (Sub 1) 🔒
      Procesa...
      COMMIT ✅ (libera locks)

3s                                           Lock Transactions 🔒
                                             Lock LeadConversions 🔒
                                             COMMIT ✅

      ✅ NO HAY DEADLOCK
```

### Solución 2: Retry Logic

```sql
DECLARE @RetryCount INT = 0
DECLARE @MaxRetries INT = 3

RETRY_TRANSACTION:
BEGIN TRY
    BEGIN TRANSACTION
        -- operaciones...
    COMMIT
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 1205 AND @RetryCount < @MaxRetries BEGIN
        SET @RetryCount = @RetryCount + 1
        PRINT 'Deadlock detected. Retry ' + CAST(@RetryCount AS VARCHAR)
        WAITFOR DELAY '00:00:00.100'  -- Esperar 100ms
        GOTO RETRY_TRANSACTION
    END
    -- Error handling...
END CATCH
```

### Solución 3: Lock Granularity

```sql
-- Usar ROWLOCK para locks más específicos
UPDATE [crm].[Transactions] WITH (ROWLOCK)
SET ...
WHERE transactionId = @Id
```

---

## 🧪 Cómo Ejecutar la Demo

### Prerrequisitos

1. Base de datos PromptCRM con tablas necesarias
2. Datos en SubscriberWallets, Transactions, LeadConversions
3. SSMS con 2 ventanas de Query

### Demo UNSAFE (Demuestra deadlock)

**Verificar datos primero:**
```sql
SELECT TOP 1 subscriberId FROM [crm].[Subscribers]
SELECT TOP 1 leadId FROM [crm].[LeadConversions]
```

**Ventana 1 (Payment):**
```sql
-- Ejecutar primero
EXEC [crm].[DeadlockSP_ProcessSubscriptionPayment_UNSAFE]
    @SubscriberId = 1,
    @Amount = 100.00,
    @DelaySeconds = 3
```

**Ventana 2 (Conversion) - Ejecutar inmediatamente después:**
```sql
-- Ejecutar < 1 segundo después
EXEC [crm].[DeadlockSP_ProcessLeadConversion_UNSAFE]
    @LeadId = 12020416,
    @SubscriberId = 1,
    @ConversionValue = 50.00,
    @DelaySeconds = 3
```

**Resultado Esperado:**
- Una de las sesiones será la "deadlock victim"
- Recibirá error 1205: "Transaction was deadlocked"
- La otra sesión completará exitosamente
- ⚠️ **DEADLOCK OCURRIÓ**

### Demo SAFE (Previene deadlock)

**Ventana 1 (Payment):**
```sql
-- Ejecutar primero
EXEC [crm].[DeadlockSP_ProcessSubscriptionPayment_SAFE]
    @SubscriberId = 1,
    @Amount = 100.00,
    @DelaySeconds = 3
```

**Ventana 2 (Conversion) - Ejecutar inmediatamente después:**
```sql
-- Ejecutar < 1 segundo después
EXEC [crm].[DeadlockSP_ProcessLeadConversion_SAFE]
    @LeadId = 12020416,
    @SubscriberId = 1,
    @ConversionValue = 50.00,
    @DelaySeconds = 3
```

**Resultado Esperado:**
- SESSION 2 esperará a que SESSION 1 termine
- Ambas sesiones completarán exitosamente
- No habrá error 1205
- ✅ **NO HAY DEADLOCK**

---

## 📊 Comparación Visual

| Aspecto | UNSAFE | SAFE |
|---------|--------|------|
| Orden de locks | Inconsistente | Consistente (Txns → Wallets → Conversions) |
| Lock hints | UPDLOCK sin orden | ROWLOCK + orden definido |
| Retry logic | ❌ No | ✅ Sí (3 intentos) |
| Deadlock risk | ⚠️ Alto | ✅ Muy bajo |
| Deadlock victim | ⚠️ Puede ocurrir | ⚠️ Raro (solo si hay conflicto externo) |
| Documentación | Sin reglas | Orden documentado |

---

## 💡 Best Practices para Prevenir Deadlocks

### ✅ DO

1. **Definir y documentar orden de acceso a tablas:**
   ```
   ORDEN OFICIAL:
   1. Transactions
   2. SubscriberWallets
   3. LeadConversions
   4. Subscribers
   ```

2. **Usar lock hints específicos:**
   ```sql
   SELECT ... WITH (ROWLOCK)  -- Lock específico
   SELECT ... WITH (UPDLOCK)  -- Para UPDATE posterior
   ```

3. **Mantener transacciones CORTAS:**
   ```sql
   -- Preparar datos ANTES de BEGIN TRANSACTION
   DECLARE @Datos ...
   SELECT @Datos = ...

   BEGIN TRANSACTION
       -- Solo operaciones críticas
       UPDATE ...
   COMMIT  -- Rápido
   ```

4. **Implementar retry logic:**
   ```sql
   IF ERROR_NUMBER() = 1205 BEGIN
       -- Retry hasta 3 veces
       GOTO RETRY_TRANSACTION
   END
   ```

5. **Usar índices apropiados:**
   - Locks más específicos = menos conflictos
   - Índices en claves de búsqueda

6. **Monitorear deadlocks:**
   ```sql
   -- Activar trace flag para logging
   DBCC TRACEON(1222, -1)
   ```

### ❌ DON'T

1. ❌ Acceder a tablas en orden diferente según el procedure
2. ❌ Hacer operaciones largas dentro de transacciones
3. ❌ Usar locks innecesariamente restrictivos (TABLOCKX)
4. ❌ Ignorar errores 1205 (deadlock)
5. ❌ Usar SERIALIZABLE sin necesidad
6. ❌ Tener transacciones interactivas (esperan input)

---

## 🔍 Diagnóstico de Deadlocks

### Ver deadlocks recientes:

```sql
-- Revisar el error log de SQL Server
EXEC sp_readerrorlog 0, 1, N'deadlock'
```

### Monitorear locks activos:

```sql
SELECT
    l.request_session_id AS SessionId,
    l.resource_type,
    l.request_mode AS LockMode,
    l.request_status,
    t.name AS TableName,
    s.login_name,
    s.program_name
FROM sys.dm_tran_locks l
LEFT JOIN sys.tables t ON l.resource_associated_entity_id = t.object_id
LEFT JOIN sys.dm_exec_sessions s ON l.request_session_id = s.session_id
WHERE l.resource_database_id = DB_ID('PromptCRM')
    AND l.request_session_id > 50
ORDER BY l.request_session_id, t.name
```

### Ver cadena de bloqueos:

```sql
SELECT
    blocking.session_id AS BlockingSession,
    blocked.session_id AS BlockedSession,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS WaitTimeSeconds,
    blocking_sql.text AS BlockingSQL,
    blocked_sql.text AS BlockedSQL
FROM sys.dm_exec_requests blocked
INNER JOIN sys.dm_exec_requests blocking
    ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocking.sql_handle) AS blocking_sql
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) AS blocked_sql
WHERE blocked.blocking_session_id <> 0
```

---

## 🎓 Entendiendo el Deadlock Graph

Cuando ocurre un deadlock, SQL Server genera un "deadlock graph":

```xml
<deadlock>
  <victim-list>
    <victimProcess id="process123"/>  <!-- Session que fue matada -->
  </victim-list>
  <process-list>
    <process id="process123" ...>
      <executionStack>
        <frame procname="DeadlockSP_ProcessPayment_UNSAFE"/>
      </executionStack>
    </process>
    <process id="process456" ...>
      <executionStack>
        <frame procname="DeadlockSP_ProcessLeadConversion_UNSAFE"/>
      </executionStack>
    </process>
  </process-list>
  <resource-list>
    <keylock hobtid="..." dbid="..." ... />
  </resource-list>
</deadlock>
```

---

## 📚 Referencias

- [Deadlock Detection and Analysis](https://docs.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide)
- [Locking Hints](https://docs.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)
- [Transaction Locking Guide](https://docs.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)

---

## ✅ Checklist de Validación

- [ ] Tablas con datos suficientes
- [ ] Procedures UNSAFE creados
- [ ] Procedures SAFE creados
- [ ] Demo UNSAFE causa deadlock (error 1205)
- [ ] Demo SAFE previene deadlock
- [ ] Retry logic funciona
- [ ] Orden de locks documentado
- [ ] Equipo conoce el orden oficial

---

## 🎯 Reglas de Oro del Proyecto

### Orden Oficial de Acceso a Tablas

```
TODOS los stored procedures DEBEN respetar este orden:

1. Transactions         (SIEMPRE PRIMERO)
2. SubscriberWallets    (SIEMPRE SEGUNDO)
3. LeadConversions      (SIEMPRE TERCERO)
4. Subscribers          (SIEMPRE CUARTO)

⚠️ NUNCA acceder en orden diferente
⚠️ Documentar excepciones con justificación
✅ Revisar en code reviews
```

---

**🎓 Entregable para:** Bases de Datos I - TEC
**👥 Desarrollado por:** Alberto Bofi con asistencia de Claude Code

---

_"El mejor deadlock es el que nunca ocurre - usa orden consistente."_
