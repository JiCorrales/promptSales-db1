-- ============================================================
-- Load data from RawPromptCrm into the PromptSales core tables
-- ============================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public."PromptCrmSnapshots"
(
    raw_id                  BIGINT PRIMARY KEY,
    lead_id                 BIGINT,
    lead_token              VARCHAR(100),
    created_at              TIMESTAMPTZ,
    utm_source              VARCHAR(100),
    utm_medium              VARCHAR(100),
    utm_campaign            VARCHAR(150),
    first_name              VARCHAR(120),
    last_name               VARCHAR(120),
    email                   VARCHAR(200),
    phone_number            VARCHAR(40),
    lead_score              NUMERIC(6,2),
    lead_status             VARCHAR(60),
    subscriber_id           BIGINT,
    subscriber_name         VARCHAR(200),
    marketing_channel_id    BIGINT,
    channel_name            VARCHAR(120),
    channel_type_name       VARCHAR(120),
    assigned_to_user_id     BIGINT,
    assigned_user_name      VARCHAR(200),
    assigned_at             TIMESTAMPTZ,
    last_contacted_at       TIMESTAMPTZ,
    next_followup_date      DATE,
    total_events            BIGINT,
    conversion_events       BIGINT,
    total_conversion_amount NUMERIC(14,2),
    last_event_at           TIMESTAMPTZ,
    snapshot_date           DATE,
    source_system           VARCHAR(30),
    source_view             VARCHAR(128),
    etl_run_id              BIGINT,
    raw_checksum            CHAR(64),
    load_ts                 TIMESTAMPTZ,
    campaign_id             BIGINT
);

ALTER TABLE public."PromptCrmSnapshots"
    ADD COLUMN IF NOT EXISTS campaign_id BIGINT;

WITH enriched AS (
    SELECT
        r.*,
        CASE
            WHEN COALESCE(r.utm_campaign, '') ~ '[0-9]'
                THEN CAST(regexp_replace(r.utm_campaign, '[^0-9]', '', 'g') AS BIGINT)
            ELSE NULL
        END AS campaign_id
    FROM public."RawPromptCrm" r
)
INSERT INTO public."PromptCrmSnapshots" (
    raw_id, lead_id, lead_token, created_at,
    utm_source, utm_medium, utm_campaign,
    first_name, last_name, email, phone_number,
    lead_score, lead_status,
    subscriber_id, subscriber_name,
    marketing_channel_id, channel_name, channel_type_name,
    assigned_to_user_id, assigned_user_name,
    assigned_at, last_contacted_at, next_followup_date,
    total_events, conversion_events, total_conversion_amount,
    last_event_at,
    snapshot_date, source_system, source_view,
    etl_run_id, raw_checksum, load_ts,
    campaign_id
)
SELECT
    raw_id, lead_id, lead_token, created_at,
    utm_source, utm_medium, utm_campaign,
    first_name, last_name, email, phone_number,
    lead_score, lead_status,
    subscriber_id, subscriber_name,
    marketing_channel_id, channel_name, channel_type_name,
    assigned_to_user_id, assigned_user_name,
    assigned_at, last_contacted_at, next_followup_date,
    total_events, conversion_events, total_conversion_amount,
    last_event_at,
    snapshot_date, source_system, source_view,
    etl_run_id, raw_checksum, load_ts,
    campaign_id
