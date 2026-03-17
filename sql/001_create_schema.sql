SET NOCOUNT ON;

IF OBJECT_ID('dbo.tableau_audit_TableauUserSyncRun', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tableau_audit_TableauUserSyncRun
    (
        RunId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        StartTime DATETIME2(0) NOT NULL CONSTRAINT DF_TableauUserSyncRun_StartTime DEFAULT SYSUTCDATETIME(),
        EndTime DATETIME2(0) NULL,
        Status NVARCHAR(30) NOT NULL CONSTRAINT DF_TableauUserSyncRun_Status DEFAULT 'STARTED',
        TotalProcessed INT NOT NULL CONSTRAINT DF_TableauUserSyncRun_TotalProcessed DEFAULT 0,
        TotalCreated INT NOT NULL CONSTRAINT DF_TableauUserSyncRun_TotalCreated DEFAULT 0,
        TotalErrors INT NOT NULL CONSTRAINT DF_TableauUserSyncRun_TotalErrors DEFAULT 0
    );
END;

IF OBJECT_ID('dbo.tableau_audit_TableauUserSyncApiLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tableau_audit_TableauUserSyncApiLog
    (
        ApiLogId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RunId BIGINT NOT NULL,
        Username NVARCHAR(255) NULL,
        [Action] NVARCHAR(50) NOT NULL,
        RequestUrl NVARCHAR(2048) NOT NULL,
        HttpStatusCode INT NULL,
        ResponseBody NVARCHAR(MAX) NULL,
        LoggedAt DATETIME2(0) NOT NULL CONSTRAINT DF_TableauUserSyncApiLog_LoggedAt DEFAULT SYSUTCDATETIME()
    );
END;

IF OBJECT_ID('dbo.tableau_stg_TableauUsers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tableau_stg_TableauUsers
    (
        RunId BIGINT NOT NULL,
        TableauUserId NVARCHAR(100) NOT NULL,
        Username NVARCHAR(255) NOT NULL,
        Email NVARCHAR(255) NULL,
        SiteRole NVARCHAR(100) NULL,
        LastLogin DATETIME2(0) NULL,
        CONSTRAINT PK_stg_TableauUsers PRIMARY KEY (RunId, TableauUserId)
    );

    CREATE INDEX IX_stg_TableauUsers_RunId_Username
        ON dbo.tableau_stg_TableauUsers (RunId, Username);
END;

IF OBJECT_ID('dbo.tableau_stg_FMISUsers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tableau_stg_FMISUsers
    (
        RunId BIGINT NOT NULL,
        UserKey NVARCHAR(100) NOT NULL,
        Username NVARCHAR(255) NOT NULL,
        Email NVARCHAR(255) NULL,
        DisplayName NVARCHAR(255) NULL,
        DesiredSiteRole NVARCHAR(100) NULL,
        IsActive BIT NOT NULL,
        CONSTRAINT PK_stg_FMISUsers PRIMARY KEY (RunId, UserKey)
    );

    CREATE INDEX IX_stg_FMISUsers_RunId_Username
        ON dbo.tableau_stg_FMISUsers (RunId, Username);
END;

IF OBJECT_ID('dbo.tableau_wrk_TableauUserSyncDelta', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.tableau_wrk_TableauUserSyncDelta
    (
        RunId BIGINT NOT NULL,
        Username NVARCHAR(255) NOT NULL,
        Email NVARCHAR(255) NULL,
        TableauUserId NVARCHAR(100) NULL,
        DesiredSiteRole NVARCHAR(100) NULL,
        CurrentSiteRole NVARCHAR(100) NULL,
        SyncAction NVARCHAR(30) NOT NULL,
        SyncStatus NVARCHAR(30) NOT NULL CONSTRAINT DF_TableauUserSyncDelta_SyncStatus DEFAULT 'PENDING',
        SyncMessage NVARCHAR(4000) NULL,
        CONSTRAINT PK_wrk_TableauUserSyncDelta PRIMARY KEY (RunId, Username)
    );

    CREATE INDEX IX_wrk_TableauUserSyncDelta_RunId_Action
        ON dbo.tableau_wrk_TableauUserSyncDelta (RunId, SyncAction);
END;
