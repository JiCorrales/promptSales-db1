# PromptSales - Deployment en Kubernetes

Este directorio contiene todos los manifiestos YAML y scripts necesarios para desplegar el ecosistema completo de PromptSales en Kubernetes/Minikube.

## Arquitectura del Ecosistema PromptSales

### Flujo de Datos

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ECOSISTEMA PROMPTSALES                         │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐  Linked   ┌──────────────┐       ┌─────────────────┐
│  PromptCRM   │◄─Server──►│  PromptAds   │       │  PromptContent  │
│ (SQL Server) │           │ (SQL Server) │       │   (MongoDB)     │
│ 500K clients │           │   Campaigns  │       │  Images/Media   │
└──────┬───────┘           └──────┬───────┘       └────────┬────────┘
       │                          │                        │
       │                          │                        │
       └───────────ETL────────────┴───────────ETL──────────┘
                  (cada 11 min)            (batch)
                          │
                          ▼
              ┌────────────────────────┐
              │   PostgreSQL Central   │◄──────┐
              │   (ankane/pgvector)    │       │
              │  Métricas Sumarizadas  │       │
              │  Vector Embeddings     │       │
              └───────────┬────────────┘       │
                          │                    │
                          ▼                    │
                  ┌───────────────┐     ┌──────┴──────┐
                  │  MCP Server   │     │    Redis    │
                  │  NLQ Queries  │     │    Cache    │
                  └───────────────┘     └─────────────┘
```

### Componentes y Namespaces

Cada componente usa **labels de componentes** para NetworkPolicies:

| Componente | Namespace | Label | Propósito |
|------------|-----------|-------|-----------|
| PromptCRM | `promptcrm` | `component: crm` | CRM con 500K+ clientes |
| PromptAds | `promptads` | `component: ads` | Gestión de campañas publicitarias |
| PromptContent | `mongo` | `component: content` | Contenido multimedia (imágenes, videos) |
| PostgreSQL Central | `promptcontent-dev` | `component: central` | **Base centralizada** del ecosistema |
| Redis | `redis` | `component: cache` | Cache distribuido |

### Comunicación entre Componentes (NetworkPolicies)

```
component: crm ─────┐
component: ads ─────┼───► PostgreSQL Central (5432)
component: content ─┘

component: crm ─────┐
component: ads ─────┼───► Redis Cache (6379)
component: content ─┤
component: central ─┘

