-- ============================================================================
-- Enrich PromptSales schema using PromptAds/PromptCrm snapshot data
-- ============================================================================
BEGIN;

-- --------------------------------------------------------------------------
INSERT INTO public."Country" ("countryId", name)
VALUES
    (9001, 'United States'),
    (9002, 'Canada'),
    (9003, 'Mexico'),
    (9004, 'Chile'),
    (9005, 'Spain')
ON CONFLICT ("countryId") DO NOTHING;

INSERT INTO public."States" ("StateId", name, "countryId")
VALUES
    (9001, 'California', 9001),
    (9002, 'Ontario', 9002),
    (9003, 'Ciudad de Mexico', 9003),
    (9004, 'Santiago RM', 9004),
    (9005, 'Madrid', 9005)
ON CONFLICT ("StateId") DO NOTHING;

INSERT INTO public."Cities" ("cityId", name, "stateId")
VALUES
    (9001, 'San Francisco', 9001),
    (9002, 'Toronto', 9002),
    (9003, 'CDMX', 9003),
    (9004, 'Santiago', 9004),
    (9005, 'Madrid', 9005)
ON CONFLICT ("cityId") DO NOTHING;

INSERT INTO public."Addresses"
(
    "AddressId", address1, address2, zipcode,
    geolocation, status, "createdAt", "updatedAt",
    enabled, "cityId"
)
VALUES
    (9001, '1 Market St', 'Suite 100', '94105', POINT(-122.3942, 37.7936), 'ACTIVE', NOW(), NOW(), TRUE, 9001),
    (9002, '100 King St W', '15th Floor', 'M5X1A9', POINT(-79.3832, 43.6481), 'ACTIVE', NOW(), NOW(), TRUE, 9002),
    (9003, 'Av. Reforma 10', 'Piso 8', '06500', POINT(-99.1667, 19.4333), 'ACTIVE', NOW(), NOW(), TRUE, 9003),
    (9004, 'Av. Providencia 1234', 'Of 501', '7500000', POINT(-70.6483, -33.4569), 'ACTIVE', NOW(), NOW(), TRUE, 9004),
    (9005, 'Gran Via 1', 'Planta 4', '28013', POINT(-3.7038, 40.4168), 'ACTIVE', NOW(), NOW(), TRUE, 9005)
ON CONFLICT ("AddressId") DO NOTHING;

INSERT INTO public."Currency" ("currencyId", name, code, symbol, "countryId")
VALUES
    (1, 'US Dollar', B'0001', '$', 9001),
    (2, 'Canadian Dollar', B'0010', 'C$', 9002),
    (3, 'Mexican Peso', B'0011', 'MX', 9003)
ON CONFLICT ("currencyId") DO NOTHING;

INSERT INTO public."ExchangeRate"
(
    "exchangeRateId", "startDate", "endDate",
    "fromCurrency", "toCurrency", enabled
)
VALUES
    (1, NOW() - INTERVAL '30 days', NULL, 1, 2, TRUE),
    (2, NOW() - INTERVAL '30 days', NULL, 2, 3, TRUE)
ON CONFLICT ("exchangeRateId") DO UPDATE
SET
    "startDate" = EXCLUDED."startDate",
    "endDate"   = EXCLUDED."endDate",
    "fromCurrency" = EXCLUDED."fromCurrency",
    "toCurrency"   = EXCLUDED."toCurrency",
    enabled        = EXCLUDED.enabled;

INSERT INTO public."PaymentTypes" ("paymentTypeId", name)
VALUES
    (1, 'Subscription'),
    (2, 'Add-On Services')
ON CONFLICT ("paymentTypeId") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public."paymentMethod" ("paymentMetId", name)
VALUES
    (1, 'Corporate Card'),
    (2, 'Wire Transfer')
ON CONFLICT ("paymentMetId") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public."featureType" ("featureTypeId", name, description)
VALUES
    (101, 'CRM', 'Lead intelligence and scoring features'),
    (102, 'ADS', 'Advertising spend and ROAS insights')
ON CONFLICT ("featureTypeId") DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO public."Features"
(
    "featureId", "featureTypeId", name,
    description, enabled, "createdAt", "updatedAt"
)
VALUES
    (201, 101, 'Lead Health Monitor', 'Monitors PromptCRM lead quality, sourced from ETL snapshots.', TRUE, NOW(), NOW()),
    (202, 102, 'Ad Spend Insights', 'Aggregates PromptAds spend/revenue for data warehouse users.', TRUE, NOW(), NOW())
ON CONFLICT ("featureId") DO UPDATE
SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    enabled     = EXCLUDED.enabled,
    "updatedAt" = EXCLUDED."updatedAt";

