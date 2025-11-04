**SolidNY** es una empresa con sede en Nueva York y más de 15 años de experiencia en **mercadeo digital**. Con el objetivo de expandir su alcance y aprovechar el potencial de la **inteligencia artificial (IA)**, lanza una nueva marca llamada **PromptSales**, enfocada en **cerrar ventas de manera eficiente, medible y automatizada**.

El éxito de PromptSales se mide principalmente por la **cantidad y el valor de las ventas logradas**, gracias a una combinación estratégica de **automatización, análisis de datos e IA aplicada en todas las etapas del embudo de ventas**.

---
## Ecosistema de Subempresas

PromptSales está compuesto por un conjunto de subempresas interconectadas, cada una especializada en una fase distinta del proceso de mercadeo y ventas. Aunque pueden operar de forma independiente, todas se integran en un **flujo automatizado** que abarca desde la creación de contenido hasta el cierre de la venta.

### PromptContent

Genera contenido creativo para campañas de mercadeo. Sus principales funciones incluyen:

- Creación de **contenido textual, audiovisual e imágenes** para redes sociales, anuncios y sitios web.
- Producción de materiales **optimizados para motores de búsqueda** y **respuestas de IA**.
- Uso de **herramientas propias de inteligencia artificial** para crear contenido adaptable a distintos públicos meta.
- **Integración** con plataformas externas como **Canva, Adobe, Meta Business Suite y OpenAI API**.  
### PromptAds
  
Se encarga de la **ejecución y optimización** de campañas publicitarias. Entre sus tareas principales:

- **Diseño, segmentación y publicación** de anuncios en redes sociales, email marketing, SMS, LinkedIn e influencers.
- **Monitoreo en tiempo real** del rendimiento de campañas.
- **Generación automática de campañas** a partir de datos de público meta y objetivos de venta.
- Integración con **Google Ads, Meta Ads, TikTok for Business, Mailchimp** y plataformas de CRM.
### PromptCrm

Administra el **seguimiento de clientes potenciales** y los procesos de cierre de ventas:

- **Registro y clasificación automática** de leads provenientes de diversas fuentes.
- Implementación de **chatbots, voicebots y flujos automatizados** de atención al cliente.
- **Predicción de intención de compra** mediante IA.
- Integración con **HubSpot, Salesforce, Zendesk, WhatsApp Business API**, entre otros.

---
## Portal Web Unificado

El portal central de **PromptSales** actúa como **centro de control** donde mercadólogos y agentes de ventas gestionan todas las operaciones del ecosistema. Desde esta interfaz se diseñan estrategias completas que abarcan campañas, contenido, audiencias, medios y tiempos.

### Principales Funcionalidades

- **Diseño de estrategias personalizadas:** permite definir mensajes, públicos meta, intenciones, productos y países objetivo.  
- **Automatización supervisada:** la IA genera campañas, contenido y sugerencias que deben ser aprobadas por personal autorizado.  
- **Agenda inteligente:** cada campaña cuenta con un calendario automatizado con recordatorios y revisión de entregables.  
- **Integración completa:** conexión con las tres subempresas y servicios externos (CRM, redes sociales, anuncios, analítica).  
- **Panel de analítica avanzada:** reportes en tiempo real de desempeño, conversión, inversión y retorno.  
- **Gestión de suscripciones:** planes por subempresa o ecosistema integrado.

---
## Datos e Integraciones Clave

El ecosistema depende del intercambio constante de información entre módulos y servicios:

- **Clientes:** datos empresariales, productos, presupuestos y contactos.  
- **Campañas:** mensajes, medios, tiempos, métricas y presupuestos.  
- **Contenido:** materiales creados, formatos, versiones y derechos de uso.  
- **Interacciones:** historial de leads, respuestas automáticas y comportamiento de usuario.  
- **Integraciones:** autenticaciones y sincronización vía API.  
- **IA:** generación de contenido, predicción de compras, optimización de anuncios y análisis de sentimiento.

---
## Visión Técnica