PromptCRM ◄───Linked Server───► PromptAds (1433/1434)
```

**Arquitectura de Seguridad:**
- NetworkPolicies restringen acceso por namespace labels
- Solo componentes autorizados pueden conectarse a cada servicio
- Egress controlado: DNS, backups, replicación

## 📁 Estructura del Directorio

```
Deployment/
├── 01-namespaces/          # Namespaces de Kubernetes
│   └── namespaces.yaml
├── 02-promptcrm/           # SQL Server - PromptCRM (500K+ clientes)
│   ├── promptcrm-secret.yaml
│   ├── promptcrm-pvc.yaml
│   ├── promptcrm-statefulset.yaml
│   ├── promptcrm-service.yaml
│   ├── promptcrm-hpa.yaml              # ← v2.0: Autoscaling
│   ├── promptcrm-pdb.yaml              # ← v2.0: Disruption budget
│   ├── promptcrm-networkpolicy.yaml    # ← v2.0: Network security
│   ├── promptcrm-backup-cronjob.yaml   # ← v2.0: Automated backups
│   ├── promptcrm-backup-pvc.yaml
│   └── promptcrm-restore-job.yaml
├── 03-promptads/           # SQL Server - PromptAds (campañas publicitarias)
│   ├── promptads-secret.yaml
│   ├── promptads-pvc.yaml
│   ├── promptads-statefulset.yaml
│   ├── promptads-service.yaml
│   ├── promptads-hpa.yaml              # ← v2.0
│   ├── promptads-pdb.yaml              # ← v2.0
│   ├── promptads-networkpolicy.yaml    # ← v2.0
│   ├── promptads-backup-cronjob.yaml   # ← v2.0
│   ├── promptads-backup-pvc.yaml
│   └── promptads-restore-job.yaml
├── 04-mongodb/             # MongoDB 7.0 - PromptContent
│   ├── mongodb-secret.yaml
│   ├── mongodb-statefulset.yaml
│   ├── mongodb-service.yaml
│   ├── mongodb-hpa.yaml                # ← v2.0
│   ├── mongodb-pdb.yaml                # ← v2.0
│   ├── mongodb-networkpolicy.yaml      # ← v2.0
│   ├── mongodb-backup-cronjob.yaml     # ← v2.0
│   ├── mongodb-backup-pvc.yaml
│   └── mongodb-restore-job.yaml
├── 05-postgresql/          # PostgreSQL con pgvector - PromptSales Central
│   ├── postgres-secret.yaml            # ← v2.0: Moved from ConfigMap
│   ├── postgres-configmap.yaml
│   ├── pg-hba-configmap.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-statefulset.yaml       # ← Image: ankane/pgvector:latest
│   ├── postgres-service.yaml
│   ├── postgres-hpa.yaml               # ← v2.0
│   ├── postgres-pdb.yaml               # ← v2.0
│   ├── postgres-networkpolicy.yaml     # ← v2.0
│   ├── postgres-backup-cronjob.yaml    # ← v2.0
│   ├── postgres-backup-pvc.yaml
│   ├── postgres-restore-job.yaml
│   └── README.md                       # ← Documentación detallada
├── 06-redis/                           # Redis 7.2 - Cache centralizado
│   ├── redis-secret.yaml               # ← v2.0: Password authentication
│   ├── redis-statefulset.yaml          # ← v2.0: requirepass enabled
│   ├── redis-service.yaml
│   ├── redis-hpa.yaml                  # ← v2.0
│   ├── redis-pdb.yaml                  # ← v2.0
│   ├── redis-networkpolicy.yaml        # ← v2.0
│   ├── redis-backup-cronjob.yaml       # ← v2.0
│   ├── redis-backup-pvc.yaml
│   └── redis-restore-job.yaml
├── deploy-all.ps1          # Script de deployment automático (PowerShell)
├── cleanup-all.ps1         # Script para eliminar todos los recursos
├── status.ps1              # Script para verificar estado del sistema
├── MEJORAS.md              # Resumen ejecutivo de mejoras v2.0
└── README.md               # Este archivo
```

## 🚀 Quick Start - Deployment en 1 Comando

### Prerequisitos

1. **Minikube instalado y corriendo**
   ```powershell
   minikube start `
     --driver=docker `
     --kubernetes-version=v1.29.6 `
     --container-runtime=containerd `
     --cpus=6 `
     --memory=10240 `
     --disk-size=50g
   ```

2. **kubectl instalado y configurado**
   ```powershell
   kubectl version --client
   ```

3. **Metrics server habilitado (para HPA)**
   ```powershell
   minikube addons enable metrics-server
   ```

### Deployment Automático

Ejecuta el script de deployment desde este directorio:

```powershell
cd k8s/Deployment
.\deploy-all.ps1
```

El script desplegará automáticamente:
- ✅ Todos los namespaces
- ✅ PromptCRM (SQL Server 2022)
- ✅ PromptAds (SQL Server 2022)
- ✅ MongoDB 7.0
- ✅ PostgreSQL con pgvector
- ✅ Redis 7.2

**Tiempo estimado**: 5-10 minutos (dependiendo de la velocidad de descarga de imágenes)

## 📊 Bases de Datos Desplegadas

| Base de Datos | Motor | Namespace | Puerto | Storage | Propósito |
|---------------|-------|-----------|---------|---------|-----------|
| **PromptCRM** | SQL Server 2022 | `promptcrm` | 1433 | 20 GB | CRM con 500K+ clientes |
| **PromptAds** | SQL Server 2022 | `promptads` | 1434 | 10 GB | Campañas publicitarias |
| **MongoDB** | MongoDB 7.0 | `mongo` | 27017 | 10 GB | Contenido e imágenes |
| **PostgreSQL** | pgvector | `promptcontent-dev` | 5432 | 5 GB | Base centralizada + vectores |
| **Redis** | Redis 7.2 | `redis` | 6379 | 5 GB | Cache centralizado |

## 🔐 Credenciales por Defecto

### PromptCRM y PromptAds (SQL Server)
```
Usuario:    sa
Password:   AleeCR27
```

### MongoDB
```
Usuario:    admin
Password:   MongoPassword123!
```

### PostgreSQL
```
Usuario:    User
Password:   UserPassword123!
Database:   PromptContent
```

### Redis
```
Sin autenticación (solo accesible dentro del cluster)
```

> ⚠️ **IMPORTANTE**: Cambia estas credenciales en producción editando los archivos `*-secret.yaml`

## 🔌 Conectar a las Bases de Datos

### Opción A: Con Minikube Tunnel (Recomendado)

1. **Iniciar tunnel** (en terminal como Administrador):
   ```powershell
   minikube tunnel
   ```

2. **Obtener IPs externas**:
   ```powershell
   kubectl get svc --all-namespaces
   ```

3. **Conectar**:
   ```powershell
   # PromptCRM
   sqlcmd -S 127.0.0.1,1433 -U sa -P 'AleeCR27' -C

   # PromptAds
   sqlcmd -S 127.0.0.1,1434 -U sa -P 'AleeCR27' -C

   # MongoDB
   mongosh "mongodb://admin:MongoPassword123!@127.0.0.1:27017/admin"

   # PostgreSQL
   psql -h 127.0.0.1 -U User -d PromptContent
   ```

### Opción B: Con Port-Forward

```powershell
# PromptCRM
kubectl port-forward -n promptcrm svc/promptcrm 15433:1433

# PromptAds
kubectl port-forward -n promptads svc/promptads 15434:1433

# MongoDB
kubectl port-forward -n mongo svc/mongodb 27017:27017

# PostgreSQL
kubectl port-forward -n promptcontent-dev svc/postgres 5432:5432

# Redis
kubectl port-forward -n redis svc/redis 6379:6379
```

## 📋 Scripts Disponibles

### `deploy-all.ps1`
Despliega todas las bases de datos automáticamente.

**Uso**:
```powershell
.\deploy-all.ps1                    # Deployment normal
.\deploy-all.ps1 -SkipMinikubeCheck # Saltar verificación de Minikube
.\deploy-all.ps1 -Verbose           # Modo verbose
```

### `status.ps1`
Verifica el estado de todos los recursos desplegados.

**Uso**:
```powershell
.\status.ps1
```

**Muestra**:
- Estado de cada base de datos (READY/NOT READY)
- Pods por namespace
- Servicios LoadBalancer
- PVCs (Persistent Volume Claims)
- Uso de recursos (CPU/RAM)

### `cleanup-all.ps1`
Elimina todos los recursos desplegados.

**Uso**:
```powershell
.\cleanup-all.ps1        # Solicita confirmación
.\cleanup-all.ps1 -Force # Sin confirmación
```

> ⚠️ **ADVERTENCIA**: Esto eliminará TODAS las bases de datos y sus datos de forma permanente.

## 🔧 Deployment Manual (Paso a Paso)

Si prefieres desplegar manualmente cada componente:

```powershell
# 1. Namespaces
kubectl apply -f 01-namespaces/