INSERT INTO public."ProviderTypes"
(
    "provderTypeId", name, description,
    "createdAt", "updatedAt", enabled
)
VALUES
    (1, 'Advertising Platform', 'External PromptAds provider seeded from ETL.', NOW(), NOW(), TRUE),
    (2, 'CRM Platform', 'PromptCRM cloud provider seeded from ETL.', NOW(), NOW(), TRUE)
ON CONFLICT ("provderTypeId") DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    enabled = EXCLUDED.enabled,
    "updatedAt" = EXCLUDED."updatedAt";

INSERT INTO public."AuthMethods" ("authId", name, description, enabled, "createdAt", "updatedAt")
VALUES
    (1, 'API Key', 'Signed requests using PromptSales API keys.', TRUE, NOW(), NOW()),
    (2, 'OAuth2', 'OAuth workflow for CRM integrations.', TRUE, NOW(), NOW())
ON CONFLICT ("authId") DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    enabled = EXCLUDED.enabled,
    "updatedAt" = EXCLUDED."updatedAt";

INSERT INTO public."ApiTypes" ("typeId", name)
VALUES
    (1, 'REST'),
    (2, 'Streaming')
ON CONFLICT ("typeId") DO UPDATE
SET name = EXCLUDED.name;

-- --------------------------------------------------------------------------
-- Populate CampaignChannels using snapshot data
-- --------------------------------------------------------------------------
WITH exploded AS (
    SELECT DISTINCT
        pas.campaign_id,
        TRIM(channel) AS channel_name
    FROM public."PromptAdsSnapshots" pas
    CROSS JOIN LATERAL regexp_split_to_table(COALESCE(pas.channels, ''), ',') AS channel
    WHERE TRIM(channel) <> '' AND pas.campaign_id IS NOT NULL
),
numbered AS (
    SELECT
        campaign_id,
        channel_name,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY channel_name) AS rn,
        COUNT(*) OVER (PARTITION BY campaign_id) AS channel_count
    FROM exploded
),
costs AS (
    SELECT
        campaign_id,
        COALESCE(SUM(total_cost), 0) AS total_cost,
        MIN(COALESCE(start_date, NOW())) AS created_at,
        MAX(COALESCE(load_ts, NOW())) AS updated_at
    FROM public."PromptAdsSnapshots"
    WHERE campaign_id IS NOT NULL
    GROUP BY campaign_id
)
INSERT INTO public."CampaignChannels"
(
    "channelId", "campaignId", name,
    "totalSpent", "createdAt", "updatedAt", enabled
)
SELECT
    campaign_id * 100 + rn                                              AS channel_id,
    campaign_id,
    channel_name,
    ROUND(COALESCE(costs.total_cost, 0) / NULLIF(channel_count, 0), 2)  AS total_spent,
    costs.created_at,
    costs.updated_at,
    TRUE
FROM numbered
JOIN costs USING (campaign_id)
ON CONFLICT ("channelId") DO UPDATE
SET
    name         = EXCLUDED.name,
    "totalSpent" = EXCLUDED."totalSpent",
    "updatedAt"  = EXCLUDED."updatedAt",
    enabled      = EXCLUDED.enabled;

-- --------------------------------------------------------------------------
-- Populate CampaignMarkets using target markets and synthetic addresses
-- --------------------------------------------------------------------------
WITH exploded AS (
    SELECT DISTINCT
        pas.campaign_id,
        TRIM(market) AS market_name
    FROM public."PromptAdsSnapshots" pas
    CROSS JOIN LATERAL regexp_split_to_table(COALESCE(pas.target_markets, ''), ',') AS market
    WHERE TRIM(market) <> '' AND pas.campaign_id IS NOT NULL
),
numbered AS (
    SELECT
        campaign_id,
        market_name,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY market_name) AS rn,
        ROW_NUMBER() OVER (ORDER BY campaign_id, market_name) AS seq
    FROM exploded
)
INSERT INTO public."CampaignMarkets"
(
    "marketId", "AddressId", "budgetAllocation",
    enabled, "createdAt", "updatedAt", "campaignId"
)
SELECT
    200000 + seq,
    9000 + ((seq - 1) % 5) + 1                               AS address_id,
    LEAST(100.0, 20.0 + (rn * 10))                           AS budget_allocation,
    TRUE,
    NOW(),
    NOW(),
    campaign_id
FROM numbered
ON CONFLICT ("marketId") DO UPDATE
SET
    "AddressId"        = EXCLUDED."AddressId",
    "budgetAllocation" = EXCLUDED."budgetAllocation",
    "updatedAt"        = EXCLUDED."updatedAt";

