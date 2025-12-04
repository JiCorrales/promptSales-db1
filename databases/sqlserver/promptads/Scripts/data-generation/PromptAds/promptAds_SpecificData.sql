USE PromptAds;
GO

/*========================================================
  SCRIPT: Specific Data 
  PRE-REQUISITOS:
    1) Base de datos PromptAds ya creada.
    2) Todas las tablas del esquema principal ya creadas (script DDL).
  ESTE SCRIPT DEBE EJECUTARSE:
    - Antes de los SP de seeding de datos masivos.
========================================================*/

/*---------------------------------------------------------
  Pa�ses, estados, ciudades
---------------------------------------------------------*/

-- Countries
INSERT INTO dbo.Countries(name)
SELECT v.name
FROM (VALUES 
    ('Costa Rica'),
    ('Estados Unidos'),
    ('M�xico'),
    ('Colombia'),
    ('Espa�a')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Countries c WHERE c.name = v.name
);

-- States 
INSERT INTO dbo.States(name, CountryId)
SELECT v.name, c.CountryId
FROM (VALUES
    ('San Jos�',       'Costa Rica'),
    ('Alajuela',       'Costa Rica'),
    ('New York',       'Estados Unidos'),
    ('California',     'Estados Unidos'),
    ('Ciudad de M�xico','M�xico')
) v(name, countryName)
JOIN dbo.Countries c ON c.name = v.countryName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.States s
    WHERE s.name = v.name AND s.CountryId = c.CountryId
);

-- Cities 
INSERT INTO dbo.Cities (name, StateId)
SELECT v.name, s.StateId
FROM (VALUES
    ('San Jos�',    'San Jos�'),
    ('Alajuela',    'Alajuela'),
    ('Heredia',     'San Jos�'),
    ('New York',    'New York'),
    ('Los �ngeles', 'California'),
    ('CDMX',        'Ciudad de M�xico')
) v(name, stateName)
JOIN dbo.States s ON s.name = v.stateName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Cities ci
    WHERE ci.name = v.name AND ci.StateId = s.StateId
);
GO

/* Direcciones b�sicas para Companies  */
INSERT INTO dbo.Addresses(Address1, Address2, zipCode, CityId)
SELECT v.Address1, v.Address2, v.zipCode, v.CityId
FROM (
    SELECT 'Av Central 123'    AS Address1, 'Oficina 201' AS Address2, 10101 AS zipCode, 1 AS CityId UNION ALL
    SELECT 'Calle Real 45',            NULL,              20202,           2 UNION ALL
    SELECT 'Boulevard Norte',         'Piso 3',           30101,           3 UNION ALL
    SELECT '5th Avenue 100',          'Suite 10',         10001,           4 UNION ALL
    SELECT 'Sunset Blvd 77',           NULL,              90001,           5 UNION ALL
    SELECT 'Reforma 250',             'Int 5',            11000,           6
) v
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Addresses a
    WHERE a.Address1 = v.Address1 AND a.zipCode = v.zipCode
);
GO

/*---------------------------------------------------------
  Cat�logos de estado/estatus b�sicos
---------------------------------------------------------*/

-- CompanyStatus
INSERT INTO dbo.CompanyStatus(name)
SELECT v.name
FROM (VALUES
    ('Prospecto'),
    ('Activo'),
    ('Suspendido'),
    ('Cerrado')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.CompanyStatus cs WHERE cs.name = v.name
);

-- UserStatus
INSERT INTO dbo.UserStatus(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('Activo',1),
    ('Inactivo',1),
    ('Bloqueado',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.UserStatus us WHERE us.name = v.name
);

-- CampaignStatus
IF NOT EXISTS (SELECT 1 FROM dbo.CampaignStatus)
BEGIN
    INSERT INTO dbo.CampaignStatus(name, enabled)
    SELECT v.name, v.enabled
    FROM (VALUES
        ('Planificada',1),
        ('Activa',1),
        ('Pausada',1),
        ('Finalizada',1),
        ('Cancelada',1)
    ) v(name, enabled)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.CampaignStatus cs WHERE cs.name = v.name
    );
