# ============================================
# PromptSales - Status Check
# ============================================
# Verifica el estado de todos los recursos

Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          PromptSales - Estado del Sistema                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Función para obtener el estado de un pod
function Get-PodStatus {
    param([string]$Namespace, [string]$Label)

    $pods = kubectl get pods -n $Namespace -l $Label -o json 2>$null | ConvertFrom-Json

    if ($pods.items) {
        $pod = $pods.items[0]
        $status = $pod.status.phase
        $ready = $pod.status.containerStatuses[0].ready

        if ($ready -eq $true) {
            return "✅ READY"
        } elseif ($status -eq "Running") {
            return "⏳ Running (not ready)"
        } else {
            return "❌ $status"
        }
    } else {
        return "❌ NOT FOUND"
    }
}

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " ESTADO DE BASES DE DATOS" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray

$databases = @(
    @{Name="PromptCRM    "; Namespace="promptcrm"; Label="app=promptcrm"},
    @{Name="PromptAds    "; Namespace="promptads"; Label="app=promptads"},
    @{Name="MongoDB      "; Namespace="mongo"; Label="app=mongodb"},
    @{Name="PostgreSQL   "; Namespace="promptcontent-dev"; Label="app=postgres"},
    @{Name="Redis        "; Namespace="redis"; Label="app=redis"}
)

foreach ($db in $databases) {
    $status = Get-PodStatus -Namespace $db.Namespace -Label $db.Label
    Write-Host " $($db.Name): $status" -ForegroundColor White
}

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " PODS POR NAMESPACE" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray
kubectl get pods --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " SERVICIOS (LoadBalancer/ClusterIP)" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray
kubectl get svc --all-namespaces | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " PERSISTENT VOLUME CLAIMS" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray
kubectl get pvc --all-namespaces

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " USO DE RECURSOS (Nodos)" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray
kubectl top nodes 2>&1 | Out-Default

Write-Host "`n════════════════════════════════════════════" -ForegroundColor Gray
Write-Host " USO DE RECURSOS (Pods)" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════" -ForegroundColor Gray
kubectl top pods --all-namespaces 2>&1 | Select-String -Pattern "promptcrm|promptads|mongo|redis|postgres"

Write-Host "`n💡 Comandos útiles:" -ForegroundColor Cyan
Write-Host "   Ver logs: kubectl logs -n <namespace> <pod-name> -f" -ForegroundColor Gray
Write-Host "   Describir pod: kubectl describe pod -n <namespace> <pod-name>" -ForegroundColor Gray
Write-Host "   Reiniciar: kubectl rollout restart statefulset/<name> -n <namespace>" -ForegroundColor Gray
