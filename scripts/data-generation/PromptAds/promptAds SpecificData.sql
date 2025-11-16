use PromptAds;

/*---------------------------------------------------------
  Países, estados, ciudades
---------------------------------------------------------*/


-- Countries
INSERT INTO dbo.Countries(name)
VALUES ('Costa Rica'),('Estados Unidos'),('México'),('Colombia'),('España');

-- States 
INSERT INTO dbo.States(name, CountryId)
SELECT 'San José', c.CountryId FROM dbo.Countries c WHERE c.name = 'Costa Rica'
UNION ALL
SELECT 'Alajuela', c.CountryId FROM dbo.Countries c WHERE c.name = 'Costa Rica'
UNION ALL
SELECT 'New York', c.CountryId FROM dbo.Countries c WHERE c.name = 'Estados Unidos'
UNION ALL
SELECT 'California', c.CountryId FROM dbo.Countries c WHERE c.name = 'Estados Unidos'
UNION ALL
SELECT 'Ciudad de México', c.CountryId FROM dbo.Countries c WHERE c.name = 'México';

-- Cities 
INSERT INTO dbo.Cities (name, StateId)
SELECT 'San José',   s.StateId FROM dbo.States s WHERE s.name = 'San José'
UNION ALL
SELECT 'Alajuela',   s.StateId FROM dbo.States s WHERE s.name = 'Alajuela'
UNION ALL
SELECT 'Heredia',    s.StateId FROM dbo.States s WHERE s.name = 'San José'
UNION ALL
SELECT 'New York',   s.StateId FROM dbo.States s WHERE s.name = 'New York'
UNION ALL
SELECT 'Los Ángeles',s.StateId FROM dbo.States s WHERE s.name = 'California'
UNION ALL
SELECT 'CDMX',       s.StateId FROM dbo.States s WHERE s.name = 'Ciudad de México';
GO

/* Direcciones básicas para Companies  */
INSERT INTO dbo.Addresses(Address1, Address2, zipCode, CityId)
SELECT 'Av Central 123',   'Oficina 201', 10101, 1 UNION ALL
SELECT 'Calle Real 45',    NULL,          20202, 2 UNION ALL
SELECT 'Boulevard Norte',  'Piso 3',      30101, 3 UNION ALL
SELECT '5th Avenue 100',   'Suite 10',    10001, 4 UNION ALL
SELECT 'Sunset Blvd 77',   NULL,          90001, 5 UNION ALL
SELECT 'Reforma 250',      'Int 5',       11000, 6;
GO

/*---------------------------------------------------------
  Catálogos de estado/estatus básicos
---------------------------------------------------------*/

-- CompanyStatus
INSERT INTO dbo.CompanyStatus(name)
VALUES ('Prospecto'),('Activo'),('Suspendido'),('Cerrado');

-- UserStatus
INSERT INTO dbo.UserStatus(name, enabled)
VALUES ('Activo',1),('Inactivo',1),('Bloqueado',1);

-- CampaignStatus (si ya la creaste con el script anterior)
IF NOT EXISTS (SELECT 1 FROM dbo.CampaignStatus)
BEGIN
    INSERT INTO dbo.CampaignStatus(name, enabled)
    VALUES ('Planificada',1),('Activa',1),('Pausada',1),('Finalizada',1),('Cancelada',1);
END;

-- AdStatus
INSERT INTO dbo.AdStatus(name)
VALUES ('Borrador'),('Pendiente Aprobación'),('Activo'),('Pausado'),('Finalizado');

-- AdTypes
INSERT INTO dbo.AdTypes(name)
VALUES ('Imagen'),('Video'),('Carrusel'),('Texto'),('Story'),('Short');

-- MediaTypes
INSERT INTO dbo.MediaTypes(name)
VALUES ('Imagen JPG'),('Imagen PNG'),('Video MP4'),('GIF'),('HTML5');

-- Channels
INSERT INTO dbo.Channels(name)
VALUES ('Facebook'),('Instagram'),('TikTok'),('LinkedIn'),('YouTube'),
       ('Google Search'),('Email'),('SMS');

