# ============================================
# PromptSales - Deployment Automático
# ============================================
# Este script despliega todas las 4 bases de datos en Minikube
# Autor: PromptSales Team
# Fecha: Noviembre 2025

param(
    [switch]$SkipMinikubeCheck,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Establecer directorio de trabajo al directorio del script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir
Write-Host "Directorio de trabajo: $ScriptDir" -ForegroundColor Gray

Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          PromptSales - Deployment Automático             ║
║                                                           ║
║  Desplegando 5 bases de datos en Kubernetes/Minikube    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Función para verificar comandos
function Test-Command {
    param($Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Función para esperar que los pods estén listos
function Wait-PodReady {
    param(
        [string]$Namespace,
        [string]$LabelSelector,
        [int]$TimeoutSeconds = 120
    )

    Write-Host "⏳ Esperando que los pods en namespace '$Namespace' estén listos..." -ForegroundColor Yellow

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $pods = kubectl get pods -n $Namespace -l $LabelSelector -o json 2>$null | ConvertFrom-Json

        if ($pods.items) {
            $ready = $true
            foreach ($pod in $pods.items) {
                # Verificar que containerStatuses existe y tiene elementos
                if ($pod.status.containerStatuses -and $pod.status.containerStatuses.Count -gt 0) {
                    $status = $pod.status.containerStatuses[0].ready
                    if (-not $status) {
                        $ready = $false
                        break
                    }
                } else {
                    # Si no hay containerStatuses aún, el pod no está listo
                    $ready = $false
                    break
                }
            }

            if ($ready) {
                Write-Host "Pods en '$Namespace' estan listos" -ForegroundColor Green
                return $true
            }
        }

        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "." -NoNewline -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "⚠️  Timeout esperando pods en '$Namespace'" -ForegroundColor Yellow
    return $false
}

# ============================================
# 1. Verificar Prerequisitos
# ============================================
Write-Host "`n[1/8] 📋 Verificando prerequisitos..." -ForegroundColor Cyan

# Verificar kubectl
if (-not (Test-Command "kubectl")) {
    Write-Host "❌ kubectl no está instalado" -ForegroundColor Red
    Write-Host "   Instalar desde: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ kubectl instalado" -ForegroundColor Green

# Verificar minikube
if (-not (Test-Command "minikube")) {
    Write-Host "❌ minikube no está instalado" -ForegroundColor Red
    Write-Host "   Instalar desde: https://minikube.sigs.k8s.io/docs/start/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ minikube instalado" -ForegroundColor Green

# Verificar que Minikube está corriendo
if (-not $SkipMinikubeCheck) {
    Write-Host "`n🔍 Verificando estado de Minikube..." -ForegroundColor Yellow
    $minikubeStatus = minikube status 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Minikube no está corriendo" -ForegroundColor Red
        Write-Host "   Iniciando Minikube..." -ForegroundColor Yellow

        minikube start `
            --driver=docker `
            --kubernetes-version=v1.29.6 `
            --container-runtime=containerd `
            --cpus=6 `
            --memory=12240 `
            --disk-size=50g

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Error al iniciar Minikube" -ForegroundColor Red
            exit 1
        }

        Write-Host "✅ Minikube iniciado correctamente" -ForegroundColor Green
    } else {
        Write-Host "✅ Minikube ya está corriendo" -ForegroundColor Green
    }

    # Habilitar metrics-server
    Write-Host "`n📊 Habilitando metrics-server..." -ForegroundColor Yellow
    minikube addons enable metrics-server 2>&1 | Out-Null
    Write-Host "✅ Metrics-server habilitado" -ForegroundColor Green
}

# ============================================
# 2. Crear Namespaces
# ============================================
Write-Host "`n[2/8] 📁 Creando namespaces..." -ForegroundColor Cyan

kubectl apply -f 01-namespaces/namespaces.yaml

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Namespaces creados" -ForegroundColor Green
} else {
    Write-Host "❌ Error al crear namespaces" -ForegroundColor Red
    exit 1
}

# Esperar un momento
Start-Sleep -Seconds 2

# ============================================
# 3. Desplegar PromptCRM (SQL Server)
# ============================================
Write-Host "`n[3/8] Desplegando PromptCRM (SQL Server)..." -ForegroundColor Cyan

Write-Host "   Aplicando manifiestos..." -ForegroundColor Gray
kubectl apply -f 02-promptcrm/

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] PromptCRM desplegado" -ForegroundColor Green
    Wait-PodReady -Namespace "promptcrm" -LabelSelector "app=promptcrm" -TimeoutSeconds 180
} else {
    Write-Host "[ERROR] Error al desplegar PromptCRM" -ForegroundColor Red
}

# ============================================
# 4. Desplegar PromptAds (SQL Server)
# ============================================
Write-Host "`n[4/8] Desplegando PromptAds (SQL Server)..." -ForegroundColor Cyan

Write-Host "   → Aplicando manifiestos..." -ForegroundColor Gray
kubectl apply -f 03-promptads/

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ PromptAds desplegado" -ForegroundColor Green
    Wait-PodReady -Namespace "promptads" -LabelSelector "app=promptads" -TimeoutSeconds 180
} else {
    Write-Host "❌ Error al desplegar PromptAds" -ForegroundColor Red
}

