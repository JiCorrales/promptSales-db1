
CREATE OR ALTER VIEW crm.vwPromptCrmSummary
AS
WITH LeadEventStats AS (
    SELECT
        le.leadId,
        COUNT_BIG(*)                       AS totalEvents,
        MAX(le.occurredAt)                 AS lastEventAt
    FROM crm.LeadEvents le
    GROUP BY le.leadId
),
LeadConversionStats AS (
    SELECT
        lc.leadId,
        COUNT_BIG(*)                       AS conversionEvents,
        SUM(lc.conversionValue)            AS totalConversionAmount
    FROM crm.LeadConversions lc
    WHERE lc.enabled = 1
    GROUP BY lc.leadId
),
LatestLeadSource AS (
    SELECT
        lsx.leadId,
        lsx.leadSourceId,
        lsx.campaignKey,
        lsx.leadSourceTypeId,
        lsx.leadSourceSystemId,
        lsx.leadMediumId,
        lsx.leadOriginChannelId,
        ROW_NUMBER() OVER (
            PARTITION BY lsx.leadId
            ORDER BY lsx.createdAt DESC, lsx.leadSourceId DESC
        ) AS rn
    FROM crm.LeadSources lsx
    WHERE lsx.enabled = 1
)
SELECT
    l.leadId                               AS lead_id,
    l.leadToken                            AS lead_token,
    l.createdAt                            AS created_at,
    lss.systemName                         AS utm_source,
    lm.leadMediumName                      AS utm_medium,
    src.campaignKey                        AS utm_campaign,
    l.firstName                            AS first_name,
    l.lastName                             AS last_name,
    l.email,
    l.phoneNumber                          AS phone_number,
    l.lead_score,
    ls.leadStatusName                      AS lead_status,

    sub.subscriberId                       AS subscriber_id,
    sub.legalName                          AS subscriber_name,

    src.leadSourceId                       AS marketing_channel_id,
    loc.leadOriginChannelName              AS channel_name,
    CONVERT(varchar(60), lst.sourceTypeName) AS channel_type_name,

    CAST(NULL AS int)                      AS assigned_to_user_id,
    CAST(NULL AS varchar(200))             AS assigned_user_name,

    CAST(NULL AS datetime2)                AS assigned_at,
    CAST(NULL AS datetime2)                AS last_contacted_at,
    CAST(NULL AS datetime2)                AS next_followup_date,

    ISNULL(e.totalEvents, 0)               AS total_events,
    ISNULL(c.conversionEvents, 0)          AS conversion_events,
    ISNULL(c.totalConversionAmount, 0)     AS total_conversion_amount,
    e.lastEventAt                          AS last_event_at
FROM crm.Leads l
JOIN crm.Subscribers sub        ON sub.subscriberId     = l.subscriberId
LEFT JOIN crm.LeadStatus ls     ON ls.leadStatusId      = l.leadStatusId
LEFT JOIN LatestLeadSource src  ON src.leadId           = l.leadId AND src.rn = 1
LEFT JOIN crm.LeadSourceTypes lst        ON lst.leadSourceTypeId     = src.leadSourceTypeId
LEFT JOIN crm.LeadSourceSystems lss      ON lss.leadSourceSystemId   = src.leadSourceSystemId
LEFT JOIN crm.LeadMediums lm             ON lm.leadMediumId          = src.leadMediumId
LEFT JOIN crm.LeadOriginChannels loc     ON loc.leadOriginChannelId  = src.leadOriginChannelId
LEFT JOIN LeadEventStats e               ON e.leadId                 = l.leadId
LEFT JOIN LeadConversionStats c          ON c.leadId                 = l.leadId;