-- ReactionTypes
INSERT INTO dbo.ReactionTypes(name)
VALUES ('Like'),('Love'),('Haha'),('Wow'),('Sad'),('Angry'),('Comment'),('Share');

-- Payment catalogs
INSERT INTO dbo.PaymentMethods(name, enabled)
VALUES ('Tarjeta Crédito',1),('Tarjeta Débito',1),('Transferencia',1),('PayPal',1);

INSERT INTO dbo.PaymentStatuses(name, enabled)
VALUES ('Pendiente',1),('Pagado',1),('Fallido',1),('Reembolsado',1);

INSERT INTO dbo.PaymentTypes(name, description, enabled)
VALUES ('Prepago','Pago anticipado de campaña',1),
       ('Postpago','Pago al cierre de campaña',1),
       ('Mensual','Pago recurrente mensual',1);

-- Currencies
INSERT INTO dbo.Currencies(name, isoCode, CountryId)
SELECT 'Colón costarricense','CRC',CountryId FROM dbo.Countries WHERE name='Costa Rica'
UNION ALL
SELECT 'Dólar estadounidense','USD',CountryId FROM dbo.Countries WHERE name='Estados Unidos'
UNION ALL
SELECT 'Euro','EUR',CountryId FROM dbo.Countries WHERE name='España';

-- Roles, Permissions, etc.
INSERT INTO dbo.Roles(name, description, createdAt, enabled)
VALUES ('Admin','Administrador del sistema',GETDATE(),1),
       ('CampaignManager','Gestor de campañas',GETDATE(),1),
       ('Analyst','Analista de datos',GETDATE(),1);

INSERT INTO dbo.Permissions(name, description, code, enabled, createdAt)
VALUES
('Ver campañas','Puede ver campañas','CAMPAIGN_VIEW',1,GETDATE()),
('Editar campañas','Puede editar campañas','CAMPAIGN_EDIT',1,GETDATE()),
('Ver métricas','Puede ver métricas','METRICS_VIEW',1,GETDATE()),
('Administrar usuarios','Administra usuarios','USER_ADMIN',1,GETDATE());

INSERT INTO dbo.PermissionsPerRole(RoleId, PermissionId, enabled, createdAt, checksum)
SELECT r.RoleId, p.PermissionId, 1, GETDATE(),
       CONVERT(char(64), HASHBYTES('SHA2_256',
              CONCAT(r.RoleId, '-', p.PermissionId)),2)
FROM dbo.Roles r
CROSS JOIN dbo.Permissions p;

-- ContactTypes
INSERT INTO dbo.ContactTypes(name, enabled)
VALUES ('Email',1),('Teléfono',1),('WhatsApp',1),('Instagram DM',1),('TikTok DM',1);

-- Subscriptions / features
INSERT INTO dbo.Subscriptions(name, description, createdAt, enabled)
VALUES
('Starter','Plan básico para pequeñas empresas',GETDATE(),1),
('Growth','Plan intermedio para crecimiento',GETDATE(),1),
('Enterprise','Plan avanzado para grandes empresas',GETDATE(),1);

INSERT INTO dbo.SubscriptionFeatures(name, description)
VALUES
('Límite de campañas mensuales','Cantidad máxima de campañas que se pueden crear al mes'),
('Soporte prioritario','Nivel de soporte y SLA'),
('Integración con CRM','Capacidad de integrarse a CRM externos'),
('Límites de presupuesto','Restricciones de presupuesto por campaña'),
('Reportes avanzados','Acceso a visualizaciones y reportes avanzados');

INSERT INTO dbo.FeaturePerSubscription(SubscriptionId, SubFeatureId, value)
SELECT s.SubscriptionId, f.SubFeatureId,
       CASE s.name
            WHEN 'Starter'    THEN 'Básico'
            WHEN 'Growth'     THEN 'Intermedio'
            WHEN 'Enterprise' THEN 'Avanzado'
       END
FROM dbo.Subscriptions s
CROSS JOIN dbo.SubscriptionFeatures f;

