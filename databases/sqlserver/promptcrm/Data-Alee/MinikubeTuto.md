
**PromptSales** está dividido en 3 subempresas:

- **PromptContent**: MongoDB + PostgreSQL/pgvector

- **PromptAds**: SQL Server 2022

- **PromptCrm:** SQL Server 2022
  
Cada miembro del equipo levanta su propio clúster Minikube local y expone sus servicios a través de **Radmin VPN**, simulando un entorno distribuido real.

---
### 1. Conectarse a Radmin

**IMPORTANTE:** Debes conectarte a Radmin VPN **ANTES** de iniciar Minikube.

**Por qué:** Cuando Minikube arranca, toma la configuración de red actual. Si te conectas a Radmin después, el clúster no estará en la misma red que tus compañeros.

**Pasos:**

1. Abre **Radmin VPN**
2. Conéctate a la red del equipo
3. Verifica tu IP de Radmin:

Anota tu IP, la necesitarás para exponer servicios.

---
### 2. Iniciar Minikube

#### 2.1 Eliminar clúster anterior (si existe)

Si ya tenías un Minikube corriendo, es mejor empezar limpio:

```powershell
minikube stop

minikube delete --purge
```

---
#### 2.2 Iniciar Minikube con configuración correcta

  

```powershell
minikube start `
--driver=docker `
--kubernetes-version=v1.29.6 `
--container-runtime=containerd `
--cpus=4 `
--memory=6144 `
--disk-size=40g
```

**Explicación de parámetros:**

- `--driver=docker`: Usa Docker como virtualizador

- `--kubernetes-version=v1.29.6`: Versión estable de Kubernetes

- `--container-runtime=containerd`: Runtime de contenedores moderno

- `--cpus=4`: 4 CPUs asignadas 

- `--memory=6144`: 6 GB de RAM 

- `--disk-size=40g`: 40 GB de disco para PVCs

---
#### 2.3 Hbilitar metrics-server (opcional pero recomendado)

```powershell
minikube addons enable metrics-server
```

Esto te permite monitorear el uso de CPU/memoria de los pods.

---
#### 2.4 Verificar estado del clúster

```powershell
minikube status
```

**Salida esperada:**

```
minikube

type: Control Plane

host: Running

kubelet: Running

apiserver: Running

kubeconfig: Configured
```

**Verificar que kubectl está conectado:**

```powershell
kubectl cluster-info
```

**Salida esperada:**

```
Kubernetes control plane is running at https://192.168.x.x:8443

CoreDNS is running at https://192.168.x.x:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

---
### 3. Crear Namespaces

Los namespaces son como "carpetas" para organizar tus recursos en Kubernetes.

```powershell
kubectl create namespace promptcrm
```

**Verificar:**

```powershell
kubectl get namespaces
```

**Salida esperada:**

```
NAME              STATUS   AGE

default           Active   5m

kube-system       Active   5m

kube-public       Active   5m

kube-node-lease   Active   5m

promptcrm         Active   10s  ✅
```

---
### 4. Desplegar SQL Server 2022

#### 4.1 Navegar a la carpeta de manifests

```powershell
C:\Users\abofi\OneDrive\MyStudio\Projects\Academic\PromptSales\promptSales-db1\databases\sqlserver\promptcrm\Data-Alee\Deploy-PromptCRM
```

---
#### 4.2 Aplicar el Secret (contraseña de SQL Server)

```powershell
kubectl apply -f promptcrm-secret.yaml
```

**Verificar:**

```powershell
kubectl get secret -n mssql
```

**Salida esperada:**

```
NAME               TYPE     DATA   AGE

promptcrm-secret   Opaque   1      5s
```

---
#### 4.3 Aplicar el Deployment de SQL Server

```powershell
kubectl apply -f promptcrm.yaml
```

**Esto crea:**

- StatefulSet (SQL Server pod)
- Service LoadBalancer (para exponer el puerto 1433)
- PersistentVolumeClaim (almacenamiento de 10GB para los datos)

**Salida esperada:**

```
service/mssql created

statefulset.apps/mssql created
```

---
#### 4.4 Monitorear el despliegue

**Ver el estado del pod en tiempo real:**

```powershell
kubectl get pods -n promptcrm -w
```

**Progreso esperado:**

```
NAME      READY   STATUS              RESTARTS   AGE

