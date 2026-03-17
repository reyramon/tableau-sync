SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE dbo.tableau_audit_usp_TableauUserSyncInitializeRun
    @RunId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.tableau_audit_TableauUserSyncRun (Status)
    VALUES ('STARTED');

    SET @RunId = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.tableau_audit_usp_TableauUserSyncLogApiCall
    @RunId BIGINT,
    @Username NVARCHAR(255) = NULL,
    @Action NVARCHAR(50),
    @RequestUrl NVARCHAR(2048),
    @HttpStatusCode INT = NULL,
    @ResponseBody NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.tableau_audit_TableauUserSyncApiLog
    (
        RunId,
        Username,
        [Action],
        RequestUrl,
        HttpStatusCode,
        ResponseBody
    )
    VALUES
    (
        @RunId,
        @Username,
        @Action,
        @RequestUrl,
        @HttpStatusCode,
        @ResponseBody
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.tableau_audit_usp_TableauUserSyncFinalizeRun
    @RunId BIGINT,
    @Status NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE r
    SET
        EndTime = SYSUTCDATETIME(),
        Status = @Status,
        TotalProcessed = totals.TotalProcessed,
        TotalCreated = totals.TotalCreated,
        TotalErrors = totals.TotalErrors
    FROM dbo.tableau_audit_TableauUserSyncRun r
    CROSS APPLY
    (
        SELECT
            COUNT(*) AS TotalProcessed,
            SUM(CASE WHEN d.SyncAction = 'CREATE' AND d.SyncStatus IN ('CREATED', 'DRY_RUN') THEN 1 ELSE 0 END) AS TotalCreated,
            SUM(CASE WHEN d.SyncStatus = 'ERROR' THEN 1 ELSE 0 END) AS TotalErrors
        FROM dbo.tableau_wrk_TableauUserSyncDelta d
        WHERE d.RunId = @RunId
    ) totals
    WHERE r.RunId = @RunId;
END;
GO