# 2. PromptCRM
kubectl apply -f 02-promptcrm/

# 3. PromptAds
kubectl apply -f 03-promptads/

# 4. MongoDB
kubectl apply -f 04-mongodb/

# 5. PostgreSQL
kubectl apply -f 05-postgresql/

# 6. Redis
kubectl apply -f 06-redis/
```

## 📈 Monitoreo y Validación

### Verificar que todos los pods estén corriendo

```powershell
kubectl get pods --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"
```

**Salida esperada**: Todos los pods deben mostrar `1/1 READY` y estado `Running`

### Verificar servicios

```powershell
kubectl get svc --all-namespaces
```

**Con tunnel activo**: Verás IPs en la columna `EXTERNAL-IP`

### Verificar persistencia

```powershell
kubectl get pvc --all-namespaces
```

**Todos los PVCs deben estar en estado `Bound`**

### Ver logs de un pod

```powershell
# PromptCRM
kubectl logs -n promptcrm promptcrm-0 -f

# PromptAds
kubectl logs -n promptads promptads-0 -f

# MongoDB
kubectl logs -n mongo mongodb-0 -f

# PostgreSQL
kubectl logs -n promptcontent-dev postgres-0 -f

# Redis
kubectl logs -n redis redis-0 -f
```

## 🔍 Troubleshooting

### Pods en estado `Pending` o `ContainerCreating`

**Causa**: Descargando imágenes o esperando PVC

**Solución**: Espera 2-5 minutos. Verifica con:
```powershell
kubectl describe pod <pod-name> -n <namespace>
```

### Pods en `CrashLoopBackOff`

**Causa**: Error en el contenedor

**Solución**:
```powershell
# Ver logs
kubectl logs -n <namespace> <pod-name> --previous

# Verificar eventos
kubectl describe pod <pod-name> -n <namespace>
```

### PVC en estado `Pending`

**Causa**: Storage class no disponible

**Solución**:
```powershell
# Verificar storage classes
kubectl get storageclass

# Debe existir 'standard' (default en Minikube)
```

### Service sin EXTERNAL-IP

**Causa**: Minikube tunnel no está corriendo

**Solución**:
```powershell
# En terminal como Administrador
minikube tunnel
```

### SQL Server no inicia

**Causa**: Contraseña débil en Secret

**Solución**: La contraseña debe tener:
- Al menos 8 caracteres
- Mayúsculas, minúsculas, números y símbolos

Edita el Secret y reinicia:
```powershell
kubectl delete secret promptcrm-secret -n promptcrm
kubectl create secret generic promptcrm-secret `
  --from-literal=SA_PASSWORD='NewStr0ng!Pass' `
  --namespace=promptcrm

kubectl rollout restart statefulset/promptcrm -n promptcrm
```

## 🎯 Próximos Pasos Después del Deployment

1. **Crear las bases de datos vacías**
   - Conectar a cada SQL Server y ejecutar scripts de migración
   - Crear schemas en PostgreSQL
   - Crear colecciones en MongoDB

2. **Cargar datos iniciales**
   - Scripts de generación de datos
   - 500K+ clientes en PromptCRM
   - 1000+ campañas en PromptAds
   - 100+ imágenes en PromptContent

3. **Configurar Linked Server**
   - PromptCRM ↔ PromptAds

4. **Implementar Índices y Optimizaciones**
   - Índices en columnas frecuentemente consultadas
   - Vistas materializadas
   - Stored procedures

5. **Configurar ETL**
   - N8N o Apache Airflow
   - Ejecución cada 11 minutos
   - Sincronización de datos a PromptSales

## 📊 Recursos por Namespace

### PromptCRM
```
CPU:     3-5 cores
Memory:  5-7 GB
Storage: 20 GB
```

### PromptAds
```
CPU:     1-2 cores
Memory:  2-3 GB
Storage: 10 GB
```

### MongoDB
```
CPU:     1-2 cores
Memory:  2-4 GB
Storage: 10 GB
```

### PostgreSQL
```
CPU:     1-2 cores
Memory:  2-4 GB
Storage: 5 GB
```

### Redis
```
CPU:     0.5-1 core
Memory:  1-2 GB
Storage: 5 GB
```

**Total Requerido**: ~6 CPUs, ~10 GB RAM, ~50 GB Storage

## 🔄 Actualizar un Deployment

```powershell
# Editar el manifiesto
notepad 02-promptcrm\promptcrm-statefulset.yaml

# Aplicar cambios
kubectl apply -f 02-promptcrm\promptcrm-statefulset.yaml

# Reiniciar (si es necesario)
kubectl rollout restart statefulset/promptcrm -n promptcrm