-- --------------------------------------------------------------------------
-- Populate salesSummary aggregating CRM + Ads snapshots
-- --------------------------------------------------------------------------
WITH crm AS (
    SELECT
        pcs.campaign_id,
        COALESCE(pcs.snapshot_date, pcs.created_at::date, CURRENT_DATE) AS snapshot_date,
        COUNT(*)                               AS orders,
        SUM(COALESCE(pcs.total_conversion_amount, 0)) AS sales_amount,
        MIN(pcs.lead_id)                       AS country_ref
    FROM public."PromptCrmSnapshots" pcs
    WHERE pcs.campaign_id IS NOT NULL
    GROUP BY pcs.campaign_id,
             COALESCE(pcs.snapshot_date, pcs.created_at::date, CURRENT_DATE)
),
ads AS (
    SELECT
        campaign_id,
        SUM(COALESCE(total_revenue, 0)) AS ads_revenue
    FROM public."PromptAdsSnapshots"
    WHERE campaign_id IS NOT NULL
    GROUP BY campaign_id
),
aggregated AS (
    SELECT
        crm.*,
        COALESCE(ads.ads_revenue, crm.sales_amount) AS ads_revenue
    FROM crm
    LEFT JOIN ads ON ads.campaign_id = crm.campaign_id
    JOIN public."Campaigns" camp ON camp."campaignId" = crm.campaign_id
),
numbered AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY campaign_id, snapshot_date) + 300000 AS sales_sum_id,
        *
    FROM aggregated
)
INSERT INTO public."salesSummary"
(
    "salesSumId", "campaignId", "countryId", date,
    orders, "salesAmount", "returnsAmount", "adsRevenue",
    "sourceSystemId", currencyd
)
SELECT
    sales_sum_id,
    campaign_id,
    COALESCE(country_ref, 9001),
    snapshot_date,
    orders,
    LEAST(sales_amount, 99999999.99),
    LEAST(sales_amount * 0.05, 99999999.99),
    LEAST(ads_revenue, 99999999.99),
    'PromptBridge',
    1
FROM numbered
ON CONFLICT ("salesSumId") DO NOTHING;

-- --------------------------------------------------------------------------
-- Build subscriptions and billing data from CRM snapshots
-- --------------------------------------------------------------------------
WITH sub_base AS (
    SELECT
        pcs.subscriber_id,
        COALESCE(NULLIF(MAX(TRIM(pcs.subscriber_name)), ''), CONCAT('Subscriber ', pcs.subscriber_id)) AS subscriber_name,
        MIN(pcs.created_at) AS first_seen,
        MAX(COALESCE(pcs.last_event_at, pcs.created_at)) AS last_seen,
        COUNT(DISTINCT pcs.campaign_id) AS campaign_count,
        SUM(COALESCE(pcs.total_conversion_amount, 0)) AS total_conversion_amount,
        COUNT(*) AS total_leads,
        MIN(c."companyId") AS company_id,
        SUM(COALESCE(pcs.total_events, 0)) AS total_events
    FROM public."PromptCrmSnapshots" pcs
    JOIN public."Campaigns" c ON c."campaignId" = pcs.campaign_id
    WHERE pcs.subscriber_id IS NOT NULL
    GROUP BY pcs.subscriber_id
)
INSERT INTO public."SubBilling"
(
    "billingId", "paymentFrequency", "startDate",
    "endDate", status, price
)
SELECT
    subscriber_id,
    CASE WHEN campaign_count >= 4 THEN 'ANNUAL' ELSE 'MONTHLY' END,
    COALESCE(first_seen, NOW()),
    COALESCE(first_seen, NOW()) + INTERVAL '1 year',
    'ACTIVE',
    LEAST(9999.99, ROUND(COALESCE(
        total_conversion_amount / NULLIF(campaign_count, 0),
        total_conversion_amount / NULLIF(total_leads, 0),
        199.99
    ), 2))
FROM sub_base
ON CONFLICT ("billingId") DO UPDATE
SET
    "paymentFrequency" = EXCLUDED."paymentFrequency",
    "startDate"        = EXCLUDED."startDate",
    "endDate"          = EXCLUDED."endDate",
    status             = EXCLUDED.status,
    price              = EXCLUDED.price;