END;

-- AdStatus
INSERT INTO dbo.AdStatus(name)
SELECT v.name
FROM (VALUES
    ('Borrador'),
    ('Pendiente Aprobaci�n'),
    ('Activo'),
    ('Pausado'),
    ('Finalizado')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.AdStatus s WHERE s.name = v.name
);

-- AdTypes
INSERT INTO dbo.AdTypes(name)
SELECT v.name
FROM (VALUES
    ('Imagen'),
    ('Video'),
    ('Carrusel'),
    ('Texto'),
    ('Story'),
    ('Short')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.AdTypes t WHERE t.name = v.name
);

-- MediaTypes
INSERT INTO dbo.MediaTypes(name)
SELECT v.name
FROM (VALUES
    ('Imagen JPG'),
    ('Imagen PNG'),
    ('Video MP4'),
    ('GIF'),
    ('HTML5')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.MediaTypes mt WHERE mt.name = v.name
);

-- Channels
INSERT INTO dbo.Channels(name)
SELECT v.name
FROM (VALUES
    ('Facebook'),
    ('Instagram'),
    ('TikTok'),
    ('LinkedIn'),
    ('YouTube'),
    ('Google Search'),
    ('Email'),
    ('SMS')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Channels c WHERE c.name = v.name
);

-- ReactionTypes
INSERT INTO dbo.ReactionTypes(name)
SELECT v.name
FROM (VALUES
    ('Like'),
    ('Love'),
    ('Haha'),
    ('Wow'),
    ('Sad'),
    ('Angry'),
    ('Comment'),
    ('Share')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ReactionTypes r WHERE r.name = v.name
);

-- Payment catalogs
INSERT INTO dbo.PaymentMethods(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('Tarjeta Cr�dito',1),
    ('Tarjeta D�bito',1),
    ('Transferencia',1),
    ('PayPal',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PaymentMethods pm WHERE pm.name = v.name
);

INSERT INTO dbo.PaymentStatuses(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('Pendiente',1),
    ('Pagado',1),
    ('Fallido',1),
    ('Reembolsado',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PaymentStatuses ps WHERE ps.name = v.name
);

INSERT INTO dbo.PaymentTypes(name, description, enabled)
SELECT v.name, v.description, v.enabled
FROM (VALUES
    ('Prepago','Pago anticipado de campa�a',1),
    ('Postpago','Pago al cierre de campa�a',1),
    ('Mensual','Pago recurrente mensual',1)
) v(name, description, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PaymentTypes pt WHERE pt.name = v.name
);

-- Currencies
INSERT INTO dbo.Currencies(name, isoCode, CountryId)
SELECT v.name, v.isoCode, c.CountryId
FROM (VALUES
    ('Col�n costarricense','CRC','Costa Rica'),
    ('D�lar estadounidense','USD','Estados Unidos'),
    ('Euro','EUR','Espa�a')
) v(name, isoCode, countryName)
JOIN dbo.Countries c ON c.name = v.countryName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Currencies cu WHERE cu.name = v.name
);

-- Roles
INSERT INTO dbo.Roles(name, description, createdAt, enabled)
SELECT v.name, v.description, GETDATE(), v.enabled
FROM (VALUES
    ('Admin','Administrador del sistema',1),
    ('CampaignManager','Gestor de campa�as',1),
    ('Analyst','Analista de datos',1)
) v(name, description, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Roles r WHERE r.name = v.name
);

-- Permissions
INSERT INTO dbo.Permissions(name, description, code, enabled, createdAt)
SELECT v.name, v.description, v.code, 1, GETDATE()
FROM (VALUES
    ('Ver campa�as','Puede ver campa�as','CAMPAIGN_VIEW'),
    ('Editar campa�as','Puede editar campa�as','CAMPAIGN_EDIT'),
    ('Ver m�tricas','Puede ver m�tricas','METRICS_VIEW'),
    ('Administrar usuarios','Administra usuarios','USER_ADMIN')
) v(name, description, code)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Permissions p WHERE p.code = v.code
);