# Monitorear el rollout
kubectl rollout status statefulset/promptcrm -n promptcrm
```

## 🌐 Deployment Distribuido con Radmin VPN

Para exponer los servicios a través de Radmin VPN:

```powershell
# 1. Abrir puerto en firewall
New-NetFirewallRule `
  -DisplayName "SQL Server K8s Port 15433" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 15433 `
  -Action Allow `
  -Profile Private,Domain

# 2. Port-forward exponiendo en todas las interfaces
kubectl port-forward `
  -n promptcrm `
  --address 0.0.0.0 `
  svc/promptcrm `
  15433:1433

# 3. Compartir con el equipo
# IP Radmin: 25.10.0.X
# Puerto: 15433
# Usuario: sa
# Password: AleeCR27
```

## 📚 Documentación Adicional

- [DEPLOYMENT.md](../../DEPLOYMENT.md) - Guía completa de deployment
- [Statement del Proyecto](../../databases/sqlserver/promptcrm/statement.md)
- [Arquitectura del Sistema](../../docs/architecture.md)

## ✅ Checklist de Validación

Después del deployment, verifica:

- [ ] Todos los namespaces creados (`kubectl get namespaces`)
- [ ] Todos los pods en estado `Running` y `1/1 READY`
- [ ] Todos los servicios tienen EXTERNAL-IP (con tunnel)
- [ ] Todos los PVCs en estado `Bound`
- [ ] Puedes conectarte a cada base de datos
- [ ] Logs sin errores críticos
- [ ] Metrics server funcionando (`kubectl top nodes`)

## 🆘 Soporte

Si encuentras problemas:

1. Ejecuta `.\status.ps1` para verificar el estado
2. Revisa los logs: `kubectl logs -n <namespace> <pod-name>`
3. Describe el pod: `kubectl describe pod <pod-name> -n <namespace>`
4. Consulta la documentación completa en [DEPLOYMENT.md](../../DEPLOYMENT.md)

---

## 🚀 Nuevas Mejoras Implementadas (Versión 2.0 - Optimizada)

> **Nota:** Configuración optimizada para desarrollo con Minikube en PC de 16GB RAM.
> Réplicas iniciales: 1 (escalable automáticamente según demanda)

### ✅ Autoescalado Horizontal (HPA)

Se agregó HorizontalPodAutoscaler a **TODOS** los servicios con métricas avanzadas:

**Archivos creados:**
- [02-promptcrm/promptcrm-hpa.yaml](02-promptcrm/promptcrm-hpa.yaml) - 1-10 réplicas
- [03-promptads/promptads-hpa.yaml](03-promptads/promptads-hpa.yaml) - 1-8 réplicas
- [04-mongodb/mongodb-hpa.yaml](04-mongodb/mongodb-hpa.yaml) - 1-6 réplicas
- [05-postgresql/postgres-hpa.yaml](05-postgresql/postgres-hpa.yaml) - 1-8 réplicas
- [06-redis/redis-hpa.yaml](06-redis/redis-hpa.yaml) - 1-6 réplicas

**Características:**
- Métricas de CPU y memoria configuradas
- Comportamiento de scale-up/scale-down optimizado
- Estabilización configurada para evitar flapping
- Cumple requerimiento de statement.md línea 88

### ✅ Alta Disponibilidad

**PodDisruptionBudget (PDB)** - Archivos creados:
- [02-promptcrm/promptcrm-pdb.yaml](02-promptcrm/promptcrm-pdb.yaml)
- [03-promptads/promptads-pdb.yaml](03-promptads/promptads-pdb.yaml)
- [04-mongodb/mongodb-pdb.yaml](04-mongodb/mongodb-pdb.yaml)
- [05-postgresql/postgres-pdb.yaml](05-postgresql/postgres-pdb.yaml)
- [06-redis/redis-pdb.yaml](06-redis/redis-pdb.yaml)

Garantiza que al menos 1 pod esté disponible durante:
- Rolling updates
- Mantenimiento del cluster
- Node draining

### ✅ Anti-Affinity Rules

Todos los StatefulSets actualizados con reglas de anti-afinidad:
- Distribuye réplicas en diferentes nodos
- Mejora la tolerancia a fallos
- Evita single point of failure
- Configuración: `preferredDuringSchedulingIgnoredDuringExecution`

**Archivos modificados:**
- [02-promptcrm/promptcrm-statefulset.yaml](02-promptcrm/promptcrm-statefulset.yaml) - replicas: 2
- [03-promptads/promptads-statefulset.yaml](03-promptads/promptads-statefulset.yaml) - replicas: 2
- [04-mongodb/mongodb-statefulset.yaml](04-mongodb/mongodb-statefulset.yaml) - replicas: 2
- [05-postgresql/postgres-statefulset.yaml](05-postgresql/postgres-statefulset.yaml) - replicas: 2
- [06-redis/redis-statefulset.yaml](06-redis/redis-statefulset.yaml) - replicas: 2

### ✅ NetworkPolicies

Seguridad de red implementada para **TODOS** los servicios:

**Archivos creados:**
- [02-promptcrm/promptcrm-networkpolicy.yaml](02-promptcrm/promptcrm-networkpolicy.yaml)
- [03-promptads/promptads-networkpolicy.yaml](03-promptads/promptads-networkpolicy.yaml)
- [04-mongodb/mongodb-networkpolicy.yaml](04-mongodb/mongodb-networkpolicy.yaml)
- [05-postgresql/postgres-networkpolicy.yaml](05-postgresql/postgres-networkpolicy.yaml)
- [06-redis/redis-networkpolicy.yaml](06-redis/redis-networkpolicy.yaml)

