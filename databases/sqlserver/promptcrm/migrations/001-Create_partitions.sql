USE PromptCRM;
GO

PRINT 'Creating partition functions...';
PRINT '';

-- Partition function for LeadEvents (by occurredAt)
-- 60 monthly partitions = 5 years (2024-2028)
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_LeadEvents_ByMonth')
BEGIN
    CREATE PARTITION FUNCTION PF_LeadEvents_ByMonth (datetime2)
    AS RANGE RIGHT FOR VALUES (
        '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01', '2024-05-01', '2024-06-01',
        '2024-07-01', '2024-08-01', '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
        '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01',
        '2025-07-01', '2025-08-01', '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01',
        '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', '2026-05-01', '2026-06-01',
        '2026-07-01', '2026-08-01', '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01',
        '2027-01-01', '2027-02-01', '2027-03-01', '2027-04-01', '2027-05-01', '2027-06-01',
        '2027-07-01', '2027-08-01', '2027-09-01', '2027-10-01', '2027-11-01', '2027-12-01',
        '2028-01-01', '2028-02-01', '2028-03-01', '2028-04-01', '2028-05-01', '2028-06-01',
        '2028-07-01', '2028-08-01', '2028-09-01', '2028-10-01', '2028-11-01', '2028-12-01'
    );
    PRINT 'Partition function PF_LeadEvents_ByMonth created (60 partitions)';
END
ELSE
BEGIN
    PRINT 'Partition function PF_LeadEvents_ByMonth already exists';
END
GO

-- Partition function for ApiRequestLog (by requestAt)
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_ApiLog_ByMonth')
BEGIN
    CREATE PARTITION FUNCTION PF_ApiLog_ByMonth (datetime2)
    AS RANGE RIGHT FOR VALUES (
        '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01', '2024-05-01', '2024-06-01',
        '2024-07-01', '2024-08-01', '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
        '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01',
        '2025-07-01', '2025-08-01', '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01',
        '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', '2026-05-01', '2026-06-01',
        '2026-07-01', '2026-08-01', '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01',
        '2027-01-01', '2027-02-01', '2027-03-01', '2027-04-01', '2027-05-01', '2027-06-01',
        '2027-07-01', '2027-08-01', '2027-09-01', '2027-10-01', '2027-11-01', '2027-12-01',
        '2028-01-01', '2028-02-01', '2028-03-01', '2028-04-01', '2028-05-01', '2028-06-01',
        '2028-07-01', '2028-08-01', '2028-09-01', '2028-10-01', '2028-11-01', '2028-12-01'
    );
    PRINT 'Partition function PF_ApiLog_ByMonth created (60 partitions)';
END
ELSE
BEGIN
    PRINT 'Partition function PF_ApiLog_ByMonth already exists';
END
GO

-- Partition function for Logs (by createdAt)
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_Logs_ByMonth')
BEGIN
    CREATE PARTITION FUNCTION PF_Logs_ByMonth (datetime2)
    AS RANGE RIGHT FOR VALUES (
        '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01', '2024-05-01', '2024-06-01',
        '2024-07-01', '2024-08-01', '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
        '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01',
        '2025-07-01', '2025-08-01', '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01',
        '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', '2026-05-01', '2026-06-01',
        '2026-07-01', '2026-08-01', '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01'
    );
    PRINT 'Partition function PF_Logs_ByMonth created (36 partitions)';
END
ELSE
BEGIN
    PRINT 'Partition function PF_Logs_ByMonth already exists';
END
GO

-- Partition function for Transactions (by createdAt/processedAt)
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_Transactions_ByMonth')
BEGIN
    CREATE PARTITION FUNCTION PF_Transactions_ByMonth (datetime2)
    AS RANGE RIGHT FOR VALUES (
        '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01', '2024-05-01', '2024-06-01',
        '2024-07-01', '2024-08-01', '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
        '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01', '2025-06-01',
        '2025-07-01', '2025-08-01', '2025-09-01', '2025-10-01', '2025-11-01', '2025-12-01',
        '2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', '2026-05-01', '2026-06-01',
        '2026-07-01', '2026-08-01', '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01',
        '2027-01-01', '2027-02-01', '2027-03-01', '2027-04-01', '2027-05-01', '2027-06-01',
        '2027-07-01', '2027-08-01', '2027-09-01', '2027-10-01', '2027-11-01', '2027-12-01',
        '2028-01-01', '2028-02-01', '2028-03-01', '2028-04-01', '2028-05-01', '2028-06-01',
        '2028-07-01', '2028-08-01', '2028-09-01', '2028-10-01', '2028-11-01', '2028-12-01'
    );
    PRINT 'Partition function PF_Transactions_ByMonth created (60 partitions)';
END
ELSE
BEGIN
    PRINT 'Partition function PF_Transactions_ByMonth already exists';
END
GO

PRINT '';

PRINT 'Creating partition schemes...';
PRINT '';

-- Partition scheme for LeadEvents
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_LeadEvents_ByMonth')
BEGIN
    CREATE PARTITION SCHEME PS_LeadEvents_ByMonth
    AS PARTITION PF_LeadEvents_ByMonth
    ALL TO ([PRIMARY]);
    PRINT 'Partition scheme PS_LeadEvents_ByMonth created';
END
ELSE
BEGIN
    PRINT 'Partition scheme PS_LeadEvents_ByMonth already exists';
END
GO

-- Partition scheme for ApiRequestLog
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_ApiLog_ByMonth')
BEGIN
    CREATE PARTITION SCHEME PS_ApiLog_ByMonth
    AS PARTITION PF_ApiLog_ByMonth
    ALL TO ([PRIMARY]);
    PRINT 'Partition scheme PS_ApiLog_ByMonth created';
END
ELSE
BEGIN
    PRINT 'Partition scheme PS_ApiLog_ByMonth already exists';
END
GO

-- Partition scheme for logs
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_Logs_ByMonth')
BEGIN
    CREATE PARTITION SCHEME PS_Logs_ByMonth
    AS PARTITION PF_Logs_ByMonth
    ALL TO ([PRIMARY]);
    PRINT 'Partition scheme PS_Logs_ByMonth created';
END
ELSE
BEGIN
    PRINT 'Partition scheme PS_Logs_ByMonth already exists';
END
GO

-- Partition scheme for Transactions
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_Transactions_ByMonth')
BEGIN
    CREATE PARTITION SCHEME PS_Transactions_ByMonth
    AS PARTITION PF_Transactions_ByMonth
    ALL TO ([PRIMARY]);
    PRINT 'Partition scheme PS_Transactions_ByMonth created';
END
ELSE
BEGIN
    PRINT 'Partition scheme PS_Transactions_ByMonth already exists';
END
GO