# Deployment de PromptContent en Kubernetes/Minikube

Este directorio contiene los manifests y pipeline para desplegar el servidor MCP `PromptContent` con probes de salud, escalado automático (HPA) y configuración por `ConfigMap`/`Secret`.

## Requisitos
- Kubernetes 1.24+ o Minikube (>= v1.30)
- `kubectl` configurado contra el cluster
- En Minikube: habilitar `metrics-server` para HPA
  - `minikube addons enable metrics-server`
- Registro de contenedores (GHCR recomendado) accesible desde el cluster

## Opciones de ambiente
- Local (Minikube):
  - CPU/RAM mínimas: `--cpus=2 --memory=2g --disk-size=20g`
  - Las imágenes se obtienen desde GHCR; no se requiere Docker local.
  - Usa `kubectl apply -f ./k8s/` y verifica probes con `/readyz`.
- Cluster compartido (VPN):
  - Al menos 3 nodos (1 master, 2 workers)
  - El pipeline CI/CD publica en GHCR con Buildah y actualiza la imagen del Deployment.

## Variables de entorno (ConfigMap/Secret)
- `ConfigMap` (`promptcontent-config`): `PC_DEFAULT_CHANNELS`, `PC_HASHTAG_COUNT`, `PC_MOODBOARD_MAX`, `PC_KEYWORD_MAX`, `PC_MESSAGE_TEMPLATES`
- `Secret` (`promptcontent-secrets`): `MONGODB_URI`, `MONGODB_DB_NAME`, `PGVECTOR_DSN`, `PGVECTOR_TABLE`, `PGVECTOR_DIM`
  - Reemplaza los placeholders con tus valores reales o usa helm/`kubectl apply -f` con un archivo propio.

## Despliegue en un solo comando
- Ejecuta: `kubectl apply -f ./k8s/`
- (CI) La imagen se construye con Buildah y se publica en `ghcr.io/<org>/promptcontent:<sha>`.
  - Crea `Namespace`, `Deployment` (2 réplicas), `Service` (ClusterIP), `HPA` y `Secrets` placeholder.
  - Para producción, hay un `Service` tipo `LoadBalancer` (`service-prod.yaml`). En Minikube: `minikube service promptcontent-svc-prod --url`.

## Health checks (probes)
- `livenessProbe`: `GET /healthz` en puerto 8080
- `readinessProbe`: `GET /readyz` en puerto 8080
- Prueba localmente (port-forward):
  - `kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080`
  - `curl http://localhost:8080/healthz`

## CI/CD (GitHub Actions)
- Workflow: `.github/workflows/promptcontent.yml`
  - Build & push a GHCR: `ghcr.io/<owner>/promptcontent`
  - Trivy: escaneo de vulnerabilidades de la imagen
  - Deploy: `kubectl apply -f k8s/` y `set image` con el SHA
- Secrets requeridos:
  - `KUBE_CONFIG`: contenido del kubeconfig del cluster dev
  - (Opcional) `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` si usas Docker Hub

## Pruebas de validación
- Pods Running:
  - `kubectl -n promptcontent-dev get pods`
- Conectividad:
  - `kubectl -n promptcontent-dev get svc`
  - `kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080`
  - `curl http://localhost:8080/readyz`
- Escalado automático (HPA):
  - `kubectl -n promptcontent-dev get hpa`
  - Genera carga (simulada) y observa `CURRENT/ TARGET`
- Persistencia (si aplica):
  - Verifica conexión a Mongo/Postgres con `/healthz` (`mongoConnected`, `pgConnected`)

## Troubleshooting
- `ImagePullBackOff`: verifica que la imagen existe y credenciales de registro (GHCR/Docker Hub)
- `HPA` no escala: habilita `metrics-server` y espera unos minutos para que aparezcan métricas
- `readiness` falla: revisa logs `kubectl -n promptcontent-dev logs deploy/promptcontent-deploy`
- Secret inválido: actualiza `promptcontent-secrets` y reinicia: `kubectl -n promptcontent-dev rollout restart deployment/promptcontent-deploy`

## Comandos básicos de gestión
- `kubectl -n promptcontent-dev get all`
- `kubectl -n promptcontent-dev describe deploy/promptcontent-deploy`
- `kubectl -n promptcontent-dev scale deploy/promptcontent-deploy --replicas=3`
- `kubectl -n promptcontent-dev rollout restart deployment/promptcontent-deploy`