- Las subempresas **PromptContent**, **PromptAds** y **PromptCrm** estarán interconectadas mediante **servidores MCP (Model Context Protocol)**.  
- El **despliegue e infraestructura** se gestionará con **Kubernetes**, asegurando escalabilidad y alta disponibilidad.  
- Las integraciones externas se implementarán vía **APIs REST** o **MCP**, según el nivel de automatización requerido.  
- Los **paneles administrativos y aplicaciones web** se desplegarán en **Vercel** con frameworks como **Next.js y React**.  
- Se empleará una **base de datos Redis en la nube** para cache y resultados temporales, reduciendo llamadas a APIs y optimizando rendimiento.

---
## Requerimientos No Funcionales

### Rendimiento

- Tiempo de respuesta del portal: **≤ 2.5 segundos**.  
- Resultados cacheados en Redis: **≤ 400 ms**.  
- Generación automática de contenido: **≤ 7 s (simple)** / **≤ 20 s (complejo)**.

### Escalabilidad

- Capacidad para escalar **10x sin degradación**.  
- Autoescalado con Kubernetes basado en CPU, memoria y concurrencia.  
- Manejo de **5000 campañas activas** y **300 usuarios simultáneos**.

### Tolerancia a Fallos

- **Disponibilidad mínima:** 99.9% mensual.  
- **Reinicio automático** de contenedores críticos.  
- **Replicación y failover** en Redis y bases de datos.  
- **Backups diarios** con retención de 30 días.

### Seguridad

- Autenticación con **OAuth 2.0**.  
- Cifrado **TLS 1.3** en tránsito y **AES-256** en reposo.  
- Auditoría centralizada (retención 90 días).  
- Cumplimiento de **GDPR** y **CCPA** con políticas de acceso mínimo.

---
# Actividades del Proyecto

## 1. Diseño de Bases de Datos
  
- **Redis:** cache y resultados temporales.  
- **PromptContent (MongoDB):** colecciones para imágenes, descripciones, hashtags y logs.  
- **PromptAds (SQL Server):** tablas para campañas, canales, mercados y métricas.  
- **PromptCrm (SQL Server):** tablas de clientes, leads, interacciones y ventas.  
- **PromptSales (PostgreSQL):** datos centralizados, métricas y estado de campañas.

## 2. Scripts de Llenado de Datos

### PromptContent

- Cargar **50+ imágenes** con descripciones y hashtags.  
- Indexar descripciones con **Pinecone, Faiss o pgvector**.  
- Conectar una **API real** con autenticación POST.  
- Configurar un **MCP server** con herramientas:  
- `getContent`: recibe descripción y retorna imágenes + hashtags.  
- Otro tool que registre campañas y genere bitácoras automatizadas.

### PromptAds

- Crear **SP transaccional** `XXXXXSP_VerboEntidad` para campañas (con TVP).  
- Generar **1000 campañas históricas** con resultados reales.  
- Monitorear rendimiento de consultas y optimizaciones SQL.

### PromptCrm

- Generar **500,000 clientes** y asociarlos a campañas.  
- Cifrar datos sensibles con **certificado X.509**.  
- Implementar **link server** con PromptAds.  
- Crear consultas con **CTE, Partition y Rank** para analizar correlaciones.  
- Generar **vistas materializadas con índices** para optimización.  
- Demostrar mejoras con **execution plan**.  
- Crear SP para logs y pruebas de **deadlocks, dirty reads y lost updates**.

### PromptSales

- Centralizar información resumida del ecosistema.  
- Crear un **ETL cada 4 min** para sincronizar solo cambios (delta).  
- Desarrollar un **MCP server** con consultas en lenguaje natural.  
- Incluir scripts en PostgreSQL que demuestren **triggers, cursores, joins, grants y revokes**.

---
## 3. Consideraciones Finales

- El **deployment** será mediante **Kubernetes**, con pods por servicio.  
- No se desarrollará el portal web, solo **bases de datos e integraciones MCP**.  
- Se permite uso de **N8N** para flujos de integración.  
- Mantener una **bitácora de uso de IA**, con nombre del estudiante, prompt, resultado y validaciones.  
- Uso correcto de **GitHub** y participación verificada en commits.  
- Cada grupo debe crear un canal en **Discord** para reportes semanales.  
- **Fecha límite de revisión de modelos:** martes 28 de octubre.  
- **Revisiones finales:** del 16 al 22 de noviembre, 2025.