WITH sub_base AS (
    SELECT
        pcs.subscriber_id,
        COALESCE(NULLIF(MAX(TRIM(pcs.subscriber_name)), ''), CONCAT('Subscriber ', pcs.subscriber_id)) AS subscriber_name,
        MIN(pcs.created_at) AS first_seen,
        MAX(COALESCE(pcs.last_event_at, pcs.created_at)) AS last_seen,
        COUNT(DISTINCT pcs.campaign_id) AS campaign_count,
        COUNT(*) AS total_leads
    FROM public."PromptCrmSnapshots" pcs
    JOIN public."Campaigns" c ON c."campaignId" = pcs.campaign_id
    WHERE pcs.subscriber_id IS NOT NULL
    GROUP BY pcs.subscriber_id
)
INSERT INTO public."Subscription"
(
    "subId", "subName", "billingId",
    status, description, "createdAt", "updatedAt", enabled
)
SELECT
    subscriber_id,
    subscriber_name,
    subscriber_id,
    'ACTIVE',
    CONCAT('Campaigns: ', campaign_count, ' | Leads: ', total_leads),
    COALESCE(first_seen, NOW()),
    COALESCE(last_seen, NOW()),
    TRUE
FROM sub_base
ON CONFLICT ("subId") DO UPDATE
SET
    "subName" = EXCLUDED."subName",
    status    = EXCLUDED.status,
    description = EXCLUDED.description,
    "updatedAt" = EXCLUDED."updatedAt",
    enabled     = EXCLUDED.enabled;

WITH sub_base AS (
    SELECT
        pcs.subscriber_id,
        MIN(pcs.created_at) AS first_seen,
        MAX(COALESCE(pcs.last_event_at, pcs.created_at)) AS last_seen,
        COUNT(*) AS total_leads,
        SUM(COALESCE(pcs.total_events, 0)) AS total_events
    FROM public."PromptCrmSnapshots" pcs
    JOIN public."Campaigns" c ON c."campaignId" = pcs.campaign_id
    WHERE pcs.subscriber_id IS NOT NULL
    GROUP BY pcs.subscriber_id
)
INSERT INTO public."featuresPerSub"
(
    "subId", "featureId", uses,
    enabled, "createdAt", "updatedAt"
)
SELECT
    subscriber_id,
    201,
    GREATEST(total_leads, 1),
    TRUE,
    COALESCE(first_seen, NOW()),
    COALESCE(last_seen, NOW())
FROM sub_base
ON CONFLICT ("subId", "featureId") DO UPDATE
SET
    uses       = EXCLUDED.uses,
    enabled    = EXCLUDED.enabled,
    "updatedAt"= EXCLUDED."updatedAt";

WITH sub_base AS (
    SELECT
        pcs.subscriber_id,
        MIN(pcs.created_at) AS first_seen,
        MAX(COALESCE(pcs.last_event_at, pcs.created_at)) AS last_seen,
        COUNT(DISTINCT pcs.campaign_id) AS campaign_count
    FROM public."PromptCrmSnapshots" pcs
    JOIN public."Campaigns" c ON c."campaignId" = pcs.campaign_id
    WHERE pcs.subscriber_id IS NOT NULL
    GROUP BY pcs.subscriber_id
)
INSERT INTO public."featuresPerSub"
(
    "subId", "featureId", uses,
    enabled, "createdAt", "updatedAt"
)
SELECT
    subscriber_id,
    202,
    GREATEST(campaign_count * 10, 1),
    TRUE,
    COALESCE(first_seen, NOW()),
    COALESCE(last_seen, NOW())
FROM sub_base
WHERE campaign_count > 1
ON CONFLICT ("subId", "featureId") DO UPDATE
SET
    uses       = EXCLUDED.uses,
    enabled    = EXCLUDED.enabled,
    "updatedAt"= EXCLUDED."updatedAt";

-- --------------------------------------------------------------------------
-- Payments aggregated from PromptCRM subscriptions
-- --------------------------------------------------------------------------
WITH sub_base AS (
    SELECT
        pcs.subscriber_id,
        COALESCE(NULLIF(MAX(TRIM(pcs.subscriber_name)), ''), CONCAT('Subscriber ', pcs.subscriber_id)) AS subscriber_name,
        MAX(COALESCE(pcs.last_event_at, pcs.created_at)) AS last_seen,
        SUM(COALESCE(pcs.total_conversion_amount, 0)) AS total_conversion_amount,
        COUNT(DISTINCT pcs.campaign_id) AS campaign_count,
        MIN(c."companyId") AS company_id
    FROM public."PromptCrmSnapshots" pcs
    JOIN public."Campaigns" c ON c."campaignId" = pcs.campaign_id
    WHERE pcs.subscriber_id IS NOT NULL
    GROUP BY pcs.subscriber_id
)
INSERT INTO public."Payments"
(
    "paymentId", amount, "createdAt", "updatedAt",
    status, cheksum, "paymentTypeId",
    "companyId", "subId", "currencyId", "paymentMethodId"
)
SELECT
    700000 + ROW_NUMBER() OVER (ORDER BY subscriber_id),
    LEAST(99999999.99, ROUND(GREATEST(total_conversion_amount * 0.12, 149.99), 2)),
    COALESCE(last_seen, NOW()),
    COALESCE(last_seen, NOW()),
    'SETTLED',
    LPAD(md5(subscriber_name || COALESCE(company_id, 0)::text), 64, '0'),
    1,
    company_id,
    subscriber_id,
    CASE MOD(COALESCE(company_id, 1), 3)
        WHEN 0 THEN 1
        WHEN 1 THEN 2
        ELSE 3
    END,
    CASE WHEN campaign_count > 2 THEN 2 ELSE 1 END
