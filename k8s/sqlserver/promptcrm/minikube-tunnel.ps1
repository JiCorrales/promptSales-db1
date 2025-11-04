# Script para crear tunnel de Minikube
# IMPORTANTE: Debe ejecutarse como Administrador

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Minikube Tunnel - PromptSales" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script crea un tunnel para exponer los servicios LoadBalancer" -ForegroundColor Yellow
Write-Host "Debe permanecer corriendo mientras uses SQL Server" -ForegroundColor Yellow
Write-Host ""
Write-Host "Conexion a SQL Server:" -ForegroundColor Green
Write-Host "  Server: localhost" -ForegroundColor White
Write-Host "  User: sa" -ForegroundColor White
Write-Host "  Password: Caso#2SQLlito" -ForegroundColor White
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el tunnel" -ForegroundColor Red
Write-Host ""
Write-Host "Iniciando tunnel..." -ForegroundColor Yellow
minikube tunnel