mssql-0   0/1     Pending             0          5s

mssql-0   0/1     ContainerCreating   0          10s

mssql-0   0/1     Running             0          45s

mssql-0   1/1     Running             0          90s  ✅
```

Cuando veas `1/1 Running`, presiona `Ctrl+C` para salir.

**Esto toma 1-2 minutos.** SQL Server necesita inicializar las bases de datos del sistema.

---
#### 4.5 Verificar logs de SQL Server

```powershell
kubectl logs -n promptcrm promptcrm-0 --tail=20
```

**Busca esta línea al final:**

```

SQL Server is now ready for client connections.

This is an informational message; no user action is required.

```

✅ Si ves esto, SQL Server está listo.

---
#### 4.6 Verificar recursos creados

```powershell
kubectl get all,pvc,secret -n promptcrm
```

**Nota:** `EXTERNAL-IP` está en `<pending>` porque aún no has iniciado `minikube tunnel`.

---
### 5. Exponer SQL Server (Conexión Local)

Tienes **2 opciones** para conectarte desde tu PC. Elige una:

##### Opción A: minikube tunnel (Recomendado para desarrollo)

**Ventaja:** Expone automáticamente todos los servicios LoadBalancer, puerto estándar 1433.

#### 5.1 Abrir PowerShell como Administrador

**Importante:** `minikube tunnel` requiere permisos de administrador.

1. Abre el menú de inicio
2. Busca "PowerShell"
3. Click derecho -> "Ejecutar como administrador"

#### 5.2 Iniciar el túnel

```powershell
minikube tunnel
```

**Salida esperada:**

```
✅ Tunnel successfully started
```

**DEJA ESTA TERMINAL ABIERTA** todo el tiempo que quieras conectarte.

#### 5.3 Verificar EXTERNAL-IP

En **otra terminal PowerShell** (normal, no admin):

```powershell
kubectl get svc -n promptcrm
```

**Con túnel activo verás:**

```
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)

mssql   LoadBalancer   10.100.9.31     127.0.0.1     1433:32354/TCP  ✅
```

#### 5.4 Conectar desde SSMS


```
Server name:      127.0.0.1,1433

Authentication:   SQL Server Authentication

Login:            sa

Password:         AleeCR27
```

**Nota:** Usa **COMA** (`,`) no dos puntos (`:`)

---
##### Opción B: kubectl port-forward 

**Ventaja:** No requiere permisos de administrador, puerto personalizado 15433.

#### 5.1 Iniciar port-forward

En cualquier terminal PowerShell:

```powershell
kubectl port-forward -n promptcrm svc/promptcrm 15433:1433
```

**Salida esperada:**

```
Forwarding from 127.0.0.1:15433 -> 1433

Forwarding from [::1]:15433 -> 1433
```

**DEJA ESTA TERMINAL ABIERTA** mientras quieras conectarte.

#### 5.2 Conectar desde SSMS

```
Server name:      tcp:127.0.0.1,15433

Authentication:   SQL Server Authentication

Login:            sa

Password:         AleeCR27
```

---
#### 5.5 Probar conectividad

En otra terminal PowerShell:

**Si usas minikube tunnel (puerto 1433):**

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 1433
```

**Si usas port-forward (puerto 15433):**

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 15433
```

**Salida esperada:**

```
ComputerName     : 127.0.0.1

RemoteAddress    : 127.0.0.1

RemotePort       : 15433

TcpTestSucceeded : True  ✅
```

---
## Paso 6: Crear la Base de Datos PromptCRM

  

### 6.1 Conectar desde SSMS

  

Usa las credenciales del paso anterior.

  

---

  

### 6.2 Ejecutar el script de migración

  

1. En SSMS, ve a: **File → Open → File**

2. Navega a: `C:\Users\abofi\OneDrive\MyStudio\Projects\Academic\PromptSales\promptSales-db1\databases\sqlserver\promptcrm\migrations\PromptCRM_v2_CORRECTED.sql`

3. Presiona **F5** para ejecutar

  

**Esto creará:**

- Base de datos `PromptCRM`

- Schema `[crm]`

- 51 tablas del sistema

  

**Tiempo estimado:** 10-30 segundos

  

---

  

### 6.3 Verificar que se crearon las tablas

  

```sql

USE PromptCRM;

GO

  

SELECT COUNT(*) AS TotalTablas

