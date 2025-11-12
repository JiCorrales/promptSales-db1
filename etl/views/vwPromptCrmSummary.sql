
CREATE OR ALTER VIEW crm.vwPromptCrmSummary
AS
SELECT
    l.lead_id,
    l.lead_token,
    l.created_at,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    l.first_name,
    l.last_name,
    l.email,
    l.phone_number,
    l.lead_score,
    sc.status_name                                    AS lead_status,

    sub.subscriber_id,
    sub.legal_name                                    AS subscriber_name,

    mc.marketing_channel_id,
    mc.channel_name,
    mct.channel_type_name,

    l.assigned_to_user_id,
    CONCAT(au.first_name, ' ', au.last_name)          AS assigned_user_name, 

    l.assigned_at,
    l.last_contacted_at,
    l.next_followup_date,

    COUNT(le.lead_event_id)                           AS total_events,
    SUM(CASE WHEN let.event_type_name = 'Conversion' THEN 1 ELSE 0 END)      AS conversion_events,
    SUM(ISNULL(le.conversion_amount, 0))              AS total_conversion_amount,
    MAX(le.occurred_at)                               AS last_event_at
FROM crm.Leads l
JOIN crm.Subscribers sub                 ON sub.subscriber_id     = l.subscriber_id
LEFT JOIN crm.Status_catalog sc          ON sc.status_catalog_id  = l.status_catalog_id
LEFT JOIN crm.Marketing_channels mc      ON mc.marketing_channel_id = l.marketing_channel_id
LEFT JOIN crm.Marketing_channel_types mct ON mct.channel_type_id  = mc.channel_type_id
LEFT JOIN crm.Users au                   ON au.user_id            = l.assigned_to_user_id
LEFT JOIN crm.Lead_events le             ON le.lead_id            = l.lead_id
LEFT JOIN crm.Lead_event_types let       ON let.event_type_id     = le.event_type_id
WHERE l.deleted_at IS NULL
GROUP BY
    l.lead_id, l.lead_token, l.created_at,
    l.utm_source, l.utm_medium, l.utm_campaign,
    l.first_name, l.last_name, l.email, l.phone_number, l.lead_score,
    sc.status_name,
    sub.subscriber_id, sub.legal_name,
    mc.marketing_channel_id, mc.channel_name,
    mct.channel_type_name,
    l.assigned_to_user_id, au.first_name, au.last_name,
    l.assigned_at, l.last_contacted_at, l.next_followup_date,
    l.converted_to_customer_at, l.conversion_value;