FROM sub_base
WHERE company_id IS NOT NULL
ON CONFLICT ("paymentId") DO UPDATE
SET
    amount      = EXCLUDED.amount,
    status      = EXCLUDED.status,
    cheksum     = EXCLUDED.cheksum,
    "updatedAt" = EXCLUDED."updatedAt",
    "paymentMethodId" = EXCLUDED."paymentMethodId";

-- --------------------------------------------------------------------------
-- Providers, APIs and integration metadata
-- --------------------------------------------------------------------------
WITH provider_usage AS (
    SELECT
        5001 AS provider_id,
        1    AS provider_type_id,
        'PromptAds Data Lake' AS provider_name,
        'https://api.promptsales.local/ads' AS base_url,
        'INTEGRATED' AS status,
        CONCAT('Campaigns: ', COUNT(DISTINCT campaign_id), ' Ads: ', COUNT(DISTINCT ad_id)) AS description,
        MIN(COALESCE(start_date, NOW())) AS first_seen,
        MAX(COALESCE(load_ts, NOW())) AS last_seen
    FROM public."PromptAdsSnapshots"
    WHERE campaign_id IS NOT NULL
    UNION ALL
    SELECT
        5002,
        2,
        'PromptCRM Service',
        'https://api.promptsales.local/crm',
        'INTEGRATED',
        CONCAT('Subscribers: ', COUNT(DISTINCT subscriber_id), ' Leads: ', COUNT(*)),
        MIN(COALESCE(created_at, NOW())),
        MAX(COALESCE(load_ts, NOW()))
    FROM public."PromptCrmSnapshots"
    WHERE subscriber_id IS NOT NULL
)
INSERT INTO public."Providers"
(
    "providerId", "providerTypeId", name,
    "baseUrl", status, description,
    "createdAt", "updatedAt", enabled
)
SELECT
    provider_id,
    provider_type_id,
    provider_name,
    base_url,
    status,
    LEFT(description, 250),
    first_seen,
    last_seen,
    TRUE
FROM provider_usage
ON CONFLICT ("providerId") DO UPDATE
SET
    "providerTypeId" = EXCLUDED."providerTypeId",
    name        = EXCLUDED.name,
    "baseUrl"   = EXCLUDED."baseUrl",
    status      = EXCLUDED.status,
    description = EXCLUDED.description,
    "updatedAt" = EXCLUDED."updatedAt",
    enabled     = EXCLUDED.enabled;

INSERT INTO public."ProviderAPIs"
(
    "apiId", "providerId", name,
    "baseUrl", "authId", enabled,
    "createdAt", "updatedAt",
    request, response, endpoint, "typeId"
)
VALUES
    (
        7001, 5001, 'Campaign Metrics',
        'https://api.promptsales.local/ads', 1, TRUE,
        NOW(), NOW(),
        '{"resource":"campaigns","scope":"metrics"}'::jsonb,
        '{"status":"ok"}'::jsonb,
        '/v1/campaigns/metrics', 1
    ),
    (
        7002, 5002, 'Lead Activity Feed',
        'https://api.promptsales.local/crm', 2, TRUE,
        NOW(), NOW(),
        '{"resource":"leads","scope":"activity"}'::jsonb,
        '{"status":"ok"}'::jsonb,
        '/v1/leads/activity', 1
    )
ON CONFLICT ("apiId") DO UPDATE
SET
    name      = EXCLUDED.name,
    "baseUrl" = EXCLUDED."baseUrl",
    "authId"  = EXCLUDED."authId",
    request   = EXCLUDED.request,
    response  = EXCLUDED.response,
    endpoint  = EXCLUDED.endpoint,
    "typeId"  = EXCLUDED."typeId",
    "updatedAt"=EXCLUDED."updatedAt",
    enabled   = EXCLUDED.enabled;

