-- =============================================
-- PromptCRM - Seed Data: Automation & External Systems
-- =============================================
-- Author: Alberto Bofi / Claude Code
-- Date: 2025-11-21
-- Purpose: Populate automation-related catalogs
-- =============================================

USE PromptCRM;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'SEEDING AUTOMATION CATALOGS';
PRINT '========================================';
PRINT '';

-- =============================================
-- TRIGGER CAUSE TYPES
-- =============================================
PRINT 'Inserting Trigger Cause Types...';

SET IDENTITY_INSERT [crm].[TriggerCauseTypes] ON;

INSERT INTO [crm].[TriggerCauseTypes] (triggerCauseTypeId, triggerCauseKey, triggerCauseName, description, enabled)
VALUES
    (1, 'EVENT', 'Event Triggered', 'Triggered by lead event', 1),
    (2, 'SCORE_CHANGE', 'Score Change', 'Lead score changed', 1),
    (3, 'STATUS_CHANGE', 'Status Change', 'Lead status changed', 1),
    (4, 'TIME_BASED', 'Time-Based', 'Scheduled/time-based trigger', 1),
    (5, 'MANUAL', 'Manual', 'Manually triggered', 1),
    (6, 'API', 'API Triggered', 'Triggered via API', 1);

SET IDENTITY_INSERT [crm].[TriggerCauseTypes] OFF;

PRINT '  ✓ Inserted 6 trigger cause types';

-- =============================================
-- AUTOMATION ACTION TYPES
-- =============================================
PRINT 'Inserting Automation Action Types...';

SET IDENTITY_INSERT [crm].[AutomationActionTypes] ON;

INSERT INTO [crm].[AutomationActionTypes] (automationActionTypeId, actionTypeKey, actionTypeName, description, enabled)
VALUES
    (1, 'SEND_EMAIL', 'Send Email', 'Send email to lead', 1),
    (2, 'SEND_SMS', 'Send SMS', 'Send SMS to lead', 1),
    (3, 'SEND_WHATSAPP', 'Send WhatsApp', 'Send WhatsApp message', 1),
    (4, 'UPDATE_SCORE', 'Update Lead Score', 'Update lead score', 1),
    (5, 'CHANGE_STATUS', 'Change Status', 'Change lead status', 1),
    (6, 'MOVE_FUNNEL_STAGE', 'Move Funnel Stage', 'Move to different stage', 1),
    (7, 'ADD_TAG', 'Add Tag', 'Add tag to lead', 1),
    (8, 'REMOVE_TAG', 'Remove Tag', 'Remove tag from lead', 1),
    (9, 'ASSIGN_TO_USER', 'Assign to User', 'Assign lead to user', 1),
    (10, 'CREATE_TASK', 'Create Task', 'Create task for user', 1),
    (11, 'WEBHOOK', 'Call Webhook', 'Call external webhook', 1),
    (12, 'MCP_CALL', 'MCP Server Call', 'Call MCP server', 1),
    (13, 'WAIT', 'Wait/Delay', 'Wait before next action', 1),
    (14, 'CONDITIONAL', 'Conditional Branch', 'Conditional logic', 1);

SET IDENTITY_INSERT [crm].[AutomationActionTypes] OFF;

PRINT '  ✓ Inserted 14 automation action types';

-- =============================================
-- EXTERNAL SYSTEMS
-- =============================================
PRINT 'Inserting External Systems...';

SET IDENTITY_INSERT [crm].[ExternalSystems] ON;

INSERT INTO [crm].[ExternalSystems] (externalSystemId, externalSystemKey, externalSystemName, description, enabled)
VALUES
    (1, 'MAILCHIMP', 'Mailchimp', 'Email marketing platform', 1),
    (2, 'SENDGRID', 'SendGrid', 'Email delivery service', 1),
    (3, 'TWILIO', 'Twilio', 'SMS/Voice platform', 1),
    (4, 'WHATSAPP_API', 'WhatsApp Business API', 'WhatsApp messaging', 1),
    (5, 'HUBSPOT', 'HubSpot', 'HubSpot CRM', 1),
    (6, 'SALESFORCE', 'Salesforce', 'Salesforce CRM', 1),
    (7, 'ZENDESK', 'Zendesk', 'Customer support', 1),
    (8, 'INTERCOM', 'Intercom', 'Customer messaging', 1),
    (9, 'SLACK', 'Slack', 'Team messaging', 1),
    (10, 'ZAPIER', 'Zapier', 'Automation platform', 1),
    (11, 'N8N', 'n8n', 'Workflow automation', 1),
    (12, 'GOOGLE_ADS', 'Google Ads', 'Google advertising', 1),
    (13, 'META_ADS', 'Meta Ads', 'Facebook/Instagram ads', 1),
    (14, 'OPENAI', 'OpenAI', 'OpenAI API', 1),
    (15, 'ANTHROPIC', 'Anthropic', 'Claude API', 1);

SET IDENTITY_INSERT [crm].[ExternalSystems] OFF;

PRINT '  ✓ Inserted 15 external systems';

PRINT '';
PRINT '========================================';
PRINT 'AUTOMATION CATALOGS SEEDED SUCCESSFULLY';
PRINT '========================================';
PRINT '';

GO