# ============================================
# 5. Desplegar MongoDB
# ============================================
Write-Host "`n[5/8] 🍃 Desplegando MongoDB..." -ForegroundColor Cyan

Write-Host "   → Aplicando manifiestos..." -ForegroundColor Gray
kubectl apply -f 04-mongodb/

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ MongoDB desplegado" -ForegroundColor Green
    Wait-PodReady -Namespace "mongo" -LabelSelector "app=mongodb" -TimeoutSeconds 120
} else {
    Write-Host "❌ Error al desplegar MongoDB" -ForegroundColor Red
}

# ============================================
# 6. Desplegar PostgreSQL (pgvector)
# ============================================
Write-Host "`n[6/8] 🐘 Desplegando PostgreSQL (pgvector)..." -ForegroundColor Cyan

Write-Host "   → Aplicando manifiestos..." -ForegroundColor Gray
kubectl apply -f 05-postgresql/

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ PostgreSQL desplegado" -ForegroundColor Green
    Wait-PodReady -Namespace "promptcontent-dev" -LabelSelector "app=postgres" -TimeoutSeconds 120
} else {
    Write-Host "❌ Error al desplegar PostgreSQL" -ForegroundColor Red
}

# ============================================
# 7. Desplegar Redis
# ============================================
Write-Host "`n[7/8] 🔴 Desplegando Redis..." -ForegroundColor Cyan

Write-Host "Aplicando manifiestos..." -ForegroundColor Gray
kubectl apply -f 06-redis/

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Redis desplegado" -ForegroundColor Green
    Wait-PodReady -Namespace "redis" -LabelSelector "app=redis" -TimeoutSeconds 60
} else {
    Write-Host "❌ Error al desplegar Redis" -ForegroundColor Red
}

# ============================================
# 8. Verificar Deployment
# ============================================
Write-Host "`n[8/8] 🔍 Verificando deployment completo..." -ForegroundColor Cyan

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "Estado de todos los Pods:" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get pods --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "Estado de todos los Services:" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get svc --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "Estado de todos los PVCs:" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get pvc --all-namespaces

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "Estado de HPAs (Autoescalado):" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get hpa --all-namespaces

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "Estado de PDBs (Alta Disponibilidad):" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get pdb --all-namespaces

Write-Host "`n-------------------------------------------" -ForegroundColor Gray
Write-Host "NetworkPolicies (Seguridad):" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray
kubectl get networkpolicies --all-namespaces

# ============================================
# Resumen Final
# ============================================
Write-Host @"
+---------------------------------------------------------+
|                                                         |
|              ✅ DEPLOYMENT COMPLETADO                    |
|                     Versión 2.0                         |
|     con HPA, PDB, Anti-affinity, NetworkPolicies        |
|                                                         |
+---------------------------------------------------------+

Bases de Datos Desplegadas:
   - PromptCRM    (SQL Server 2022) - namespace: promptcrm    [1-10 replicas HPA]
   - PromptAds    (SQL Server 2022) - namespace: promptads    [1-8 replicas HPA]
   - MongoDB      (v7.0)            - namespace: mongo        [1-6 replicas HPA]
   - PostgreSQL   (pgvector)        - namespace: promptcontent-dev [1-8 replicas HPA]
   - Redis        (v7.2)            - namespace: redis        [1-6 replicas HPA]

Caracteristicas Implementadas:
   - Autoescalado Horizontal (HPA) - CPU/Memoria
   - Anti-Affinity Rules - Distribucion en nodos (cuando hay multiples replicas)
   - NetworkPolicies - Seguridad de red
   - PodDisruptionBudget - Proteccion durante updates
   - Configuracion optimizada para desarrollo (1 replica inicial, escalable segun demanda)

Proximos Pasos:

1. Iniciar Minikube Tunnel (en terminal como Administrador):

   minikube tunnel

2. Verificar IPs externas de los servicios:

   kubectl get svc --all-namespaces

3. Conectar a las bases de datos:

   PromptCRM:
   - Server: 127.0.0.1,1433
   - User: sa
   - Password: AleeCR27

   PromptAds:
   - Server: 127.0.0.1,1434
   - User: sa
   - Password: AleeCR27

   MongoDB:
   - Connection: mongodb://admin:MongoPassword123!@127.0.0.1:27017/admin

   PostgreSQL:
   - Connection: postgresql://User:UserPassword123!@127.0.0.1:5432/PromptContent

   Redis:
   - Port-forward: kubectl port-forward -n redis svc/redis 6379:6379

4. Ejecutar scripts de migracion para crear las bases de datos

Comandos Utiles:

   Ver logs de un pod:
   kubectl logs -n [namespace] [pod-name] -f

   Ver estado completo:
   kubectl get all,pvc --all-namespaces

   Reiniciar un deployment:
   kubectl rollout restart statefulset/[name] -n [namespace]

Documentacion completa: README.md

"@ -ForegroundColor Green

Write-Host "Deployment completado exitosamente" -ForegroundColor Cyan