INSERT INTO public."MCPServers"
(
    "mcpId", "providerId", name, url,
    "maxConcurrentCalls", "authId", enabled,
    "lastCall", "createdAt", "updatedAt"
)
VALUES
    (8001, 5001, 'PromptAds MCP', 'https://mcp.promptsales.local/ads', 8, 1, TRUE, NOW(), NOW(), CAST(EXTRACT(EPOCH FROM NOW()) AS INT)),
    (8002, 5002, 'PromptCRM MCP', 'https://mcp.promptsales.local/crm', 5, 2, TRUE, NOW(), NOW(), CAST(EXTRACT(EPOCH FROM NOW()) AS INT))
ON CONFLICT ("mcpId") DO UPDATE
SET
    "providerId" = EXCLUDED."providerId",
    name   = EXCLUDED.name,
    url    = EXCLUDED.url,
    "maxConcurrentCalls" = EXCLUDED."maxConcurrentCalls",
    "authId" = EXCLUDED."authId",
    enabled  = EXCLUDED.enabled,
    "lastCall"= EXCLUDED."lastCall",
    "updatedAt"=EXCLUDED."updatedAt";

WITH call_base AS (
    SELECT
        pas.campaign_id,
        pas.company_id,
        MAX(COALESCE(pas.load_ts, NOW())) AS last_load,
        COUNT(*) AS payloads
    FROM public."PromptAdsSnapshots" pas
    WHERE pas.company_id IS NOT NULL
    GROUP BY pas.campaign_id, pas.company_id
)
INSERT INTO public."IntegrationCalls"
(
    "callId", "companyId", "providerId",
    "apiId", "mcpToolId", operation,
    "responseTime", "excecutedAt", status, "updatedAt"
)
SELECT
    900000 + ROW_NUMBER() OVER (ORDER BY campaign_id),
    company_id,
    5001,
    7001,
    8001,
    CONCAT('SYNC_CAMPAIGN_', campaign_id),
    make_interval(secs => LEAST(payloads, 30)),
    last_load,
    'SUCCESS',
    last_load
FROM call_base
ON CONFLICT ("callId") DO NOTHING;

-- --------------------------------------------------------------------------
-- Contact methods per company derived from snapshot companies
-- --------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_company_contacts;

CREATE TEMP TABLE tmp_company_contacts AS
WITH company_base AS (
    SELECT
        c."companyId",
        COALESCE(NULLIF(c."companyName", ''), CONCAT('Company ', c."companyId")) AS company_name,
        COALESCE(c."createdAt", NOW()) AS created_at
    FROM public."Companies" c
)
SELECT
    company_base."companyId"             AS company_id,
    company_name,
    created_at,
    kinds.kind,
    (company_base."companyId" * 10) + kinds.offset_value AS type_id,
    (company_base."companyId" * 20) + kinds.offset_value AS method_id,
    CASE
        WHEN kinds.kind = 'EMAIL' THEN LOWER(regexp_replace(company_name, '[^a-z0-9]', '', 'g')) || '@promptcrm.local'
        ELSE CONCAT('+1', LPAD(((company_base."companyId" * 73) % 10000000)::text, 7, '0'))
    END AS contact_value
FROM company_base
CROSS JOIN (VALUES ('EMAIL', 1), ('PHONE', 2)) AS kinds(kind, offset_value);

INSERT INTO public."ContactMethodTypes" ("TypeId", name)
SELECT
    type_id,
    CASE WHEN kind = 'EMAIL'
         THEN CONCAT('Email - ', company_name)
         ELSE CONCAT('Phone - ', company_name)
    END
FROM tmp_company_contacts
ON CONFLICT ("TypeId") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public."ContactMethods"
(
    "contactMethodId", value, status,
    "createdAt", "updatedAt", enabled, "contactTypeId"
)
SELECT
    method_id,
    contact_value,
    'ACTIVE',
    created_at,
    NOW(),
    TRUE,
    type_id
FROM tmp_company_contacts
ON CONFLICT ("contactMethodId") DO UPDATE
SET
    value     = EXCLUDED.value,
    "updatedAt"= EXCLUDED."updatedAt",
    enabled   = EXCLUDED.enabled;

INSERT INTO public."contactCompany"
(
    "companyId", "contactMehodId", status,
    "createdAt", "updatedAt", enabled
)
SELECT
    company_id,
    method_id,
    CASE WHEN kind = 'EMAIL' THEN 'PRIMARY_EMAIL' ELSE 'PRIMARY_PHONE' END,
    created_at,
    NOW(),
    TRUE
FROM tmp_company_contacts
ON CONFLICT ("companyId", "contactMehodId") DO NOTHING;