FROM INFORMATION_SCHEMA.TABLES

WHERE TABLE_SCHEMA = 'crm';

GO

```

  

**Resultado esperado:**

```

TotalTablas

-----------

51

```

  

---

  

## Paso 7: Conectar desde DBeaver (Para ver Diagramas)

  

### 7.1 Crear nueva conexión en DBeaver

  

1. Abre DBeaver

2. Click en **Database → New Database Connection**

3. Selecciona **SQL Server**

4. Click **Next**

  

---

  

### 7.2 Configurar conexión

  

**Si usas minikube tunnel (puerto 1433):**

```

Host:     localhost

Port:     1433

Database: PromptCRM

Authentication: SQL Server Authentication

Username: sa

Password: AleCR27!@#secure

```

  

**Si usas port-forward (puerto 15433):**

```

Host:     localhost

Port:     15433

Database: PromptCRM

Authentication: SQL Server Authentication

Username: sa

Password: AleCR27!@#secure

```

  

---

  

### 7.3 Configuraciones importantes

  

En la pestaña **Driver properties**, busca y configura:

  

```

trustServerCertificate = true

encrypt = false

```

  

**Importante:** SQL Server en Kubernetes usa certificados autofirmados.

  

---

  

### 7.4 Probar conexión

  

Click en **Test Connection**

  

**Debe mostrar:**

```

✅ Connected

```

  

Click en **Finish**.

  

---

  

### 7.5 Ver diagrama ER

  

1. En el navegador de DBeaver, expande: **PromptCRM → Schemas → crm → Tables**

2. Selecciona múltiples tablas (Ctrl+Click)

3. Click derecho → **View Diagram**

  

Ahora puedes ver las relaciones entre tablas.

  

---

  

## Paso 8: Exponer SQL Server a Radmin VPN (Para que tus compañeros accedan)

  

### 8.1 Obtener tu IP de Radmin VPN

  

```powershell

ipconfig | findstr "Radmin" -A 4

```

  

**Salida esperada:**

```

Adaptador de Ethernet Radmin VPN:

   Dirección IPv4. . . . : 25.10.0.X  ← Esta es tu IP

```

  

Anota tu IP.

  

---

  

### 8.2 Abrir puerto en Firewall de Windows

  

**Si usas port-forward al puerto 15433:**

```powershell

New-NetFirewallRule `

  -DisplayName "SQL Server K8s Port 15433" `

  -Direction Inbound `

  -Protocol TCP `

  -LocalPort 15433 `

  -Action Allow `

  -Profile Private,Domain

```

  

**Si usas minikube tunnel (puerto 1433):**

```powershell

New-NetFirewallRule `

  -DisplayName "SQL Server K8s Port 1433" `

  -Direction Inbound `

  -Protocol TCP `

  -LocalPort 1433 `

  -Action Allow `

  -Profile Private,Domain

```

  

---

  

### 8.3 Port-forward exponiendo en todas las interfaces

  

**IMPORTANTE:** Por defecto, `kubectl port-forward` solo escucha en `127.0.0.1` (localhost). Para que tus compañeros accedan desde Radmin, debes usar `--address 0.0.0.0`.

  

**Si usas puerto 15433:**

```powershell

kubectl port-forward `

  -n mssql `

  --address 0.0.0.0 `

  svc/mssql `

  15433:1433

```

  

**Si usas puerto 1433:**

```powershell

kubectl port-forward `

  -n mssql `

  --address 0.0.0.0 `

  svc/mssql `

  1433:1433

```

  

**Salida esperada:**

```

Forwarding from 0.0.0.0:15433 -> 1433

Forwarding from [::]:15433 -> 1433

```

  

**DEJA ESTA TERMINAL ABIERTA** mientras quieras que tus compañeros accedan.

  

---

  

### 8.4 Compartir credenciales con el equipo

  

Comparte esta información por Discord/Teams/WhatsApp:

  

**Si usas puerto 15433:**

```

IP Radmin:  25.10.0.X

Puerto:     15433

Usuario:    sa

Password:   AleCR27!@#secure

```

  

**Tus compañeros conectan desde su SSMS:**

```

Server:     tcp:25.10.0.X,15433

Login:      sa

Password:   AleCR27!@#secure

```

  

---

  

### 8.5 Verificar acceso remoto

  

Pide a un compañero que pruebe la conectividad desde su PC:

  

```powershell

