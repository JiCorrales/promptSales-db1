# Script para iniciar y configurar Minikube para PromptSales

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Configuracion de Minikube para PromptSales" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si Minikube esta instalado
$minikubePath = "C:\Program Files\Kubernetes\Minikube\minikube.exe"
if (-not (Test-Path $minikubePath)) {
    # Intentar encontrar en otras ubicaciones comunes
    $minikubePath = (Get-Command minikube -ErrorAction SilentlyContinue).Source
    if (-not $minikubePath) {
        Write-Host "ERROR: No se encuentra minikube" -ForegroundColor Red
        Write-Host "Por favor instalalo con: winget install Kubernetes.minikube" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Minikube encontrado en: $minikubePath" -ForegroundColor Green
Write-Host ""

# Verificar estado actual de Minikube
Write-Host "[1/5] Verificando estado de Minikube..." -ForegroundColor Yellow
$status = & $minikubePath status 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Minikube ya esta corriendo" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Minikube no esta corriendo. Iniciando..." -ForegroundColor Yellow
    Write-Host ""

    # Iniciar Minikube con configuracion para SQL Server
    Write-Host "[2/5] Iniciando Minikube (puede tomar 2-3 minutos)..." -ForegroundColor Yellow
    & $minikubePath start --driver=docker --memory=8192 --cpus=4

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo al iniciar Minikube" -ForegroundColor Red
        exit 1
    }
    Write-Host "Minikube iniciado exitosamente" -ForegroundColor Green
    Write-Host ""
}

# Cambiar contexto de kubectl a Minikube
Write-Host "[3/5] Cambiando contexto a Minikube..." -ForegroundColor Yellow
kubectl config use-context minikube

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Fallo al cambiar contexto" -ForegroundColor Red
    exit 1
}
Write-Host "Contexto cambiado a Minikube" -ForegroundColor Green
Write-Host ""

# Verificar nodos
Write-Host "[4/5] Verificando nodos..." -ForegroundColor Yellow
kubectl get nodes
Write-Host ""

# Mostrar informacion del cluster
Write-Host "[5/5] Informacion del cluster:" -ForegroundColor Yellow
& $minikubePath status
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host "Minikube configurado exitosamente" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Siguiente paso:" -ForegroundColor Cyan
Write-Host "Ejecuta: .\deploy-sqlserver.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Para acceder a servicios LoadBalancer, ejecuta en otra terminal:" -ForegroundColor Yellow
Write-Host "  minikube tunnel" -ForegroundColor White
Write-Host ""
