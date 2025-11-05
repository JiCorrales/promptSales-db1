CONFIGURACION PARA DESPLEGAR LAS BASES 

Se usa la imagen de minikube en docker, es nesesario instalar "kubectl"

Iniciar minikube:
> minikube start

Primero crear el namespace:
> kubectl create namespace mssql/postgres/mongo

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