Test-NetConnection -ComputerName 25.10.0.X -Port 15433

```

  

**Debe mostrar:**

```

TcpTestSucceeded : True  ✅

```

  

---

  

## Paso 9: Comandos Útiles de Mantenimiento

  

### Ver logs de SQL Server en tiempo real

  

```powershell

kubectl logs -n mssql mssql-0 -f

```

  

Presiona `Ctrl+C` para salir.

  

---

  

### Ver estado de todos los recursos

  

```powershell

kubectl get all,pvc,secret -n mssql

```

  

---

  

### Reiniciar SQL Server (sin perder datos)

  

```powershell

kubectl rollout restart statefulset -n mssql mssql

```

  

**Monitorear el reinicio:**

```powershell

kubectl rollout status statefulset -n mssql mssql

```

  

---

  

### Ejecutar queries desde kubectl (sin SSMS)

  

**Ver versión de SQL Server:**

```powershell

kubectl exec -n mssql mssql-0 -- /opt/mssql-tools18/bin/sqlcmd `

  -S localhost -U sa -P 'AleCR27!@#secure' -C `

  -Q "SELECT @@VERSION"

```

  

**Listar bases de datos:**

```powershell

kubectl exec -n mssql mssql-0 -- /opt/mssql-tools18/bin/sqlcmd `

  -S localhost -U sa -P 'AleCR27!@#secure' -C `

  -Q "SELECT name FROM sys.databases"

```

  

---

  

### Ver descripción completa del pod (para troubleshooting)

  

```powershell

kubectl describe pod -n mssql mssql-0

```

  

Busca la sección `Events:` al final para ver errores.

  

---

  

## Paso 10: Troubleshooting Común

  

### Problema 1: "minikube status" muestra componentes Stopped

  

**Diagnóstico:**

```powershell

minikube status

```

  

**Si ves:**

```

apiserver: Stopped

kubelet: Stopped

```

  

**Causa:** Tu PC hibernó o la IP del VM cambió.

  

**Solución:** Reiniciar Minikube desde cero.

```powershell

minikube stop

minikube delete --purge

minikube start --driver=hyperv --hyperv-virtual-switch "Default Switch" --kubernetes-version=v1.29.6 --container-runtime=containerd --cpus=4 --memory=6144 --disk-size=40g

```

  

Luego reaplica los manifests (Paso 4.2 y 4.3).

  

---

  

### Problema 2: Pod en estado CrashLoopBackOff

  

**Diagnóstico:**

```powershell

kubectl get pods -n mssql

```

  

**Si ves:**

```

NAME      READY   STATUS             RESTARTS

mssql-0   0/1     CrashLoopBackOff   5

```

  

**Ver logs:**

```powershell

kubectl logs -n mssql mssql-0 --tail=50

```

  

**Solución más común:** PVC corrupto. Eliminar y recrear:

  

```powershell

# 1. Eliminar StatefulSet

kubectl delete statefulset -n mssql mssql

  

# 2. Eliminar PVC (ESTO BORRA LOS DATOS)

kubectl delete pvc -n mssql mssql-data

  

# 3. Esperar 10 segundos

Start-Sleep -Seconds 10

  

# 4. Reaplicar manifests

kubectl apply -f C:\Users\abofi\OneDrive\MyStudio\Projects\Academic\PromptSales\promptSales-db1\k8s\MinikubeConfig\mssql.yaml

  

# 5. Monitorear

kubectl get pods -n mssql -w

```

  

---

  

### Problema 3: No puedo conectar desde SSMS

  

**Checklist:**

  

- [ ] ¿Minikube está corriendo?

  ```powershell

  minikube status

  ```

  

- [ ] ¿El pod está Running 1/1?

  ```powershell

  kubectl get pods -n mssql

  ```

  

- [ ] ¿El port-forward o minikube tunnel está activo?

  ```

  Debe haber una terminal con:

  "Forwarding from..." o "Tunnel successfully started"

  ```

  

- [ ] ¿El puerto está accesible?

  ```powershell

  Test-NetConnection -ComputerName 127.0.0.1 -Port 15433

  # TcpTestSucceeded debe ser True

  ```

  

- [ ] ¿Estás usando la sintaxis correcta?

  - ✅ `tcp:127.0.0.1,15433` (con COMA)

  - ✅ `127.0.0.1,15433`

  - ❌ `localhost:15433`

  - ❌ `127.0.0.1:15433` (con dos puntos)

  

---

  

### Problema 4: Error "bind: address already in use"

  

**Causa:** Ya hay algo corriendo en el puerto 15433.

  

**Solución 1 - Encontrar y matar el proceso:**

```powershell

