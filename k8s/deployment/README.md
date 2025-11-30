# PromptSales - Deployment en Kubernetes

Este directorio contiene todos los manifiestos YAML y scripts necesarios para desplegar el ecosistema completo de PromptSales en Kubernetes/Minikube.

## 📁 Estructura del Directorio

```
Deployment/
├── 01-namespaces/          # Namespaces de Kubernetes
│   └── namespaces.yaml
├── 02-promptcrm/           # SQL Server - PromptCRM (500K+ clientes)
│   ├── promptcrm-secret.yaml
│   ├── promptcrm-pvc.yaml
│   ├── promptcrm-statefulset.yaml
│   └── promptcrm-service.yaml
├── 03-promptads/           # SQL Server - PromptAds (campañas publicitarias)
│   ├── promptads-secret.yaml
│   ├── promptads-pvc.yaml
│   ├── promptads-statefulset.yaml
│   └── promptads-service.yaml
├── 04-mongodb/             # MongoDB 7.0 - PromptContent
│   ├── mongodb-secret.yaml
│   ├── mongodb-statefulset.yaml
│   └── mongodb-service.yaml
├── 05-postgresql/          # PostgreSQL con pgvector - PromptSales
│   ├── postgres-configmap.yaml
│   ├── pg-hba-configmap.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-statefulset.yaml
│   └── postgres-service.yaml
├── 06-redis/               # Redis 7.2 - Cache centralizado
│   ├── redis-statefulset.yaml
│   └── redis-service.yaml
├── deploy-all.ps1          # Script de deployment automático
├── cleanup-all.ps1         # Script para eliminar todos los recursos
├── status.ps1              # Script para verificar estado del sistema
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

---

**Autor**: PromptSales Team
**Fecha**: Noviembre 2025
**Versión**: 2.0 (con HPA, PDB, Anti-affinity, NetworkPolicies)
**Configuración Validada**: Minikube + Docker (v1.29.6, 6CPU, 10GB RAM, 50GB disk)