-- --------------------------------------------------------------------------
-- Administrative data: modules, permissions, roles, users, logs
-- --------------------------------------------------------------------------
INSERT INTO public."Modules" ("moduleId", "moduleName")
VALUES
    (1, 'CRM Operations'),
    (2, 'Ad Intelligence'),
    (3, 'Billing Engine')
ON CONFLICT ("moduleId") DO UPDATE
SET "moduleName" = EXCLUDED."moduleName";

INSERT INTO public."Applications"
(
    "AppId", "appName", "appType", "moduleId"
)
VALUES
    (101, 'PromptCRM Portal', 'web', 1),
    (102, 'PromptAds Console', 'web', 2),
    (103, 'Billing Hub', 'internal', 3)
ON CONFLICT ("AppId") DO UPDATE
SET
    "appName" = EXCLUDED."appName",
    "appType" = EXCLUDED."appType",
    "moduleId"= EXCLUDED."moduleId";

INSERT INTO public."Roles"
(
    "roleId", "roleName", "roleStatus",
    "createdAt", "updatedAt"
)
VALUES
    (1, 'Administrator', 'ACTIVE', NOW(), NOW()),
    (2, 'Analyst', 'ACTIVE', NOW(), NOW()),
    (3, 'BillingManager', 'ACTIVE', NOW(), NOW())
ON CONFLICT ("roleId") DO UPDATE
SET
    "roleName" = EXCLUDED."roleName",
    "roleStatus" = EXCLUDED."roleStatus",
    "updatedAt" = EXCLUDED."updatedAt";

INSERT INTO public."Permissions"
(
    "permissionId", "permissionCode", "permissionStatus",
    "createdAt", "updatedAt", enabled, module
)
VALUES
    (1, 'CRM_VIEW', TRUE, NOW(), NOW(), TRUE, 1),
    (2, 'CRM_EDIT', TRUE, NOW(), NOW(), TRUE, 1),
    (3, 'ADS_VIEW', TRUE, NOW(), NOW(), TRUE, 2),
    (4, 'BILLING_ADMIN', TRUE, NOW(), NOW(), TRUE, 3)
ON CONFLICT ("permissionId") DO UPDATE
SET
    "permissionCode" = EXCLUDED."permissionCode",
    "permissionStatus"= EXCLUDED."permissionStatus",
    enabled           = EXCLUDED.enabled,
    module            = EXCLUDED.module,
    "updatedAt"       = EXCLUDED."updatedAt";

INSERT INTO public."PermissionsPerRole"
(
    "roleId", "permisionId", "createdAt", "updatedAt",
    enabled, status
)
VALUES
    (1, 1, NOW(), NOW(), TRUE, 'ACTIVE'),
    (1, 2, NOW(), NOW(), TRUE, 'ACTIVE'),
    (1, 3, NOW(), NOW(), TRUE, 'ACTIVE'),
    (1, 4, NOW(), NOW(), TRUE, 'ACTIVE'),
    (2, 1, NOW(), NOW(), TRUE, 'ACTIVE'),
    (2, 3, NOW(), NOW(), TRUE, 'ACTIVE'),
    (3, 3, NOW(), NOW(), TRUE, 'ACTIVE'),
    (3, 4, NOW(), NOW(), TRUE, 'ACTIVE')
ON CONFLICT ("roleId", "permisionId") DO UPDATE
SET
    enabled  = EXCLUDED.enabled,
    status   = EXCLUDED.status,
    "updatedAt" = EXCLUDED."updatedAt";

DROP TABLE IF EXISTS tmp_company_users;
CREATE TEMP TABLE tmp_company_users AS
WITH company_base AS (
    SELECT
        c."companyId",
        COALESCE(NULLIF(c."companyName", ''), CONCAT('Company ', c."companyId")) AS company_name,
        COALESCE(c."createdAt", NOW()) AS created_at
    FROM public."Companies" c
)
SELECT
    company_base."companyId"                       AS company_id,
    company_name,
    created_at,
    personas.persona,
    ROW_NUMBER() OVER (ORDER BY company_base."companyId", personas.persona) + 1000 AS user_id
FROM company_base
CROSS JOIN (VALUES ('Owner'), ('Analyst')) AS personas(persona);

INSERT INTO public."User"
(
    id, "userNationalId", "userFirstName", "userLastName",
    "userPassword", enabled, "createdAt", "updatedAt", "lastLogin"
)
SELECT
    user_id,
    user_id * 17,
    CASE WHEN persona = 'Owner' THEN CONCAT('Owner', company_id) ELSE CONCAT('Analyst', company_id) END,
    company_name,
    CONCAT('hashed-', md5(company_name || persona)),
    TRUE,
    created_at,
    NOW(),
    NOW()
