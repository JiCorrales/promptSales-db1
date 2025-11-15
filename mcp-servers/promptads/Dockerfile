# Imagen base ligera con Node.js
FROM node:20-alpine

# Carpeta de trabajo dentro del contenedor
WORKDIR /app

# Copiamos package.json y package-lock.json (si existe)
COPY package.json ./

# Instalamos dependencias (solo producción)
RUN npm install --omit=dev

# Copiamos el resto del código
COPY server.js ./

# Exponemos el puerto que usa nuestro servidor
EXPOSE 8080

# Comando por defecto al iniciar el contenedor
CMD ["npm", "start"]
