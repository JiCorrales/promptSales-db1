# PromptContent – Guía rápida solo Minikube (sin Docker)

Esta guía resume los pasos mínimos para levantar PromptContent MCP en **Minikube** en Windows, sin usar Docker Desktop. Para más detalle, consulta `docs/promptcontent-minikube-guide.md`.

## 1) Prerrequisitos
- Windows 11 con Hyper‑V (recomendado) o driver Docker instalado.
- `kubectl` y `minikube` instalados.
- Habilitar métricas para HPA:
  ```powershell
  minikube addons enable metrics-server
  ```

## 2) Arrancar Minikube (Hyper‑V)
```powershell
minikube start --driver=hyperv --cpus=2 --memory=2g --disk-size=20g
kubectl cluster-info
kubectl get nodes
```

## 3) Desplegar bases en Minikube (opcional)
Si usarás Postgres/pgvector dentro de Minikube:
```powershell
kubectl apply -f k8s/MinikubeConfig/postgres/psql-pv.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/psql-claim.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/postgres-configmap.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/postgresService.yaml
kubectl apply -f k8s/MinikubeConfig/postgres/ps-deployment.yaml
```
Para obtener IP/puerto externo (si lo necesitas):
```powershell
minikube tunnel
kubectl -n promptcontent-dev get svc postgres-service -o wide
```
Si usarás Mongo dentro de Minikube, consulta `k8s/MinikubeConfig/mongo/` y aplica los manifests correspondientes.

## 4) Configurar PromptContent (namespace, ConfigMap, Secret)
```powershell
kubectl apply -f namespace-promptcontent-dev.yaml  # o k8s/promptcontent/namespace.yaml
kubectl apply -f k8s/promptcontent/configmap.yaml
```

Edita `k8s/promptcontent/secrets.local.yaml` con tus valores reales y aplícalo:
```powershell
kubectl apply -f k8s/promptcontent/secrets.local.yaml
```
Variables clave (en `stringData` del Secret):
- `MONGODB_URI`: cadena de conexión (p. ej. `mongodb://host.minikube.internal:27017/promptContent`)
- `MONGODB_DB_NAME`: nombre de la BD (p. ej. `promptContent`)
- `PGVECTOR_DSN`: `postgres://<user>:<pass>@<host>:5432/promptcontent`
- `PGVECTOR_TABLE`: `content_embeddings`
- `PGVECTOR_DIM`: `128`
- `API_KEY`: `devlocal` (para pruebas)
- `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`: credenciales Client Credentials

## 5) Permitir egress (si tu clúster lo restringe)
```powershell
kubectl apply -f k8s/promptcontent/networkpolicy-egress.yaml
```
Permite salida a Internet (HTTP/HTTPS) y hacia Postgres/Mongo.

## 6) Desplegar PromptContent
```powershell
kubectl apply -f k8s/promptcontent/
kubectl -n promptcontent-dev rollout status deployment/promptcontent-deploy --timeout=120s
kubectl -n promptcontent-dev get pods
kubectl -n promptcontent-dev get svc
```

## 7) Exponer el servicio y verificar
Port‑forward local:
```powershell
kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080
```
Salud:
```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```
`readyz` debe mostrar conexiones OK (`mongoConnected`, `pgConnected`) cuando las credenciales sean correctas.

## 8) Pruebas rápidas
- Importar contenido externo (Spotify):
  ```bash
  curl -X POST http://localhost:8080/external/spotify/import \
       -H "Authorization: Bearer devlocal" \
       -H "Content-Type: application/json" \
       -d '{"q":"rock","limit":20}'
  ```
- Generar contenido MCP:
  ```bash
  curl -X POST http://localhost:8080/mcp/getContent \
       -H "Authorization: Bearer devlocal" \
       -H "Content-Type: application/json" \
       -d '{"description":"Campaña juvenil de música rock alternativa con estética vintage y tonos rojos","keywords":["rock","vintage","juvenil","alternativa"],"channels":["instagram","tiktok"],"aspectRatio":"4:5","moodboardCount":3}'
  ```

## 9) Compartir por VPN (opcional)
Si usas Radmin VPN:
```powershell
kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080 --address <TU_IP_RADMIN>
```

## Referencias
- Detalle completo: `docs/promptcontent-minikube-guide.md`
- Variables de entorno: `k8s/promptcontent/configmap.yaml` y `k8s/promptcontent/secrets.*.yaml`
- Bases (Minikube): `k8s/MinikubeConfig/`

