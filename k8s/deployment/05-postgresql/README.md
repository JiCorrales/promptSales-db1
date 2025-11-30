# PostgreSQL - Base de Datos Centralizada de PromptSales

## Descripción General

PostgreSQL es la **base de datos centralizada** del ecosistema PromptSales. Recibe datos consolidados desde todos los subsistemas (PromptCRM, PromptAds, PromptContent) y proporciona métricas sumarizadas para análisis y reporting.

### Imagen de Contenedor

```yaml
image: ankane/pgvector:latest
```

**Ubicación:** [postgres-statefulset.yaml](postgres-statefulset.yaml#L35)

Esta imagen incluye:
- PostgreSQL 16 (versión estable)
- Extensión **pgvector** para vectores embeddings (necesaria para funcionalidades de IA/ML)
- Soporte para búsquedas de similitud vectorial

---

## Arquitectura de Componentes

### Rol en el Ecosistema

```
┌─────────────────┐
│   PromptCRM     │────┐
│  (SQL Server)   │    │
└─────────────────┘    │
                       │
┌─────────────────┐    │     ┌──────────────────────┐
│   PromptAds     │────┼────►│   PostgreSQL         │
│  (SQL Server)   │    │     │  (Base Centralizada) │
└─────────────────┘    │     └──────────────────────┘
                       │              │
┌─────────────────┐    │              │
│  PromptContent  │────┘              ▼
│  (MongoDB)      │            [Métricas & NLQ]
└─────────────────┘            [MCP Server]
```

### Propósito

1. **Consolidación de Datos:** Recibe datos ETL desde PromptCRM, PromptAds y PromptContent
2. **Métricas Sumarizadas:** Almacena KPIs, métricas de rendimiento de campañas
3. **NLQ (Natural Language Queries):** MCP server para consultas en lenguaje natural
4. **Análisis Avanzado:** Vectores embeddings para búsquedas semánticas

---

## Configuración de Seguridad

### Kubernetes Secrets

**Archivo:** [postgres-secret.yaml](postgres-secret.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: promptcontent-dev
type: Opaque
stringData:
  POSTGRES_DB: "PromptContent"
  POSTGRES_USER: "User"
  POSTGRES_PASSWORD: "UserPassword123!"
```

**Estado:** ✅ Implementado en v2.0

**Razón:** Se movieron las credenciales desde ConfigMap a Secret para eliminar vulnerabilidad de seguridad (almacenamiento de contraseñas en texto plano).

### ConfigMap (Solo Datos No Sensibles)

**Archivo:** [postgres-configmap.yaml](postgres-configmap.yaml)

Contiene solo el nombre de la base de datos:
```yaml
data:
  POSTGRES_DB: "PromptContent"
```

---

## NetworkPolicy - Seguridad de Red

**Archivo:** [postgres-networkpolicy.yaml](postgres-networkpolicy.yaml)

### Arquitectura de Componentes

El NetworkPolicy usa **etiquetas de componentes** para controlar acceso:

#### Ingress (Quién puede conectarse)

PostgreSQL acepta conexiones desde los siguientes componentes:

```yaml
ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          component: crm        # PromptCRM
    - namespaceSelector:
        matchLabels:
          component: ads        # PromptAds
    - namespaceSelector:
        matchLabels:
          component: content    # PromptContent/MCP
    - namespaceSelector:
        matchLabels:
          component: central    # Mismo namespace/servicios internos
    ports:
      - protocol: TCP
        port: 5432
```

#### Egress (A dónde puede conectarse)

1. **DNS:** Resolución de nombres (kube-system)
2. **Replicación:** Comunicación entre réplicas de PostgreSQL (para HA futuro)

### Topología de Red

```
component: crm ────────┐
component: ads ────────┤
component: content ────┼───► PostgreSQL:5432 (puerto TCP)
component: central ────┘
```

---

## Alta Disponibilidad (HA)

### Estado Actual (v2.0 - MVP)

#### HorizontalPodAutoscaler (HPA)

**Archivo:** [postgres-hpa.yaml](postgres-hpa.yaml)

```yaml
spec:
  minReplicas: 1        # Inicio: 1 pod
  maxReplicas: 8        # Máximo: 8 pods
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 70%
    - type: Resource
      resource:
        name: memory
        target:
          averageUtilization: 75%
```

**⚠️ ADVERTENCIA:** HPA en bases de datos StatefulSet requiere configuración adicional:
- Actualmente configurado pero NO recomendado para producción sin replicación streaming
- Para escalar READ operations, se requiere PostgreSQL streaming replication (primary + réplicas)
- Ver "Próximos Pasos" más abajo

#### PodDisruptionBudget (PDB)

**Archivo:** [postgres-pdb.yaml](postgres-pdb.yaml)

```yaml
spec:
  minAvailable: 1  # Mínimo 1 pod disponible durante updates/mantenimiento
```

**Propósito:** Evita downtime durante rolling updates de Kubernetes.

#### Anti-Affinity

**Configuración en:** [postgres-statefulset.yaml](postgres-statefulset.yaml#L21)

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - postgres
        topologyKey: kubernetes.io/hostname
```

**Propósito:** Distribuye réplicas en diferentes nodos físicos para mayor resiliencia.

### Próximos Pasos (Post-MVP)

Para HA completo, se requiere:

1. **Streaming Replication:**
   ```
   Primary (read/write) → Réplica 1 (read-only)
                        → Réplica 2 (read-only)
   ```

2. **Servicio de Réplicas:**
   - Service principal: escribe en primary
   - Service read-only: balanceo entre réplicas

3. **pg_hba.conf:** Configuración de replicación ([pg-hba-configmap.yaml](pg-hba-configmap.yaml))

4. **Failover Automático:** Herramientas como Patroni o Stolon

**Referencia:** planDeTrabajo.md § 1 "PostgreSQL: habilitar streaming replication"

---

## Backups y Recuperación

### Estado Actual

#### Archivos Implementados

1. **[postgres-backup-cronjob.yaml](postgres-backup-cronjob.yaml)**
   - CronJob diario para backups automáticos
   - Retención: 30 días
   - Almacenamiento: PVC local

2. **[postgres-backup-pvc.yaml](postgres-backup-pvc.yaml)**
   - PersistentVolumeClaim para almacenar backups
   - Tamaño: 10Gi

3. **[postgres-restore-job.yaml](postgres-restore-job.yaml)**
   - Job bajo demanda para restaurar desde backup
   - Usa dumps locales en PVC

#### Estado de Deployment

```
✅ Archivos creados
⚠️  Pendiente: Validar ejecución en cluster
⚠️  Pendiente: Documentar procedimiento de restore manual
```

### Procedimiento de Restore (Planificado)

```bash
# 1. Listar backups disponibles
kubectl exec -n promptcontent-dev postgres-0 -- ls -lh /backups

# 2. Aplicar Job de restore
kubectl apply -f postgres-restore-job.yaml

# 3. Monitorear restore
kubectl logs -n promptcontent-dev job/postgres-restore -f
```

### Próximos Pasos (Post-MVP)

1. **Validar CronJob:** Ejecutar job manual y verificar backup
2. **Almacenamiento Externo:** Mover backups a bucket S3/GCS o PVC dedicado exportable
3. **Pruebas de Restore:** Documentar y probar procedimiento completo
4. **Automatización:** Hooks de restore opcionales (init/job)

**Referencia:** planDeTrabajo.md § 3 "Backups y DR"

---

## Recursos y Escalado

### Configuración Actual (Optimizada para 10GB Minikube)

**Archivo:** [postgres-statefulset.yaml](postgres-statefulset.yaml#L57)

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "4Gi"
```

### Storage

**Archivo:** [postgres-pvc.yaml](postgres-pvc.yaml)

```yaml
resources:
  requests:
    storage: 10Gi
storageClassName: standard
```

### Sizing Recommendations

Para cumplir requerimientos de statement.md:
- **Operaciones:** 100,000 ops/min
- **Campañas:** 5,000+ activas
- **Usuarios:** 300+ concurrentes

**Recomendaciones de Producción:**
- CPU: 4-8 cores
- Memory: 8-16Gi
- Storage: 50-100Gi con IOPS altos (SSD/NVMe)
- Storage Class: premium-rwo o equivalente con IOPS garantizados

**Referencia:** planDeTrabajo.md § 4 "Escalabilidad y rendimiento"

---

## Conexión desde Aplicaciones

### Dentro del Cluster

```bash
# Desde cualquier pod en namespaces autorizados
psql -h postgres.promptcontent-dev.svc.cluster.local -p 5432 -U User -d PromptContent
```

### Variables de Entorno (usando Secret)

```yaml
env:
- name: POSTGRES_HOST
  value: "postgres.promptcontent-dev.svc.cluster.local"
- name: POSTGRES_PORT
  value: "5432"
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_DB
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_PASSWORD
```

### Connection String

```
postgresql://User:UserPassword123!@postgres.promptcontent-dev.svc.cluster.local:5432/PromptContent
```

**⚠️ Seguridad:** La contraseña por defecto debe ser rotada en producción.

---

## Healthchecks

### Readiness Probe

```yaml
readinessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Propósito:** Verificar que PostgreSQL acepta conexiones antes de enviar tráfico.

### Liveness Probe

```yaml
livenessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 15
  periodSeconds: 20
```

**Propósito:** Reiniciar el pod si PostgreSQL deja de responder.

---

## Extensiones y Funcionalidades

### pgvector

PostgreSQL incluye la extensión **pgvector** para:

1. **Vector Embeddings:** Almacenar embeddings de texto/imágenes (dimensión configurable)
2. **Búsquedas de Similitud:** Búsquedas semánticas usando cosine similarity, L2 distance, inner product
3. **Índices Vectoriales:** IVFFlat, HNSW para búsquedas rápidas

#### Uso Ejemplo

```sql
-- Crear tabla con vectores
CREATE TABLE embeddings (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(1536)  -- OpenAI ada-002: 1536 dimensiones
);

-- Crear índice HNSW
CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);

-- Búsqueda de similitud
SELECT content, 1 - (embedding <=> '[0.1, 0.2, ...]') AS similarity
FROM embeddings
ORDER BY embedding <=> '[0.1, 0.2, ...]'
LIMIT 5;
```

### Scripts Planificados (PromptSales Central)

Según planDeTrabajo.md § 9, se implementarán:

- Triggers para actualización automática de métricas
- Cursors para procesamiento batch
- Interlocks para control de concurrencia
- Metadata tables para auditoría
- Monitoring queries
- JOINs complejos para consolidación de datos
- COALESCE/CASE para lógica de negocio
- GRANT/REVOKE para control de acceso

---

## Seguridad Pendiente (Post-MVP)

### TLS Interno

**Estado:** ⚠️ Pendiente

**Requisitos:**
1. Generar certificados self-signed o usar cert-manager
2. Configurar PostgreSQL para TLS:
   ```
   ssl = on
   ssl_cert_file = '/etc/ssl/certs/server.crt'
   ssl_key_file = '/etc/ssl/private/server.key'
   ```
3. Actualizar pg_hba.conf para requerir SSL
4. Montar certificados como Secret

**Referencia:** planDeTrabajo.md § 64 "TLS interno básico para PostgreSQL"

### Rotación de Credenciales

**Estado:** ⚠️ Pendiente

**Requisitos:**
1. Generar nuevos secrets por entorno (dev/staging/prod)
2. Parametrizar deploy-all.ps1 para seleccionar entorno
3. Documentar procedimiento de rotación sin downtime

**Referencia:** planDeTrabajo.md § 67 "Rotar credenciales por defecto"

### Cifrado en Reposo

**Estado:** ⚠️ Pendiente

**Opciones:**
1. Storage Class encriptada (proveedores de nube)
2. CSI driver con KMS integration
3. PostgreSQL pgcrypto para columnas específicas

**Referencia:** planDeTrabajo.md § 13 "Cifrado en reposo"

---

## Troubleshooting

### Pod en Estado Pending

**Síntoma:** `kubectl get pods -n promptcontent-dev` muestra Pending

**Causas Comunes:**
1. **Memoria Insuficiente:** Minikube con límite de 10GB
   ```bash
   # Verificar uso de memoria
   kubectl top nodes

   # Solución temporal: Reducir requests en StatefulSet
   # Solución permanente: Aumentar memoria de Minikube
   minikube delete
   minikube start --memory=12288 --cpus=6
   ```

2. **PVC No Disponible:** PersistentVolume no provisionado
   ```bash
   kubectl get pvc -n promptcontent-dev
   kubectl describe pvc postgres-data-postgres-0 -n promptcontent-dev
   ```

3. **Storage Class No Encontrado:** Verificar storage class
   ```bash
   kubectl get storageclass
   ```

### Conexión Rechazada

**Síntoma:** `could not connect to server: Connection refused`

**Verificaciones:**
1. **Pod Running:**
   ```bash
   kubectl get pods -n promptcontent-dev
   ```

2. **Service Expuesto:**
   ```bash
   kubectl get svc -n promptcontent-dev
   ```

3. **NetworkPolicy:**
   ```bash
   # Verificar que el namespace origen tiene label component correcto
   kubectl get namespace promptcontent-dev --show-labels

   # Temporal: Eliminar NetworkPolicy para debugging
   kubectl delete networkpolicy postgres-networkpolicy -n promptcontent-dev
   ```

4. **Logs del Pod:**
   ```bash
   kubectl logs -n promptcontent-dev postgres-0
   ```

### Backup Fallando

**Síntoma:** CronJob no crea backups

**Verificaciones:**
1. **Jobs Ejecutados:**
   ```bash
   kubectl get jobs -n promptcontent-dev
   kubectl describe cronjob postgres-backup -n promptcontent-dev
   ```

2. **Logs del Job:**
   ```bash
   kubectl logs -n promptcontent-dev job/postgres-backup-<timestamp>
   ```

3. **Permisos del PVC:**
   ```bash
   kubectl exec -n promptcontent-dev postgres-0 -- ls -la /backups
   ```

---

## Referencias

### Archivos del Deployment

- [postgres-statefulset.yaml](postgres-statefulset.yaml) - Deployment principal
- [postgres-service.yaml](postgres-service.yaml) - Service ClusterIP
- [postgres-pvc.yaml](postgres-pvc.yaml) - Almacenamiento persistente
- [postgres-secret.yaml](postgres-secret.yaml) - Credenciales
- [postgres-configmap.yaml](postgres-configmap.yaml) - Configuración no sensible
- [postgres-hpa.yaml](postgres-hpa.yaml) - Autoscaling
- [postgres-pdb.yaml](postgres-pdb.yaml) - Disruption budget
- [postgres-networkpolicy.yaml](postgres-networkpolicy.yaml) - Seguridad de red
- [pg-hba-configmap.yaml](pg-hba-configmap.yaml) - Configuración de acceso
- [postgres-backup-cronjob.yaml](postgres-backup-cronjob.yaml) - Backups automáticos
- [postgres-backup-pvc.yaml](postgres-backup-pvc.yaml) - Storage para backups
- [postgres-restore-job.yaml](postgres-restore-job.yaml) - Restore bajo demanda

### Documentación Externa

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [pgvector Extension](https://github.com/pgvector/pgvector)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [planDeTrabajo.md](../../planDeTrabajo.md) - Roadmap completo

---

## Changelog

### v2.0 (2025-01-XX) - MVP Deployment

**Nuevas Características:**
- ✅ HorizontalPodAutoscaler configurado (1-8 replicas)
- ✅ PodDisruptionBudget (minAvailable: 1)
- ✅ Anti-affinity para distribución de réplicas
- ✅ NetworkPolicy con arquitectura de componentes
- ✅ Kubernetes Secrets para credenciales
- ✅ Backups automáticos (CronJob + PVC)
- ✅ Job de restore bajo demanda

**Pendientes:**
- ⚠️ TLS interno (certificados self-signed)
- ⚠️ Streaming replication (primary + réplicas)
- ⚠️ Rotación de credenciales
- ⚠️ Validación de CronJobs en cluster
- ⚠️ Almacenamiento externo para backups
- ⚠️ Prometheus/Grafana monitoring

### v1.0 (Inicial)

- PostgreSQL con pgvector
- StatefulSet con 1 réplica
- PVC 10Gi
- Service ClusterIP

---

**Última actualización:** 2025-01-XX
**Versión:** v2.0 MVP
**Mantenedor:** Equipo PromptSales