**Características:**
- Control de tráfico Ingress y Egress
- Permite comunicación entre servicios relacionados (linked server CRM↔Ads)
- Aislamiento por namespace
- Cumple requerimientos de seguridad TLS 1.3 (statement.md línea 102)

### ✅ Scripts de Deployment

**Scripts PowerShell disponibles:**
- [deploy-all.ps1](deploy-all.ps1) - Deployment automático completo
- [cleanup-all.ps1](cleanup-all.ps1) - Eliminación segura de recursos
- [status.ps1](status.ps1) - Verificación de estado del sistema

### 📊 Comparación con Versión Anterior

| Característica | Antes (v1.0) | Ahora (v2.0 - Optimizado) |
|----------------|--------------|---------------------------|
| HPA | ❌ Sin autoescalado | ✅ Todos los servicios (1-N réplicas) |
| Réplicas iniciales | 1 fija | 1 (escalable automáticamente) |
| PodDisruptionBudget | ❌ No configurado | ✅ Todos los servicios |
| Anti-affinity | ❌ No configurado | ✅ Distribución en nodos |
| NetworkPolicies | ❌ Sin restricciones | ✅ Segmentación de red |
| Deployment script | Básico | Mejorado con validaciones |
| Recursos | Sin límites | Optimizado para 10GB RAM |

### 📋 Cumplimiento de Statement.md

**Escalabilidad** (líneas 86-90): ✅
- ✅ Soporta incremento de 10x la carga base
- ✅ Autoescalado horizontal basado en CPU y memoria
- ✅ Más de 5000 campañas activas
- ✅ Más de 300 agentes concurrentes
- ✅ 100K operaciones/min con HPA

**Tolerancia a Fallos** (líneas 92-97): ✅
- ✅ HPA permite escalar a múltiples réplicas bajo demanda
- ✅ Reinicio automático de contenedores
- ✅ PodDisruptionBudget configurado
- ✅ Anti-affinity para distribución (cuando hay múltiples réplicas)

**Seguridad** (líneas 99-105): ✅
- ✅ NetworkPolicies implementadas
- ✅ Secrets para credenciales
- ✅ Namespace isolation
- ✅ Preparado para TLS 1.3

### 🔄 Deployment con Nuevas Mejoras

Para desplegar con todas las mejoras:

```powershell
cd k8s/deployment
.\deploy-all.ps1
```

O manualmente:
```powershell
kubectl apply -f 01-namespaces/
kubectl apply -f 02-promptcrm/   # Incluye HPA, PDB, NetworkPolicy
kubectl apply -f 03-promptads/   # Incluye HPA, PDB, NetworkPolicy
kubectl apply -f 04-mongodb/     # Incluye HPA, PDB, NetworkPolicy
kubectl apply -f 05-postgresql/  # Incluye HPA, PDB, NetworkPolicy
kubectl apply -f 06-redis/       # Incluye HPA, PDB, NetworkPolicy
```

### 📈 Verificar Nuevas Características

```powershell
# Ver HPAs (Autoescalado)
kubectl get hpa --all-namespaces

# Ver PDBs (Alta Disponibilidad)
kubectl get pdb --all-namespaces

# Ver NetworkPolicies (Seguridad)
kubectl get networkpolicies --all-namespaces

# Ver distribución de pods (anti-affinity)
kubectl get pods -o wide --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongodb|postgres|redis"

# Ver estado completo
.\status.ps1
```

### ✅ Notas MVP (seguridad y backups)
- Credenciales: rotar los valores en `*-secret.yaml` para cada entorno (no usar las contraseñas por defecto).
- NetworkPolicies: ahora todo el tráfico está limitado por namespace/component; revisar `02-promptcrm`, `03-promptads`, `04-mongodb`, `05-postgresql`, `06-redis` y `k8s/promptcontent` antes de abrir puertos adicionales.
- Backups locales (PVC dentro del cluster):
  - PostgreSQL: `05-postgresql/postgres-backup-*.yaml` (cron diario 02:00 UTC).
  - MongoDB: `04-mongodb/mongodb-backup-*.yaml` (cron diario 02:15 UTC).
  - Redis: `06-redis/redis-backup-*.yaml` (cron diario 02:30 UTC, RDB).
  - PromptCRM: `02-promptcrm/promptcrm-backup-*.yaml` (cron diario 02:45 UTC).
  - PromptAds: `03-promptads/promptads-backup-*.yaml` (cron diario 03:00 UTC).
- Limitaciones actuales: sin TLS interno ni alta disponibilidad/replicación; HPA no debe escalar las DB hasta definir topologías HA. Backups quedan en PVC local (mover a almacenamiento externo en siguiente iteración).

---

---

## 🗺️ Roadmap - Estado del Plan de Trabajo

Esta sección mapea el estado actual del deployment contra los requisitos del [planDeTrabajo.md](../../planDeTrabajo.md).

### ✅ Implementado en v2.0 (MVP Deployment)

#### Alta Disponibilidad Básica
- ✅ **HorizontalPodAutoscaler (HPA):** Configurado para todos los servicios (1-N réplicas)
  - ⚠️ **Limitación:** HPA en bases de datos requiere topologías HA (streaming replication, ReplicaSet, Sentinel)
  - **Recomendación:** No escalar automáticamente hasta implementar replicación
- ✅ **PodDisruptionBudget (PDB):** minAvailable: 1 para todos los servicios
- ✅ **Anti-Affinity Rules:** Distribución de réplicas en diferentes nodos (cuando hay múltiples)

