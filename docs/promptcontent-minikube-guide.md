# PromptContent – Guía de despliegue Minikube/VPN

Guía reproducible para que cualquier integrante del equipo levante el servidor MCP **PromptContent** en su propia máquina (Windows + Hyper-V) y lo exponga a otros miembros de la VPN (p. ej. Radmin). Los pasos contemplan bases de datos externas (cada quien puede apuntar a su instancia de MongoDB/Postgres).

---

## 0. Requisitos previos

- **Windows 11** con Hyper-V habilitado y privilegios de administrador.
- **VPN** (Radmin) conectada antes de iniciar Minikube para que el nodo obtenga una IP dentro de la red compartida.
- **Herramientas CLI** instaladas en el host:
  - [Minikube ≥ v1.37](https://minikube.sigs.k8s.io/docs/start/)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) (solo para la build local)
  - PowerShell 7+ (recomendado)
- **Bases de datos accesibles**:
  - *MongoDB*: puede ser local o remota. Debe aceptar conexiones desde la IP del nodo Minikube (usa `host.minikube.internal` cuando sea tu propia máquina).
  - *Postgres + pgvector* (opcional): mismo criterio.

> Consejo: crea un directorio de trabajo limpio y clona este repositorio antes de seguir (`git clone <repo>`).

---

## 1. Preparar las bases de datos

### MongoDB
1. Edita el archivo `mongod.cfg` (en Windows suele estar en `C:\Program Files\MongoDB\Server\<version>\bin\mongod.cfg`).
2. En la sección `net`, habilita escucha externa:
   ```yaml
   net:
     port: 27017
     bindIp: 0.0.0.0
   ```
3. Reinicia el servicio `MongoDB`.
4. Abre el puerto en el firewall (ejemplo):
   ```powershell
   New-NetFirewallRule -DisplayName "Mongo 27017" -Direction Inbound -Protocol TCP -LocalPort 27017 -Action Allow
   ```
5. Verifica desde Minikube (después de iniciarlo) con:
   ```powershell
   minikube ssh "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/host.minikube.internal/27017' && echo reachable"
   ```

### Postgres + pgvector (opcional)
1. Asegúrate de tener la extensión `pgvector` instalada y la tabla de embeddings creada.
2. Abre el puerto 5432 y permite conexiones desde el rango de la VPN o desde `host.minikube.internal`.
3. Construye una cadena de conexión `postgres://usuario:password@host:5432/basedatos?sslmode=<opcional>`.

---

## 2. Arrancar Minikube

```powershell
minikube start `
  --driver=hyperv `
  --hyperv-virtual-switch "Default Switch" `
  --kubernetes-version=v1.29.6 `
  --container-runtime=containerd `
  --cpus=4 --memory=6144 --disk-size=40g

minikube addons enable metrics-server
```

> Si la IP del nodo cambia tras suspender la laptop, es más fácil borrar y recrear el cluster (`minikube delete --purge` + `minikube start`) que parchar manualmente los manifests del control plane.

---

## 3. Construir la imagen dentro del cluster

En la raíz del repo:

```powershell
minikube image build -t promptcontent:local .\mcp-servers\promptcontent
```

Esto carga la imagen en el runtime `containerd` interno, de modo que no dependemos de un registro externo.

---

## 4. Configurar variables y secretos

1. Crea el namespace y los recursos base:
   ```powershell
   kubectl apply -f k8s/promptcontent/namespace.yaml
   kubectl apply -f k8s/promptcontent/configmap.yaml
   ```
2. Copia `k8s/promptcontent/secrets.placeholders.yaml` a un archivo personalizado *(no lo subas al repo si contiene credenciales reales)*. El formato esperado:

   | Clave               | Descripción                                                                                | Ejemplo                                       |
   |---------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------|
   | `MONGODB_URI`       | URI completa (`mongodb://user:pass@host:puerto/db`). Usa `host.minikube.internal` para local | `mongodb://host.minikube.internal:27017/promptContent` |
   | `MONGODB_DB_NAME`   | Nombre de la DB principal                                                                  | `promptContent`                                |
   | `PGVECTOR_DSN`      | Cadena Postgres (solo si usarás embeddings)                                               | `postgres://postgres:postgres@host:5432/promptcontent` |
   | `PGVECTOR_TABLE`    | Tabla con columna `vector`                                                                 | `content_embeddings`                           |
   | `PGVECTOR_DIM`      | Dimensión de los vectores                                                                  | `128`                                          |

3. Aplica tu archivo:
   ```powershell
   kubectl -n promptcontent-dev apply -f <tu-archivo-de-secretos>.yaml
   ```

---

## 5. Desplegar los manifests

```powershell
kubectl apply -f k8s/promptcontent/
```

Esto crea Deployment, Services (`ClusterIP` + `LoadBalancer`), HPA, ConfigMap y Secret (si usaste el placeholder).

---

## 6. Validar el despliegue

```powershell
kubectl -n promptcontent-dev get pods
kubectl -n promptcontent-dev rollout status deployment/promptcontent-deploy --timeout=120s
kubectl -n promptcontent-dev get svc
kubectl -n promptcontent-dev get hpa
```

Para comprobar la salud:

```powershell
kubectl -n promptcontent-dev port-forward svc/promptcontent-svc 8080:8080
# En otra terminal:
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

`mongoConnected` / `pgConnected` deben quedar en `true` cuando las credenciales sean correctas.

---

## 7. Compartir el servicio con la VPN

### Opción A – LoadBalancer con `minikube tunnel`

```powershell
minikube tunnel
kubectl -n promptcontent-dev get svc promptcontent-svc-prod -o wide
```

El campo `EXTERNAL-IP` (ej. `10.108.157.26`) será accesible para cualquiera dentro de la misma VPN en el puerto 80 (`http://IP/readyz`). Debes mantener el túnel corriendo.

### Opción B – Port-forward abierto

```powershell
New-NetFirewallRule -DisplayName "PromptContent 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
kubectl -n promptcontent-dev port-forward --address 0.0.0.0 svc/promptcontent-svc 8080:8080
```

Mientras el comando esté activo, otros podrán usar `http://<tu-IP-VPN>:8080/readyz`.

---

## 8. Pruebas de carga / HPA (opcional)

1. Con el port-forward activo, ejecuta:
   ```powershell
   node .\mcp-servers\promptcontent\scripts\load-test.js
   ```
2. Observa el autoscaler:
   ```powershell
   kubectl -n promptcontent-dev get hpa -w
   ```

---

## 9. Problemas frecuentes

| Síntoma | Causa común | Solución |
|--------|-------------|----------|
| `minikube status` muestra `apiserver: Stopped` | El VM cambió de IP tras suspender el host | `minikube stop`, `minikube delete --purge`, `minikube start ...` y vuelve a aplicar los manifests |
| `/readyz` devuelve `mongoConnected:false` | Puerto 27017 bloqueado o credenciales erróneas | Revisa firewall, usa `host.minikube.internal`/`timeout 5 bash -c 'cat </dev/null >/dev/tcp/...'` para testear |
| HPA sin métricas (`<unknown>/60%`) | Falta `metrics-server` | `minikube addons enable metrics-server` y espera unos minutos |
| `ImagePullBackOff` | Imagen no existe | Reconstruye con `minikube image build ...` o usa la etiqueta del registro oficial |

---

Con estos pasos cada miembro del equipo puede levantar PromptContent, conectarlo a sus propias bases y exponerlo por la VPN para pruebas compartidas. Mantén tus secretos fuera del repositorio y actualiza las variables cuando cambie la infraestructura.
