-- ============================================================
-- Load data from RawPromptAds into the PromptSales core tables
-- ============================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public."PromptAdsSnapshots"
(
    raw_id              BIGINT PRIMARY KEY,
    campaign_id         BIGINT,
    campaign_name       VARCHAR(200),
    start_date          TIMESTAMPTZ,
    end_date            TIMESTAMPTZ,
    campaign_budget     NUMERIC(12,2),
    company_id          BIGINT,
    company_name        VARCHAR(200),
    ad_id               BIGINT,
    ad_name             VARCHAR(200),
    ad_created_at       TIMESTAMPTZ,
    ad_enabled          BOOLEAN,
    ad_status           VARCHAR(50),
    ad_type             VARCHAR(50),
    channels            TEXT,
    target_markets      TEXT,
    total_impressions   BIGINT,
    total_clicks        BIGINT,
    total_interactions  BIGINT,
    total_reach         BIGINT,
    total_hours_viewed  NUMERIC(18,3),
    total_cost          NUMERIC(14,2),
    total_revenue       NUMERIC(14,2),
    snapshot_date       DATE,
    source_system       VARCHAR(30),
    source_view         VARCHAR(128),
    etl_run_id          BIGINT,
    raw_checksum        CHAR(64),
    load_ts             TIMESTAMPTZ
);

INSERT INTO public."PromptAdsSnapshots" (
    raw_id, campaign_id, campaign_name,
    start_date, end_date, campaign_budget,
    company_id, company_name,
    ad_id, ad_name, ad_created_at, ad_enabled, ad_status, ad_type,
    channels, target_markets,
    total_impressions, total_clicks, total_interactions,
    total_reach, total_hours_viewed, total_cost, total_revenue,
    snapshot_date, source_system, source_view,
    etl_run_id, raw_checksum, load_ts
)
SELECT
    raw_id, campaign_id, campaign_name,
    start_date, end_date, campaign_budget,
    company_id, company_name,
    ad_id, ad_name, ad_created_at, ad_enabled, ad_status, ad_type,
    channels, target_markets,
    total_impressions, total_clicks, total_interactions,
    total_reach, total_hours_viewed, total_cost, total_revenue,
    snapshot_date, source_system, source_view,
    etl_run_id, raw_checksum, load_ts
FROM public."RawPromptAds"
ON CONFLICT (raw_id) DO UPDATE
SET
    campaign_id        = EXCLUDED.campaign_id,
    campaign_name      = EXCLUDED.campaign_name,
    start_date         = EXCLUDED.start_date,
    end_date           = EXCLUDED.end_date,
    campaign_budget    = EXCLUDED.campaign_budget,
    company_id         = EXCLUDED.company_id,
    company_name       = EXCLUDED.company_name,
    ad_id              = EXCLUDED.ad_id,
    ad_name            = EXCLUDED.ad_name,
    ad_created_at      = EXCLUDED.ad_created_at,
    ad_enabled         = EXCLUDED.ad_enabled,
    ad_status          = EXCLUDED.ad_status,
    ad_type            = EXCLUDED.ad_type,
    channels           = EXCLUDED.channels,
    target_markets     = EXCLUDED.target_markets,
    total_impressions  = EXCLUDED.total_impressions,
    total_clicks       = EXCLUDED.total_clicks,
    total_interactions = EXCLUDED.total_interactions,
    total_reach        = EXCLUDED.total_reach,
    total_hours_viewed = EXCLUDED.total_hours_viewed,
    total_cost         = EXCLUDED.total_cost,
    total_revenue      = EXCLUDED.total_revenue,
    snapshot_date      = EXCLUDED.snapshot_date,
    source_system      = EXCLUDED.source_system,
    source_view        = EXCLUDED.source_view,
    etl_run_id         = EXCLUDED.etl_run_id,
    raw_checksum       = EXCLUDED.raw_checksum,
    load_ts            = EXCLUDED.load_ts;

DROP TABLE IF EXISTS tmp_promptads_campaigns;

CREATE TEMP TABLE tmp_promptads_campaigns AS
SELECT
    campaign_id::int                               AS campaign_id,
    MAX(campaign_name)                             AS campaign_name,
    MAX(company_id)::int                           AS company_id,
    MAX(company_name)                              AS company_name,
    MIN(start_date)                                AS start_date,
    MAX(end_date)                                  AS end_date,
    MAX(campaign_budget)                           AS campaign_budget,
    STRING_AGG(DISTINCT channels, ', ' ORDER BY channels)
        FILTER (WHERE channels IS NOT NULL AND channels <> '') AS channels,
    STRING_AGG(DISTINCT target_markets, ', ' ORDER BY target_markets)
        FILTER (WHERE target_markets IS NOT NULL AND target_markets <> '') AS target_markets,
    SUM(total_impressions)                         AS total_impressions,
    SUM(total_clicks)                              AS total_clicks,
    SUM(total_interactions)                        AS total_interactions,
    SUM(total_reach)                               AS total_reach,
    SUM(total_hours_viewed)                        AS total_hours_viewed,
    SUM(total_cost)                                AS total_cost,
    SUM(total_revenue)                             AS total_revenue,
    MAX(snapshot_date)                             AS snapshot_date,
    MAX(load_ts)                                   AS last_load_ts