-- SuppliersType / SuppliersAPI / Webhooks / RequestMethods / RequestStates
INSERT INTO dbo.SuppliersType(name, enabled)
VALUES ('AdsPlatform',1),('EmailProvider',1),('SmsGateway',1),('Analytics',1);

INSERT INTO dbo.SuppliersAPI(name, SupTypeId, base_url, documentation_url, active, createdAt)
SELECT 'Meta Ads',      st.SupTypeId,'https://graph.facebook.com',
       'https://developers.facebook.com/docs/marketing-apis',1,GETDATE()
FROM dbo.SuppliersType st WHERE st.name='AdsPlatform'
UNION ALL
SELECT 'Google Ads',    st.SupTypeId,'https://googleads.googleapis.com',
       'https://developers.google.com/google-ads/api',1,GETDATE()
FROM dbo.SuppliersType st WHERE st.name='AdsPlatform'
UNION ALL
SELECT 'Mailchimp',     st.SupTypeId,'https://usX.api.mailchimp.com',
       'https://mailchimp.com/developer',1,GETDATE()
FROM dbo.SuppliersType st WHERE st.name='EmailProvider'
UNION ALL
SELECT 'Twilio SMS',    st.SupTypeId,'https://api.twilio.com',
       'https://www.twilio.com/docs/sms',1,GETDATE()
FROM dbo.SuppliersType st WHERE st.name='SmsGateway';

INSERT INTO dbo.WebhookType(name, enabled)
VALUES ('ConversionEvent',1),('LeadEvent',1),('DeliveryStatus',1);

INSERT INTO dbo.WebhooksAPI(SupplierId, WHTypeId, secret, enabled, createdAt)
SELECT TOP (5) s.SupplierId, wt.WHTypeId,
       CONVERT(varbinary(max), NEWID()),
       1, GETDATE()
FROM dbo.SuppliersAPI s
CROSS JOIN dbo.WebhookType wt;

INSERT INTO dbo.RequestMethods(name, enabled, createdAt)
VALUES ('GET',1,GETDATE()),('POST',1,GETDATE()),('PUT',1,GETDATE()),('DELETE',1,GETDATE());

-- RequestStates (para RequestsAPI.StateId)
IF OBJECT_ID('dbo.RequestStates','U') IS NOT NULL
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.RequestStates)
    INSERT INTO dbo.RequestStates(name, description)
    VALUES ('PENDING','Solicitud enviada, esperando respuesta'),
           ('SUCCESS','Respuesta correcta'),
           ('FAILED','Error en la solicitud'),
           ('RETRYING','Se está reintentando');
END

-- SentimentTypes
IF OBJECT_ID('dbo.SentimentTypes','U') IS NOT NULL
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.SentimentTypes)
    INSERT INTO dbo.SentimentTypes(name, description)
    VALUES ('Positive','Sentimiento mayormente positivo'),
           ('Neutral','Sentimiento neutro'),
           ('Negative','Sentimiento negativo');
END

-- ValidationMethods (para AuditAI)
IF OBJECT_ID('dbo.ValidationMethods','U') IS NOT NULL
BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.ValidationMethods)
    INSERT INTO dbo.ValidationMethods(name, description)
    VALUES ('Revisión manual rápida','Validación manual por el usuario'),
           ('Comparación con dataset','Comparación con datos de referencia'),
           ('Pruebas unitarias','Uso de tests automáticos'),
           ('Revisión por par','Revisión de otra persona del equipo');
END

-- LogLevels / LogTypes / LogSources
INSERT INTO dbo.LogLevels(name)
VALUES ('Info'),('Warning'),('Error'),('Critical');

INSERT INTO dbo.LogTypes(name)
VALUES ('System'),('Business'),('Security'),('Integration');

INSERT INTO dbo.LogSources(name)
VALUES ('API'),('ETL'),('WebPortal'),('MCPServer'),('BackgroundJob');

-- ETLWatermark base
INSERT INTO dbo.ETLWatermark(processName, LastSuccessAt, Notes)
VALUES ('PromptAds_To_PromptSales_Summary', GETDATE(), 'Carga inicial');
GO