-- PermissionsPerRole
INSERT INTO dbo.PermissionsPerRole(RoleId, PermissionId, enabled, createdAt, checksum)
SELECT r.RoleId, p.PermissionId, 1, GETDATE(),
       CONVERT(char(64), HASHBYTES('SHA2_256',
              CONCAT(r.RoleId, '-', p.PermissionId)),2)
FROM dbo.Roles r
CROSS JOIN dbo.Permissions p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PermissionsPerRole pr
    WHERE pr.RoleId = r.RoleId AND pr.PermissionId = p.PermissionId
);

-- ContactTypes
INSERT INTO dbo.ContactTypes(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('Email',1),
    ('Tel�fono',1),
    ('WhatsApp',1),
    ('Instagram DM',1),
    ('TikTok DM',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ContactTypes ct WHERE ct.name = v.name
);

-- Subscriptions
INSERT INTO dbo.Subscriptions(name, description, createdAt, enabled)
SELECT v.name, v.description, GETDATE(), 1
FROM (VALUES
    ('Starter','Plan b�sico para peque�as empresas'),
    ('Growth','Plan intermedio para crecimiento'),
    ('Enterprise','Plan avanzado para grandes empresas')
) v(name, description)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Subscriptions s WHERE s.name = v.name
);

-- SubscriptionFeatures
INSERT INTO dbo.SubscriptionFeatures(name, description)
SELECT v.name, v.description
FROM (VALUES
    ('L�mite de campa�as mensuales','Cantidad m�xima de campa�as que se pueden crear al mes'),
    ('Soporte prioritario','Nivel de soporte y SLA'),
    ('Integraci�n con CRM','Capacidad de integrarse a CRM externos'),
    ('L�mites de presupuesto','Restricciones de presupuesto por campa�a'),
    ('Reportes avanzados','Acceso a visualizaciones y reportes avanzados')
) v(name, description)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.SubscriptionFeatures f WHERE f.name = v.name
);

-- FeaturePerSubscription
INSERT INTO dbo.FeaturePerSubscription(SubscriptionId, SubFeatureId, value)
SELECT s.SubscriptionId, f.SubFeatureId,
       CASE s.name
            WHEN 'Starter'    THEN 'B�sico'
            WHEN 'Growth'     THEN 'Intermedio'
            WHEN 'Enterprise' THEN 'Avanzado'
       END
FROM dbo.Subscriptions s
CROSS JOIN dbo.SubscriptionFeatures f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.FeaturePerSubscription fs
    WHERE fs.SubscriptionId = s.SubscriptionId
      AND fs.SubFeatureId = f.SubFeatureId
);

-- SuppliersType
INSERT INTO dbo.SuppliersType(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('AdsPlatform',1),
    ('EmailProvider',1),
    ('SmsGateway',1),
    ('Analytics',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.SuppliersType st WHERE st.name = v.name
);

INSERT INTO dbo.SuppliersAPI (name, SupTypeId, base_url, documentation_url, active, createdAt)
SELECT
    v.name,
    st.SupTypeId,
    v.base_url,
    v.doc_url,
    v.active,
    GETDATE()
FROM (
    VALUES
        ('Meta Ads',   'AdsPlatform',  'https://graph.facebook.com',
         'https://developers.facebook.com/docs/marketing-apis', 1),
        ('Google Ads', 'AdsPlatform',  'https://googleads.googleapis.com',
         'https://developers.google.com/google-ads/api', 1),
        ('Mailchimp',  'EmailProvider','https://usX.api.mailchimp.com',
         'https://mailchimp.com/developer', 1),
        ('Twilio SMS', 'SmsGateway',   'https://api.twilio.com',
         'https://www.twilio.com/docs/sms', 1)
) AS v(name, type, base_url, doc_url, active)
JOIN dbo.SuppliersType st
    ON st.name = v.type
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.SuppliersAPI s WHERE s.name = v.name
);


