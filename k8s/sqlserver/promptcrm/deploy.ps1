# =====================================================
# Script de Despliegue de SQL Server - PromptCRM
# Usuario: abofi
# =====================================================

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Despliegue de SQL Server - PromptCRM (abofi)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
$currentDir = Get-Location
if ($currentDir.Path -notlike "*promptcrm*") {
    Write-Host "ADVERTENCIA: No estas en el directorio promptcrm" -ForegroundColor Yellow
    Write-Host "Cambiando al directorio correcto..." -ForegroundColor Yellow
    Set-Location $PSScriptRoot
}

# Función para verificar si kubectl está disponible
function Test-Kubectl {
    try {
        kubectl version --client --short 2>&1 | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Función para verificar si Minikube está corriendo
function Test-Minikube {
    try {
        $status = minikube status --format='{{.Host}}'
        return $status -eq "Running"
    } catch {
        return $false
    }
}

# Verificar prerequisitos
Write-Host "[1/6] Verificando prerequisitos..." -ForegroundColor Yellow

if (-not (Test-Kubectl)) {
    Write-Host "ERROR: kubectl no esta instalado o no esta en el PATH" -ForegroundColor Red
    Write-Host "Instala kubectl: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Red
    exit 1
}
Write-Host "   kubectl encontrado" -ForegroundColor Green

if (-not (Test-Minikube)) {
    Write-Host "ERROR: Minikube no esta corriendo" -ForegroundColor Red
    Write-Host "Inicia Minikube con: minikube start --memory=8192 --cpus=4" -ForegroundColor Red
    exit 1
}
Write-Host "   Minikube esta corriendo" -ForegroundColor Green

Write-Host ""

# Paso 1: Crear Namespace
Write-Host "[2/6] Creando namespace 'promptsales'..." -ForegroundColor Yellow
kubectl apply -f namespace.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo crear el namespace" -ForegroundColor Red
    exit 1
}
Write-Host "   Namespace creado/verificado" -ForegroundColor Green
Write-Host ""

# Paso 2: Crear Secret
Write-Host "[3/6] Creando Secret 'sqlserver-abofi-secret'..." -ForegroundColor Yellow
kubectl apply -f sqlserver-shared-secret.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo crear el Secret" -ForegroundColor Red
    exit 1
}
Write-Host "   Secret creado" -ForegroundColor Green
Write-Host ""

# Paso 3: Crear PVC
Write-Host "[4/6] Creando PVC 'sqlserver-abofi-pvc'..." -ForegroundColor Yellow
kubectl apply -f sqlserver-shared-pvc.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo crear el PVC" -ForegroundColor Red
    exit 1
}
Write-Host "   PVC creado" -ForegroundColor Green

# Esperar a que el PVC esté Bound
Write-Host "  Esperando a que el PVC este Bound..." -ForegroundColor Yellow
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $pvcStatus = kubectl get pvc -n promptsales sqlserver-abofi-pvc -o jsonpath='{.status.phase}' 2>$null
    if ($pvcStatus -eq "Bound") {
        Write-Host "   PVC esta Bound" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "  ." -NoNewline
}

if ($elapsed -ge $timeout) {
    Write-Host ""
    Write-Host "ADVERTENCIA: El PVC no esta Bound despues de ${timeout}s" -ForegroundColor Yellow
    Write-Host "Continuando de todas formas..." -ForegroundColor Yellow
}
Write-Host ""

# Paso 4: Crear Deployment
Write-Host "[5/6] Creando Deployment 'sqlserver-abofi'..." -ForegroundColor Yellow
kubectl apply -f sqlserver-shared-deployment.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo crear el Deployment" -ForegroundColor Red
    exit 1
}
Write-Host "   Deployment creado" -ForegroundColor Green

# Esperar a que el pod esté Running
Write-Host "  Esperando a que el pod este Running (esto puede tomar 1-2 minutos)..." -ForegroundColor Yellow
$timeout = 180
$elapsed = 0
while ($elapsed -lt $timeout) {
    $podStatus = kubectl get pods -n promptsales -l app=sqlserver-abofi -o jsonpath='{.items[0].status.phase}' 2>$null
    if ($podStatus -eq "Running") {
        Write-Host ""
        Write-Host "   Pod esta Running" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "  ." -NoNewline
}

if ($elapsed -ge $timeout) {
    Write-Host ""
    Write-Host "ADVERTENCIA: El pod no esta Running despues de ${timeout}s" -ForegroundColor Yellow
    Write-Host "Verifica los logs con: kubectl logs -n promptsales -l app=sqlserver-abofi" -ForegroundColor Yellow
}
Write-Host ""

# Paso 5: Crear Service
Write-Host "[6/6] Creando Service 'sqlserver-abofi'..." -ForegroundColor Yellow
kubectl apply -f sqlserver-shared-service.yaml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo crear el Service" -ForegroundColor Red
    exit 1
}
Write-Host "   Service creado" -ForegroundColor Green
Write-Host ""

# Resumen
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  DESPLIEGUE COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Mostrar estado de los recursos
Write-Host "Estado de los recursos:" -ForegroundColor Yellow
kubectl get all,pvc,secret -n promptsales -l owner=abofi
Write-Host ""

# Instrucciones finales
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  PROXIMOS PASOS" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. EXPONER EL SERVICIO:" -ForegroundColor Yellow
Write-Host "   Ejecuta en una terminal de PowerShell SEPARADA como Administrador:" -ForegroundColor White
Write-Host "   > minikube tunnel" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. CONECTAR DESDE SSMS:" -ForegroundColor Yellow
Write-Host "   Server name:  127.0.0.1,1433" -ForegroundColor White
Write-Host "   Login:        sa" -ForegroundColor White
Write-Host "   Password:     Caso#2SQLlito" -ForegroundColor White
Write-Host ""
Write-Host "3. CREAR LA BASE DE DATOS:" -ForegroundColor Yellow
Write-Host "   Ejecuta el script:" -ForegroundColor White
Write-Host "   databases\sqlserver\promptcrm\migrations\001-Initial-structure.sql" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. COMANDOS UTILES:" -ForegroundColor Yellow
Write-Host "   Ver logs:     kubectl logs -n promptsales -l app=sqlserver-abofi -f" -ForegroundColor White
Write-Host "   Ver pods:     kubectl get pods -n promptsales -l app=sqlserver-abofi" -ForegroundColor White
Write-Host "   Reiniciar:    kubectl rollout restart deployment -n promptsales sqlserver-abofi" -ForegroundColor White
Write-Host "   Eliminar:     kubectl delete all,pvc,secret -n promptsales -l owner=abofi" -ForegroundColor White
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