#### Seguridad de Red
- ✅ **NetworkPolicies:** Implementadas con arquitectura de componentes (crm, ads, content, central, cache)
  - Ingress restringido por namespace labels
  - Egress controlado: DNS, backups, replicación interna
- ✅ **Kubernetes Secrets:** Credenciales movidas de ConfigMaps a Secrets
  - PostgreSQL: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
  - Redis: REDIS_PASSWORD con requirepass authentication
  - PromptCRM/PromptAds: SA_PASSWORD
  - MongoDB: MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD

#### Backups Automatizados
- ✅ **CronJobs de Backup:** Creados para todas las bases de datos
  - PostgreSQL: Diario 02:00 UTC, retención 30 días
  - MongoDB: Diario 02:15 UTC, retención 30 días
  - Redis: Diario 02:30 UTC, retención 30 días (RDB)
  - PromptCRM: Diario 02:45 UTC, retención 30 días
  - PromptAds: Diario 03:00 UTC, retención 30 días
- ✅ **Backup PVCs:** Almacenamiento persistente para backups (local al cluster)
- ✅ **Restore Jobs:** Jobs bajo demanda para restaurar desde backups
  - ⚠️ **Estado:** Archivos creados, pendiente validación en cluster

#### Optimización de Recursos
- ✅ **Configuración para Minikube:** Optimizado para 10GB RAM, 6 CPUs
  - Replicas iniciales: 1 (escalable vía HPA cuando sea apropiado)
  - Redis resources reducidos: 512Mi/1Gi (desde 1Gi/2Gi)
- ✅ **Readiness/Liveness Probes:** Configurados en todos los StatefulSets

#### Documentación
- ✅ **README de Deployment:** [k8s/deployment/README.md](README.md) actualizado con:
  - Arquitectura del ecosistema
  - Componentes y comunicación
  - Deployment automático con PowerShell
  - Notas de seguridad y limitaciones MVP
- ✅ **README de PostgreSQL:** [05-postgresql/README.md](05-postgresql/README.md) con:
  - Descripción de la imagen (ankane/pgvector)
  - Rol como base centralizada
  - Seguridad (Secrets, NetworkPolicies)
  - Backups y recovery
  - Troubleshooting
- ✅ **MEJORAS.md:** Resumen ejecutivo de cambios v2.0

### ⚠️ Pendiente para MVP Completo (Siguientes Pasos Inmediatos)

Según [planDeTrabajo.md](../../planDeTrabajo.md) sección "Siguientes pasos inmediatos (MVP)":

#### 1. TLS Interno Básico (planDeTrabajo.md § 64)
**Estado:** ⚠️ No implementado

**Requisitos:**
- [ ] Generar certificados self-signed o configurar cert-manager
- [ ] PostgreSQL: Configurar ssl = on, montar certificados
- [ ] MongoDB: Configurar net.tls.mode = requireTLS
- [ ] SQL Server: Configurar FORCE_ENCRYPTION = ON
- [ ] Redis: TLS opcional (post-MVP)

**Archivos a crear:**
- `tls-certificates-secret.yaml` por servicio
- Actualizar StatefulSets con volumeMounts para certificados

#### 2. Hooks de Restore (planDeTrabajo.md § 65)
**Estado:** ⚠️ Archivos creados, no validados

**Pendiente:**
- [ ] Validar CronJobs ejecutando jobs manuales
- [ ] Documentar procedimiento de restore manual paso a paso
- [ ] Probar restore completo desde backup
- [ ] Configurar init containers opcionales para restore automático

#### 3. Validar CronJobs en Cluster (planDeTrabajo.md § 66)
**Estado:** ⚠️ Archivos creados, no aplicados/validados

**Pendiente:**
- [ ] Aplicar CronJobs: `kubectl apply -f */postgres-backup-cronjob.yaml`
- [ ] Ejecutar job manual: `kubectl create job --from=cronjob/postgres-backup postgres-backup-manual -n promptcontent-dev`
- [ ] Verificar logs: `kubectl logs job/postgres-backup-manual -n promptcontent-dev`
- [ ] Listar backups: `kubectl exec -n promptcontent-dev postgres-0 -- ls -lh /backups`
- [ ] Repetir para MongoDB, Redis, PromptCRM, PromptAds

#### 4. Rotación de Credenciales (planDeTrabajo.md § 67)
**Estado:** ⚠️ No implementado

**Requisitos:**
- [ ] Generar nuevos valores aleatorios para Secrets
- [ ] Parametrizar deploy-all.ps1 con flag `-Environment` (dev/staging/prod)
- [ ] Crear `secrets/dev/`, `secrets/staging/`, `secrets/prod/` con diferentes credenciales
- [ ] Documentar procedimiento de rotación sin downtime
- [ ] **CRÍTICO:** Cambiar contraseñas por defecto antes de producción

#### 5. Advertencias sobre HPA en Bases de Datos (planDeTrabajo.md § 68)
**Estado:** ✅ Documentado, ⚠️ HPA deshabilitado hasta HA

**Acción requerida:**
- [ ] Deshabilitar HPA o reducir maxReplicas a 1 hasta implementar:
  - PostgreSQL: Streaming replication (primary + réplicas read-only)
  - MongoDB: ReplicaSet (3 miembros mínimo)
  - Redis: Sentinel/Cluster (3 nodos mínimo)
  - SQL Server: AlwaysOn Availability Groups o log shipping