-- WebhookType
INSERT INTO dbo.WebhookType(name, enabled)
SELECT v.name, v.enabled
FROM (VALUES
    ('ConversionEvent',1),
    ('LeadEvent',1),
    ('DeliveryStatus',1)
) v(name, enabled)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.WebhookType wt WHERE wt.name = v.name
);

-- WebhooksAPI
INSERT INTO dbo.WebhooksAPI(SupplierId, WHTypeId, secret, enabled, createdAt)
SELECT s.SupplierId, wt.WHTypeId,
       CONVERT(varbinary(max), NEWID()),
       1, GETDATE()
FROM dbo.SuppliersAPI s
CROSS JOIN dbo.WebhookType wt
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.WebhooksAPI w
    WHERE w.SupplierId = s.SupplierId AND w.WHTypeId = wt.WHTypeId
);

-- RequestMethods
INSERT INTO dbo.RequestMethods(name, enabled, createdAt)
SELECT v.name, 1, GETDATE()
FROM (VALUES
    ('GET'),
    ('POST'),
    ('PUT'),
    ('DELETE')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.RequestMethods rm WHERE rm.name = v.name
);

-- RequestStates
IF OBJECT_ID('dbo.RequestStates','U') IS NOT NULL
BEGIN
    INSERT INTO dbo.RequestStates(name, description)
    SELECT v.name, v.description
    FROM (VALUES
        ('PENDING','Solicitud enviada, esperando respuesta'),
        ('SUCCESS','Respuesta correcta'),
        ('FAILED','Error en la solicitud'),
        ('RETRYING','Se est� reintentando')
    ) v(name, description)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.RequestStates rs WHERE rs.name = v.name
    );
END

-- SentimentTypes
IF OBJECT_ID('dbo.SentimentTypes','U') IS NOT NULL
BEGIN
    INSERT INTO dbo.SentimentTypes(name, description)
    SELECT v.name, v.description
    FROM (VALUES
        ('Positive','Sentimiento mayormente positivo'),
        ('Neutral','Sentimiento neutro'),
        ('Negative','Sentimiento negativo')
    ) v(name, description)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SentimentTypes st WHERE st.name = v.name
    );
END

-- ValidationMethods (para AuditAI)
IF OBJECT_ID('dbo.ValidationMethods','U') IS NOT NULL
BEGIN
    INSERT INTO dbo.ValidationMethods(name, description)
    SELECT v.name, v.description
    FROM (VALUES
        ('Revisi�n manual r�pida','Validaci�n manual por el usuario'),
        ('Comparaci�n con dataset','Comparaci�n con datos de referencia'),
        ('Pruebas unitarias','Uso de tests autom�ticos'),
        ('Revisi�n por par','Revisi�n de otra persona del equipo')
    ) v(name, description)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.ValidationMethods vm WHERE vm.name = v.name
    );
END

-- LogLevels
INSERT INTO dbo.LogLevels(name)
SELECT v.name
FROM (VALUES
    ('Info'),
    ('Warning'),
    ('Error'),
    ('Critical')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.LogLevels ll WHERE ll.name = v.name
);

-- LogTypes
INSERT INTO dbo.LogTypes(name)
SELECT v.name
FROM (VALUES
    ('System'),
    ('Business'),
    ('Security'),
    ('Integration')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.LogTypes lt WHERE lt.name = v.name
);

-- LogSources
INSERT INTO dbo.LogSources(name)
SELECT v.name
FROM (VALUES
    ('API'),
    ('ETL'),
    ('WebPortal'),
    ('MCPServer'),
    ('BackgroundJob')
) v(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.LogSources ls WHERE ls.name = v.name
);

-- ETLWatermark base
INSERT INTO dbo.ETLWatermark(processName, LastSuccessAt, Notes)
SELECT v.processName, GETDATE(), v.Notes
FROM (VALUES
    ('PromptAds_To_PromptSales_Summary','Carga inicial')
) v(processName, Notes)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ETLWatermark e WHERE e.processName = v.processName
);
GO