FROM public."RawPromptAds"
GROUP BY campaign_id;

-- Upsert companies that own the campaigns
INSERT INTO public."Companies"
(
    "companyId", legalld, "companyName", "legalName",
    status, "createdAt", "updatedAt", enabled
)
SELECT DISTINCT
    t.company_id,
    t.company_id,
    COALESCE(t.company_name, CONCAT('Company ', t.company_id::text)),
    COALESCE(t.company_name, CONCAT('Company ', t.company_id::text)),
    'ACTIVE',
    COALESCE(t.start_date::date, CURRENT_DATE),
    COALESCE(t.last_load_ts::date, CURRENT_DATE),
    TRUE
FROM tmp_promptads_campaigns t
ON CONFLICT ("companyId") DO UPDATE
SET
    "companyName" = EXCLUDED."companyName",
    "legalName"   = EXCLUDED."legalName",
    status        = EXCLUDED.status,
    "updatedAt"   = EXCLUDED."updatedAt";

-- Upsert interaction metrics aggregated per campaign
INSERT INTO public."Interactions"
(
    "interactionId", clicks, likes, comments, reactions, shares, "usersReached"
)
SELECT
    t.campaign_id,
    COALESCE(t.total_clicks, 0),
    NULL,
    NULL,
    COALESCE(t.total_interactions, 0),
    NULL,
    COALESCE(t.total_reach, 0)
FROM tmp_promptads_campaigns t
ON CONFLICT ("interactionId") DO UPDATE
SET
    clicks       = EXCLUDED.clicks,
    reactions    = EXCLUDED.reactions,
    "usersReached" = EXCLUDED."usersReached";

-- Upsert financial calculations for each campaign
INSERT INTO public."Calculations"
(
    "calculoId", "clickRate", "conversionRate", "ROI",
    "engagementRate", "createdAt", "totalSpent", "totalRevenue"
)
SELECT
    t.campaign_id,
    CASE WHEN t.total_impressions > 0
         THEN ROUND(t.total_clicks::numeric / t.total_impressions, 4)
         ELSE 0 END,
    0, -- No conversion count available in PromptAds
    CASE WHEN t.total_cost > 0
         THEN ROUND( (t.total_revenue - t.total_cost) / t.total_cost, 4)
         ELSE 0 END,
    CASE WHEN t.total_reach > 0
         THEN ROUND(t.total_interactions::numeric / t.total_reach, 4)
         ELSE 0 END,
    COALESCE(t.last_load_ts, NOW()),
    LEAST(COALESCE(t.total_cost, 0),        99999999.99),
    LEAST(COALESCE(t.total_revenue, 0),     99999999.99)
FROM tmp_promptads_campaigns t
ON CONFLICT ("calculoId") DO UPDATE
SET
    "clickRate"     = EXCLUDED."clickRate",
    "ROI"           = EXCLUDED."ROI",
    "engagementRate"= EXCLUDED."engagementRate",
    "totalSpent"    = EXCLUDED."totalSpent",
    "totalRevenue"  = EXCLUDED."totalRevenue",
    "createdAt"     = EXCLUDED."createdAt";

-- Upsert campaigns connected to the metrics above
INSERT INTO public."Campaigns"
(
    "campaignId", "companyId", name, status,
    "startDate", "endDate", enabled, "budgetAmount",
    "createdAt", "updatedAt", description,
    "intereractionsId", "calculatiosId"
)
SELECT
    t.campaign_id,
    t.company_id,
    COALESCE(t.campaign_name, CONCAT('Campaign ', t.campaign_id::text)),
    CASE
        WHEN t.end_date IS NOT NULL AND t.end_date < NOW() THEN 'COMPLETED'
        ELSE 'ACTIVE'
    END,
    COALESCE(t.start_date, NOW()),
    t.end_date,
    TRUE,
    LEAST(COALESCE(t.campaign_budget, 0), 99999999.99),
    COALESCE(t.snapshot_date::timestamp, NOW()),
    COALESCE(t.last_load_ts, NOW()),
    LEFT(
        CONCAT(
            'Channels: ', COALESCE(t.channels, 'N/A'),
            ' | Markets: ', COALESCE(t.target_markets, 'N/A')
        ),
        200
    ),
    t.campaign_id,
    t.campaign_id
FROM tmp_promptads_campaigns t
ON CONFLICT ("campaignId") DO UPDATE
SET
    "companyId"  = EXCLUDED."companyId",
    name         = EXCLUDED.name,
    status       = EXCLUDED.status,
    "startDate"  = EXCLUDED."startDate",
    "endDate"    = EXCLUDED."endDate",
    enabled      = EXCLUDED.enabled,
    "budgetAmount" = EXCLUDED."budgetAmount",
    "updatedAt"  = EXCLUDED."updatedAt",
    description  = EXCLUDED.description,
    "intereractionsId" = EXCLUDED."intereractionsId",
    "calculatiosId"    = EXCLUDED."calculatiosId";

DROP TABLE IF EXISTS tmp_promptads_campaigns;

COMMIT;