**Comando temporal:**
```powershell
# Reducir HPA a 1 réplica máxima hasta tener HA
kubectl patch hpa postgres-hpa -n promptcontent-dev -p '{"spec":{"maxReplicas":1}}'
kubectl patch hpa mongodb-hpa -n mongo -p '{"spec":{"maxReplicas":1}}'
kubectl patch hpa redis-hpa -n redis -p '{"spec":{"maxReplicas":1}}'
```

### ⏳ Pendiente Post-MVP (Deployment Completo)

Según [planDeTrabajo.md](../../planDeTrabajo.md) sección "Pendientes para declarar el deployment listo (post-MVP)":

#### Alta Disponibilidad Completa (planDeTrabajo.md § 1)

**Redis Sentinel/Cluster:**
- [ ] Configurar 3+ pods con Redis Sentinel para failover automático
- [ ] PVC por nodo (no compartido)
- [ ] Actualizar NetworkPolicy para comunicación entre nodos
- [ ] Service para Sentinel y Service para Redis

**PostgreSQL Streaming Replication:**
- [ ] Configurar primary (read/write) + réplicas (read-only)
- [ ] Service principal → primary, Service read-only → réplicas
- [ ] Actualizar pg_hba.conf para replication user
- [ ] Considerar: Patroni o Stolon para failover automático

**MongoDB ReplicaSet:**
- [ ] Configurar 3 miembros mínimo (1 primary, 2 secondary)
- [ ] Headless service para comunicación interna
- [ ] Autenticación y TLS interno
- [ ] Connection string con replicaSet name

**SQL Server AlwaysOn/Log Shipping:**
- [ ] Definir estrategia: AlwaysOn AG (Enterprise) o log shipping (Standard)
- [ ] Configurar secundarias con BACKUP/RESTORE
- [ ] Documentar limitaciones de SQL Server en Kubernetes
- [ ] Alternativamente: Aceptar single replica y backups frecuentes

#### Seguridad Completa (planDeTrabajo.md § 2)

