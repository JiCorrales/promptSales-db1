CONFIGURACION PARA DESPLEGAR LAS BASES

Se usa Minikube con driver Hyper-V; es necesario instalar "kubectl".

Iniciar minikube:
> minikube start --driver=hyperv --hyperv-virtual-switch "Default Switch"

Primero crear el namespace:
> kubectl create namespace mssql
> kubectl create namespace postgres
> kubectl create namespace mongo 

Se pueden crear los archivos con:
> nano nombre_archivo.yaml

Aplicar los archivos:
> kubectl apply -f nombre_archivo.yaml

Para las conexiones:

| Motor          | Host             | Puerto | Usuario    | Contraseña       |
| -------------- | ---------------- | ------ | ---------- | ---------------- |
| **Postgres**   | `localhost`      | 5432   | `User`     | *(la tuya)*      |
| **SQL Server** | `127.0.0.1,1433` | 1433   | `sa`       | *(de tu secret)* |

Para que funcionen los servicios LoadBalancer tiene que estar corriendo:
> minikube tunnel