FROM tmp_company_users
ON CONFLICT (id) DO UPDATE
SET
    "userFirstName" = EXCLUDED."userFirstName",
    "userLastName"  = EXCLUDED."userLastName",
    "userPassword"  = EXCLUDED."userPassword",
    enabled         = EXCLUDED.enabled,
    "updatedAt"     = EXCLUDED."updatedAt",
    "lastLogin"     = EXCLUDED."lastLogin";

INSERT INTO public."UserInCompany"
(
    "userId", "companyId", status,
    "createdAt", "updatedAt", enabled
)
SELECT
    user_id,
    company_id,
    persona,
    created_at,
    NOW(),
    TRUE
FROM tmp_company_users
ON CONFLICT ("userId", "companyId") DO UPDATE
SET
    status    = EXCLUDED.status,
    "updatedAt"= EXCLUDED."updatedAt",
    enabled   = EXCLUDED.enabled;

INSERT INTO public."RolesPerUser"
(
    "userId", "roleId", status,
    "createdAt", "upatedAt", enabled
)
SELECT
    user_id,
    CASE WHEN persona = 'Owner' THEN 1 ELSE 2 END,
    persona,
    NOW(),
    NOW(),
    TRUE
FROM tmp_company_users
UNION ALL
SELECT
    user_id,
    3,
    'Billing',
    NOW(),
    NOW(),
    TRUE
FROM tmp_company_users
WHERE persona = 'Owner'
ON CONFLICT ("userId", "roleId") DO UPDATE
SET
    status    = EXCLUDED.status,
    enabled   = EXCLUDED.enabled,
    "upatedAt"= EXCLUDED."upatedAt";

INSERT INTO public."UserPermissions"
(
    "permissionId", "userId", "permisionStatus",
    "createdAt", "updatedAt", enabled, "userEmail"
)
SELECT
    perm."permissionId",
    t.user_id,
    TRUE,
    NOW(),
    NOW(),
    TRUE,
    CASE
        WHEN perm."permissionCode" LIKE 'CRM%' THEN CONCAT('crm+', t.user_id, '@promptsales.local')
        WHEN perm."permissionCode" LIKE 'ADS%' THEN CONCAT('ads+', t.user_id, '@promptsales.local')
        ELSE CONCAT('ops+', t.user_id, '@promptsales.local')
    END
FROM tmp_company_users t
JOIN public."Permissions" perm
    ON (perm."permissionCode" IN ('CRM_VIEW','CRM_EDIT') AND t.persona = 'Owner')
    OR (perm."permissionCode" = 'CRM_VIEW' AND t.persona = 'Analyst')
    OR (perm."permissionCode" = 'ADS_VIEW' AND t.persona = 'Analyst')
    OR (perm."permissionCode" = 'BILLING_ADMIN' AND t.persona = 'Owner')
ON CONFLICT ("permissionId", "userId") DO UPDATE
SET
    "permisionStatus" = EXCLUDED."permisionStatus",
    enabled           = EXCLUDED.enabled,
    "updatedAt"       = EXCLUDED."updatedAt",
    "userEmail"       = EXCLUDED."userEmail";

INSERT INTO public."SystemLogTypes" ("systemLogTypeId", name)
VALUES
    (1, 'Synchronization'),
    (2, 'Alert')
ON CONFLICT ("systemLogTypeId") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public."logSources" ("logSourceId", name)
VALUES
    (1, 'PromptAds Loader'),
    (2, 'PromptCRM Loader')
ON CONFLICT ("logSourceId") DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public."LogLevels" ("logLevelId", name)
VALUES
    (1, 'INFO'),
    (2, 'WARN'),
    (3, 'ERROR')
ON CONFLICT ("logLevelId") DO UPDATE
SET name = EXCLUDED.name;

WITH log_data AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY campaign_id) + 400000 AS log_id,
        CONCAT('Campaign ', campaign_id, ' sync summary') AS description,
        MAX(COALESCE(load_ts, NOW())) AS event_time,
        campaign_id,
        company_id
    FROM public."PromptAdsSnapshots"
    WHERE campaign_id IS NOT NULL AND company_id IS NOT NULL
    GROUP BY campaign_id, company_id
    LIMIT 50
)
INSERT INTO public."SystemLogs"
(
    "systemLogId", description, "postTime", checksum,
    "systemLogTypeId", "moduleId", "userId",
    "logSourceId", "logLevelId"
)
SELECT
    log_id,
    description,
    event_time,
    md5(description),
    1,
    2,
    (SELECT MIN(user_id) FROM tmp_company_users WHERE company_id = log_data.company_id),
    1,
    1
FROM log_data
ON CONFLICT ("systemLogId") DO NOTHING;

COMMIT;