# Ver qué está usando el puerto

netstat -ano | findstr :15433

  

# Anotar el PID (última columna)

# Matar el proceso (reemplaza 12345 con el PID real)

taskkill /PID 12345 /F

```

  

**Solución 2 - Usar otro puerto:**

```powershell

kubectl port-forward -n mssql svc/mssql 15434:1433

```

  

Ahora conecta a `127.0.0.1,15434`

  

---

  

### Problema 5: Los compañeros no pueden conectarse via Radmin

  

**Diagnóstico desde la PC del compañero:**

```powershell

Test-NetConnection -ComputerName 25.10.0.X -Port 15433

# TcpTestSucceeded : False ❌

```

  

**Posibles causas y soluciones:**

  

1. **Firewall bloqueando:**

   ```powershell

   # En tu PC, verificar regla

   Get-NetFirewallRule -DisplayName "SQL Server K8s Port 15433"

  

   # Si no existe, crearla (Paso 8.2)

   ```

  

2. **Port-forward sin --address 0.0.0.0:**

   ```powershell

   # Debe estar corriendo con 0.0.0.0, NO solo 127.0.0.1

   kubectl port-forward -n mssql --address 0.0.0.0 svc/mssql 15433:1433

   ```

  

3. **Radmin VPN desconectada:**

   ```powershell

   # Verificar conexión

   ipconfig | findstr "Radmin"

   ```

  

4. **IP incorrecta compartida:**

   ```powershell

   # Obtener IP correcta de Radmin

   ipconfig | findstr "Radmin" -A 4

   ```

  

---

  

## Resumen de Comandos Diarios

  

### Inicio de sesión (cada día)

  

**Opción A: Con minikube tunnel**

```powershell

# Terminal 1 (como Administrador)

minikube tunnel

  

# Dejar abierta

```

  

**Opción B: Con port-forward**

```powershell

# Terminal 1 (normal)

kubectl port-forward -n mssql svc/mssql 15433:1433

  

# Dejar abierta

```

  

**Conectar desde SSMS:**

- Opción A: `127.0.0.1,1433`

- Opción B: `tcp:127.0.0.1,15433`

- Usuario: `sa`

- Password: `AleCR27!@#secure`

  

---

  

### Verificación rápida del clúster

  

```powershell

# Estado de Minikube

minikube status

  

# Estado del pod

kubectl get pods -n mssql

  

# Estado de todos los recursos

kubectl get all,pvc -n mssql

```

  

---

  

### Exponer a Radmin (cuando trabajas con el equipo)

  

```powershell

# Terminal dedicada

kubectl port-forward -n mssql --address 0.0.0.0 svc/mssql 15433:1433

  

# Dejar abierta

  

# Compartir con el equipo:

# IP: 25.10.0.X (tu IP de Radmin)

# Puerto: 15433

# Usuario: sa

# Password: AleCR27!@#secure

```

  

---

  

## Próximos Pasos

  

1. ✅ Clúster Minikube levantado

2. ✅ SQL Server 2022 desplegado

3. ✅ Base de datos PromptCRM creada (51 tablas)

4. ✅ Conexión desde SSMS y DBeaver

5. ⏳ Ejecutar script de generación de datos (500K leads)

6. ⏳ Probar consultas y rendimiento

7. ⏳ Documentar queries útiles para el equipo

  

---

  

## Recursos Adicionales

  

- [Cómo conectarse - Guía completa](COMO-CONECTARSE-SQLSERVER.md)

- [Solución a problemas comunes](SOLUCION-PROBLEMA-SQLSERVER.md)

- [Networking y despliegue explicado](NETWORKING-Y-DESPLIEGUE-SQLSERVER.md)

- [README principal del proyecto](README.md)

- [Tutorial completo de Ale](k8s/sqlserver/promptcrm/Ale-legacy/README.md)

  

---

  

**Estado:** ✅ Tutorial completo y validado

**Última actualización:** 2025-11-15

  

¡Bienvenido al equipo de PromptCRM! 🚀