FROM enriched
ON CONFLICT (raw_id) DO UPDATE
SET
    lead_id                 = EXCLUDED.lead_id,
    lead_token              = EXCLUDED.lead_token,
    created_at              = EXCLUDED.created_at,
    utm_source              = EXCLUDED.utm_source,
    utm_medium              = EXCLUDED.utm_medium,
    utm_campaign            = EXCLUDED.utm_campaign,
    first_name              = EXCLUDED.first_name,
    last_name               = EXCLUDED.last_name,
    email                   = EXCLUDED.email,
    phone_number            = EXCLUDED.phone_number,
    lead_score              = EXCLUDED.lead_score,
    lead_status             = EXCLUDED.lead_status,
    subscriber_id           = EXCLUDED.subscriber_id,
    subscriber_name         = EXCLUDED.subscriber_name,
    marketing_channel_id    = EXCLUDED.marketing_channel_id,
    channel_name            = EXCLUDED.channel_name,
    channel_type_name       = EXCLUDED.channel_type_name,
    assigned_to_user_id     = EXCLUDED.assigned_to_user_id,
    assigned_user_name      = EXCLUDED.assigned_user_name,
    assigned_at             = EXCLUDED.assigned_at,
    last_contacted_at       = EXCLUDED.last_contacted_at,
    next_followup_date      = EXCLUDED.next_followup_date,
    total_events            = EXCLUDED.total_events,
    conversion_events       = EXCLUDED.conversion_events,
    total_conversion_amount = EXCLUDED.total_conversion_amount,
    last_event_at           = EXCLUDED.last_event_at,
    snapshot_date           = EXCLUDED.snapshot_date,
    source_system           = EXCLUDED.source_system,
    source_view             = EXCLUDED.source_view,
    etl_run_id              = EXCLUDED.etl_run_id,
    raw_checksum            = EXCLUDED.raw_checksum,
    load_ts                 = EXCLUDED.load_ts,
    campaign_id             = EXCLUDED.campaign_id;

DROP TABLE IF EXISTS tmp_promptcrm_leads;

CREATE TEMP TABLE tmp_promptcrm_leads AS
SELECT
    lead_id::int                                            AS lead_id,
    lead_token,
    created_at,
    COALESCE(utm_source, '')                                AS utm_source,
    COALESCE(utm_medium, '')                                AS utm_medium,
    COALESCE(utm_campaign, '')                              AS utm_campaign,
    COALESCE(first_name, '')                                AS first_name,
    COALESCE(last_name, '')                                 AS last_name,
    email,
    phone_number,
    lead_score,
    lead_status,
    subscriber_id::int                                      AS subscriber_id,
    COALESCE(subscriber_name, 'Unknown Subscriber')         AS subscriber_name,
    marketing_channel_id::int                               AS marketing_channel_id,
    channel_name,
    channel_type_name,
    assigned_to_user_id,
    assigned_user_name,
    assigned_at,
    last_contacted_at,
    next_followup_date,
    total_events,
    conversion_events,
    total_conversion_amount,
    last_event_at,
    snapshot_date,
    load_ts,
    campaign_id
FROM public."PromptCrmSnapshots";

-- Remove leads that cannot be linked to a campaign
DELETE FROM tmp_promptcrm_leads
WHERE campaign_id IS NULL;

-- Ensure there is a "country" row per lead (the schema requires the FK)
INSERT INTO public."Country" ("countryId", name)
SELECT DISTINCT
    lead_id,
    subscriber_name
FROM tmp_promptcrm_leads
ON CONFLICT ("countryId") DO UPDATE
SET
    name = EXCLUDED.name;

-- Upsert normalized leads
INSERT INTO public."Leads"
(
    "leadId", "campaignId", "sourceSystem",
    name, email, "number", "countryId",
    status, score, "createdAt", "updatedAt", enabled
)
SELECT
    t.lead_id,
    t.campaign_id,
    NULLIF(t.marketing_channel_id, 0),
    LEFT(TRIM(CONCAT(t.first_name, ' ', t.last_name)), 60),
    LEFT(COALESCE(t.email, CONCAT(t.lead_token, '@promptcrm.local')), 60),
    LEFT(COALESCE(t.phone_number, 'N/A'), 20),
    t.lead_id,
    LEFT(COALESCE(t.lead_status, 'NEW'), 30),
    ROUND(COALESCE(t.lead_score, 0)::numeric, 1),
    t.created_at,
    COALESCE(t.last_event_at, t.created_at),
    TRUE
FROM tmp_promptcrm_leads t
JOIN public."Campaigns" c ON c."campaignId" = t.campaign_id
ON CONFLICT ("leadId") DO UPDATE
SET
    "campaignId" = EXCLUDED."campaignId",
    "sourceSystem" = EXCLUDED."sourceSystem",
    name         = EXCLUDED.name,
    email        = EXCLUDED.email,
    "number"     = EXCLUDED."number",
    status       = EXCLUDED.status,
    score        = EXCLUDED.score,
    "updatedAt"  = EXCLUDED."updatedAt",
    enabled      = EXCLUDED.enabled;

DROP TABLE IF EXISTS tmp_promptcrm_leads;

COMMIT;
