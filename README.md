# PromptSales – Guía de despliegue colaborativo

Este README resume los pasos que cada integrante del equipo debe seguir para **levantar su stack local de PromptSales** según el caso #2. Incluye la puesta en marcha del clúster Kubernetes (Minikube), la construcción del servidor MCP (PromptContent) y la habilitación de las bases de datos asignadas a cada subequipo (MongoDB, Postgres/pgvector y SQL Server).

> **Contexto:** PromptSales está compuesto por PromptContent, PromptAds y PromptCrm. Cada subempresa utiliza un motor diferente: PromptContent depende de MongoDB + pgvector, mientras que PromptAds/PromptCrm consumen SQL Server. Esta guía permite que cualquier miembro reproduzca el entorno y exponga su servicio a los demás via VPN.

---

## 1. Prerrequisitos comunes

- Windows 11 con **Hyper-V** habilitado.
- **VPN corporativa** (Radmin u otra) conectada *antes* de iniciar Minikube para que el nodo quede en la misma red que el resto del equipo.
- Herramientas instaladas:
  - [Minikube ≥ v1.37](https://minikube.sigs.k8s.io/docs/start/)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - Registro de contenedores (GHCR recomendado) para recibir imágenes publicadas por CI/CD.
- Repositorio clonado:
  ```powershell
  git clone <repo-url> && cd promptSales-db1
  ```

---

## 2. Inicializar Minikube y utilidades

```powershell
minikube start `
  --driver=hyperv `
  --hyperv-virtual-switch "Default Switch" `
  --kubernetes-version=v1.29.6 `
  --container-runtime=containerd `
  --cpus=4 --memory=6144 --disk-size=40g

minikube addons enable metrics-server
```

Si el equipo entra en suspensión y el nodo cambia de IP, la forma más sencilla de recuperarse es `minikube stop && minikube delete --purge` seguido de `minikube start ...` y reaplicar los manifests.

---

## 3. Servidor PromptContent

1. **Imagen desde GHCR vía CI/CD** (sin Docker local):
   - El pipeline `.github/workflows/promptcontent.yml` construye con Buildah y publica en `ghcr.io/<org>/promptcontent:<sha>`.
   - El Deployment apunta a GHCR y `imagePullPolicy: Always`; puedes fijar una etiqueta específica con `kubectl set image` si necesitas probar una versión.
2. **Recursos base** (namespace, ConfigMap y Secret) – todos los miembros deben ejecutarlos igual:
   ```powershell
   kubectl apply -f k8s/promptcontent/namespace.yaml
   kubectl apply -f k8s/promptcontent/configmap.yaml
   # Copia k8s/promptcontent/secrets.placeholders.yaml, rellénalo y aplícalo:
   kubectl -n promptcontent-dev apply -f <tu-secret>.yaml
   ```
   - `MONGODB_URI`, `PGVECTOR_DSN`, etc. apuntan a la base que te corresponda (ver secciones siguientes).
3. **Despliegue + HPA + Services**:
   ```powershell
   kubectl apply -f k8s/promptcontent/
   kubectl -n promptcontent-dev rollout status deployment/promptcontent-deploy --timeout=120s
   ```
4. **Checks**:
   ```powershell
   kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080
   # En otra terminal
   curl http://localhost:8080/healthz
   curl http://localhost:8080/readyz
   ```
   Los campos `mongoConnected` y `pgConnected` deben cambiar a `true` cuando tus conexiones estén bien configuradas.

---

## 4. Bases de datos por subequipo

Cada equipo puede optar por **(A)** exponer su instancia local a Kubernetes mediante `host.minikube.internal` (abrir el puerto y ajustar el firewall) o **(B)** desplegar el motor dentro del clúster usando los manifiestos de `k8s/MinikubeConfig`. A continuación se resumen ambos caminos.

### 4.1 MongoDB (PromptContent)

#### A) Reutilizar tu Mongo local
1. Edita `mongod.cfg` y establece `bindIp: 0.0.0.0`.
2. Reinicia el servicio `MongoDB` y abre el puerto 27017:
   ```powershell
   New-NetFirewallRule -DisplayName "Mongo 27017" -Direction Inbound -Protocol TCP -LocalPort 27017 -Action Allow
   ```
3. Verifica desde Minikube:
   ```powershell
   minikube ssh "timeout 5 bash -c 'cat </dev/null >/dev/tcp/host.minikube.internal/27017'"
   ```
4. En tu secreto usa `MONGODB_URI=mongodb://host.minikube.internal:27017/<tuDB>`.

#### B) Mongo dentro del clúster
1. Aplica los manifiestos preparados:
   ```powershell
   kubectl apply -f k8s/MinikubeConfig/mongo/mongo-secret.yaml
   kubectl apply -f k8s/MinikubeConfig/mongo/mongo-svc.yaml
   ```
   Esto crea un `StatefulSet`, un PVC y un `Service` tipo LoadBalancer (`mongodb.mongo.svc` + IP externa cuando corra `minikube tunnel`).
2. Consigue la IP/puerto:
   ```powershell
   minikube tunnel
   kubectl -n mongo get svc mongodb -o wide
   ```
3. Ajusta `MONGODB_URI` con `mongodb://root:<pass>@mongodb.mongo.svc.cluster.local:27017/<tuDB>` o la IP externa.

### 4.2 Postgres + pgvector (PromptContent)

Tienes manifests listos en `k8s/MinikubeConfig/postgres/`.

```powershell
kubectl apply -f k8s/MinikubeConfig/postgres/psql-pv.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/psql-claim.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/postgres-configmap.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/postgresService.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/ps-deployment.yaml
```

- El Deployment usa `ankane/pgvector:latest` con credenciales del ConfigMap (`postgres/postgres` por defecto).
- Obtén la IP:
  ```powershell
  minikube tunnel
  kubectl -n promptcontent-dev get svc postgres-service -o wide
  ```
- Configura el secreto del MCP con:
  ```
  PGVECTOR_DSN=postgres://postgres:postgres@postgres-service.promptcontent-dev.svc.cluster.local:5432/promptcontent
  PGVECTOR_TABLE=content_embeddings
  PGVECTOR_DIM=128
  ```
  (Ajusta usuario/contraseña si los cambias en el ConfigMap.)

### 4.3 SQL Server (PromptAds / PromptCrm)

Para quienes trabajan los módulos que dependen de SQL Server:

```powershell
kubectl create namespace mssql
kubectl apply -f k8s/MinikubeConfig/mssql/mssql-secret.yaml   # Cambia la contraseña antes
kubectl apply -f k8s/MinikubeConfig/mssql/mssql.yaml
```

- Se despliega un `StatefulSet` con volumen persistente y `Service` tipo LoadBalancer (`mssql.mssql.svc`).
- Exponer el puerto:
  ```powershell
  minikube tunnel
  kubectl -n mssql get svc mssql -o wide
  ```
- Conecta tu aplicación (PromptAds o PromptCrm) usando una cadena como:
  ```
  Server=mssql.mssql.svc.cluster.local,1433;
  User ID=sa;
  Password=<tu SA_PASSWORD>;
  TrustServerCertificate=true;
  ```
- Si necesitas ejecutar migraciones o ETLs, toma como base los placeholders en `k8s/sqlserver/`.

---

## 5. Exponer servicios a la VPN

### LoadBalancer (recomendado)
1. Mantén `minikube tunnel` activo.
2. Consulta la IP externa del servicio:
   ```powershell
   kubectl -n promptcontent-dev get svc promptcontent-svc-prod -o wide
   ```
3. Comparte `http://<IP>:80/readyz` con tus compañeros (o define un registro DNS interno).

### Port-forward abierto
Si solo necesitas exponer algún endpoint puntual:
```powershell
New-NetFirewallRule -DisplayName "PromptContent 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
kubectl -n promptcontent-dev port-forward --address 0.0.0.0 svc/promptcontent-svc 8080:8080
```
El túnel permanece abierto mientras la terminal siga activa.

---

## 6. Validaciones y troubleshooting rápido

| Problema | Diagnóstico | Fix |
|----------|-------------|-----|
| `apiserver: Stopped` en `minikube status` | IP del VM cambió o el host hibernó | `minikube stop && minikube delete --purge && minikube start ...` |
| `/readyz` muestra `mongoConnected:false` | Puerto 27017 cerrado o credenciales incorrectas | Abre el firewall / usa `host.minikube.internal` / revisa `kubectl -n promptcontent-dev logs deploy/promptcontent-deploy` |
| `PGVECTOR_DSN` falla | ConfigMap y secreto desalineados | Usa la misma combinación usuario/pass en ambos, reinicia el deployment (`kubectl -n promptcontent-dev rollout restart deployment/promptcontent-deploy`) |
| SQL Server no asigna IP externa | Falta `minikube tunnel` o firewall bloquea 1433 | Ejecuta el túnel y revisa `kubectl -n mssql get svc mssql -o wide`; abre el puerto 1433 en Windows si expones vía port-forward |

---

## 7. Próximos pasos

- Automatizar despliegues con el workflow `.github/workflows/promptcontent.yml` agregando `KUBE_CONFIG` y credenciales de registro si publican imágenes en GHCR u otro registro compatible.
- Completar los manifests pendientes bajo `k8s/sqlserver/` y `k8s/mongodb/` para cada microservicio MCP adicional (PromptAds, PromptCrm).
- Documentar los datos de prueba (`databases/**/schemas/*.json`) para que el equipo pueda poblar sus motores de forma consistente.

Con esta guía cada integrante puede arrancar su entorno, conectar la base que le corresponda y compartir el servicio a través de la VPN.