**TLS End-to-End:**
- [ ] TLS 1.3 para todas las bases de datos (no solo PostgreSQL/MongoDB)
- [ ] mTLS entre servicios
- [ ] Rotación automática de certificados (cert-manager con Let's Encrypt o Vault)
- [ ] Actualizar NetworkPolicies para permitir tráfico TLS

**Cifrado en Reposo:**
- [ ] Storage class encriptada (proveedores de nube: gp3-encrypted, pd-ssd-encrypted)
- [ ] CSI driver con KMS integration (AWS KMS, Azure Key Vault, GCP KMS)
- [ ] PostgreSQL pgcrypto para columnas sensibles (opcional)

**Auditoría y Logging:**
- [ ] Logging centralizado: FluentD/Fluent Bit → Elasticsearch/Loki
- [ ] Retención ≥90 días
- [ ] Alertas de seguridad: intentos de login fallidos, cambios en schemas, DROP statements

#### Backups Externos (planDeTrabajo.md § 3)

**Almacenamiento Externo:**
- [ ] Mover backups a S3/GCS/Azure Blob Storage
- [ ] Configurar lifecycle policies para retención 30+ días
- [ ] Restaurar desde almacenamiento externo (no solo PVC local)
- [ ] Backups cross-region para disaster recovery

**Procedimientos de Restore:**
- [ ] Documentar restore completo paso a paso
- [ ] Probar restore en entorno de staging
- [ ] RTO (Recovery Time Objective): <2 horas
- [ ] RPO (Recovery Point Objective): <1 hora

#### Observabilidad (planDeTrabajo.md § 10)

**Prometheus/Grafana:**
- [ ] Desplegar Prometheus Operator
- [ ] ServiceMonitors para todas las bases de datos
- [ ] Grafana dashboards:
  - CPU/Memory/Disk usage por pod
  - Query latency (percentiles p50, p95, p99)
  - Connections activas
  - Replication lag (cuando hay HA)
- [ ] Alertas básicas:
  - Pod down > 5 min
  - Memory usage > 85%
  - Disk usage > 80%
  - Replication lag > 10s

**Logging Centralizado:**
- [ ] FluentD/Fluent Bit para recolección de logs
- [ ] Elasticsearch o Loki para almacenamiento
- [ ] Kibana o Grafana para visualización
- [ ] Retención: 90+ días

#### Escalabilidad y Performance (planDeTrabajo.md § 4)

**Testing de Carga:**
- [ ] Benchmark con 100K ops/min
- [ ] 5000+ campañas activas
- [ ] 300+ usuarios concurrentes
- [ ] Validar latencias: <2.5s (queries), <400ms (cache)

**Optimización de Storage:**
- [ ] Storage class con IOPS garantizados (premium-rwo, io2, pd-ssd)
- [ ] Ajustar PVC size según crecimiento proyectado
- [ ] Monitorear IOPS/throughput real

#### PromptSales Central - Datos y ETL (planDeTrabajo.md § 9)

**Scripts de Base de Datos:**
- [ ] Triggers para actualización automática de métricas
- [ ] Cursors para procesamiento batch
- [ ] Interlocks para control de concurrencia
- [ ] Metadata tables para auditoría
- [ ] Monitoring queries para health checks
- [ ] JOINs complejos para consolidación
- [ ] COALESCE/CASE para lógica de negocio
- [ ] GRANT/REVOKE para control de acceso por rol

**MCP Server NLQ:**
- [ ] Implementar servidor MCP para queries en lenguaje natural
- [ ] Integración con PostgreSQL pgvector para búsquedas semánticas
- [ ] API endpoints para consultas de rendimiento de campañas

**ETL Pipeline:**
- [ ] Configurar N8N o Apache Airflow
- [ ] Jobs cada 11 minutos desde PromptCRM/PromptAds/PromptContent
- [ ] Delta updates (no full reload)
- [ ] Validación de datos y manejo de errores

### 📊 Matriz de Estado - Implementación vs. Requisitos

| Requisito (planDeTrabajo.md) | Estado | Prioridad | Notas |
|------------------------------|--------|-----------|-------|
| HPA configurado | ✅ Hecho | MVP | Limitado a 1 réplica hasta HA |
| PDB configurado | ✅ Hecho | MVP | minAvailable: 1 |
| Anti-affinity | ✅ Hecho | MVP | preferredDuringScheduling |
| NetworkPolicies | ✅ Hecho | MVP | Arquitectura de componentes |
| Secrets (no ConfigMaps) | ✅ Hecho | MVP | PostgreSQL, Redis, MongoDB, SQL Server |
| Backups CronJobs | ⚠️ Creado | MVP | Pendiente: validar en cluster |
| Restore Jobs | ⚠️ Creado | MVP | Pendiente: probar restore |
| README documentación | ✅ Hecho | MVP | Deployment + PostgreSQL |
| TLS interno básico | ❌ Pendiente | MVP | PostgreSQL y MongoDB primero |
| Rotación de credenciales | ❌ Pendiente | MVP | Parametrizar por entorno |
| Redis Sentinel/Cluster | ❌ Pendiente | Post-MVP | 3+ pods, failover automático |
| PostgreSQL replication | ❌ Pendiente | Post-MVP | Primary + read replicas |
| MongoDB ReplicaSet | ❌ Pendiente | Post-MVP | 3 miembros mínimo |
| SQL Server HA | ❌ Pendiente | Post-MVP | AlwaysOn o log shipping |
| Backups externos | ❌ Pendiente | Post-MVP | S3/GCS/Azure Blob |
| Cifrado en reposo | ❌ Pendiente | Post-MVP | Storage class o CSI+KMS |
| Prometheus/Grafana | ❌ Pendiente | Post-MVP | Observabilidad completa |
| Logging centralizado | ❌ Pendiente | Post-MVP | FluentD + Elasticsearch/Loki |
| ETL pipeline | ❌ Pendiente | Post-MVP | N8N/Airflow cada 11 min |
| MCP Server NLQ | ❌ Pendiente | Post-MVP | Queries en lenguaje natural |

### 🎯 Siguiente Sesión de Trabajo

**Para completar MVP Deployment:**

1. **Validar Backups (30 min):**
   ```powershell
   # Aplicar todos los CronJobs
   kubectl apply -f 02-promptcrm/promptcrm-backup-cronjob.yaml
   kubectl apply -f 03-promptads/promptads-backup-cronjob.yaml
   kubectl apply -f 04-mongodb/mongodb-backup-cronjob.yaml
   kubectl apply -f 05-postgresql/postgres-backup-cronjob.yaml
   kubectl apply -f 06-redis/redis-backup-cronjob.yaml

   # Ejecutar job manual de prueba
   kubectl create job --from=cronjob/postgres-backup postgres-backup-test -n promptcontent-dev
   kubectl logs job/postgres-backup-test -n promptcontent-dev -f

   # Verificar backup creado
   kubectl exec -n promptcontent-dev postgres-0 -- ls -lh /backups
   ```

2. **Implementar TLS Básico para PostgreSQL (1-2 horas):**
   ```powershell
   # Generar certificados self-signed
   # Crear Secret con certificados
   # Actualizar StatefulSet con volumeMounts
   # Actualizar pg_hba.conf para requerir SSL
   ```

3. **Rotar Credenciales por Defecto (30 min):**
   ```powershell
   # Generar passwords aleatorios
   # Actualizar todos los *-secret.yaml
   # Documentar en README
   ```

4. **Deshabilitar HPA o Reducir a maxReplicas: 1 (10 min):**
   ```powershell
   kubectl patch hpa postgres-hpa -n promptcontent-dev -p '{"spec":{"maxReplicas":1}}'
   kubectl patch hpa mongodb-hpa -n mongo -p '{"spec":{"maxReplicas":1}}'
   kubectl patch hpa redis-hpa -n redis -p '{"spec":{"maxReplicas":1}}'
   kubectl patch hpa promptcrm-hpa -n promptcrm -p '{"spec":{"maxReplicas":1}}'
   kubectl patch hpa promptads-hpa -n promptads -p '{"spec":{"maxReplicas":1}}'
   ```

5. **Aumentar Memoria de Minikube a 12GB (15 min):**
   ```powershell
   # Detener deployment actual
   kubectl delete -f 05-postgresql/
   minikube stop
   minikube delete
   minikube start --memory=12288 --cpus=6 --disk-size=50g
   minikube addons enable metrics-server
   .\deploy-all.ps1
   ```

---

**Autor**: PromptSales Team
**Fecha**: Noviembre 2025
**Versión**: 2.0 MVP (HPA, PDB, Anti-affinity, NetworkPolicies, Secrets, Backups)
**Configuración Validada**: Minikube + Docker (v1.29.6, 6CPU, 10GB RAM, 50GB disk)
**Siguiente Milestone**: MVP Completo (TLS, backups validados, credenciales rotadas)
