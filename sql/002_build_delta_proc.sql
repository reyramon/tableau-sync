SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE dbo.tableau_wrk_usp_BuildTableauUserSyncDelta
    @RunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.tableau_wrk_TableauUserSyncDelta
    WHERE RunId = @RunId;

    ;WITH Fmis AS
    (
        SELECT
            f.RunId,
            f.Username,
            f.Email,
            f.DesiredSiteRole,
            f.IsActive
        FROM dbo.tableau_stg_FMISUsers f
        WHERE f.RunId = @RunId
    ),
    Tableau AS
    (
        SELECT
            t.RunId,
            t.TableauUserId,
            t.Username,
            t.Email,
            t.SiteRole
        FROM dbo.tableau_stg_TableauUsers t
        WHERE t.RunId = @RunId
    )
    INSERT INTO dbo.tableau_wrk_TableauUserSyncDelta
    (
        RunId,
        Username,
        Email,
        TableauUserId,
        DesiredSiteRole,
        CurrentSiteRole,
        SyncAction,
        SyncStatus,
        SyncMessage
    )
    SELECT
        @RunId,
        f.Username,
        f.Email,
        t.TableauUserId,
        f.DesiredSiteRole,
        t.SiteRole,
        CASE
            WHEN f.IsActive = 0 THEN 'INACTIVE'
            WHEN t.TableauUserId IS NULL THEN 'CREATE'
            WHEN ISNULL(f.DesiredSiteRole, '') <> ISNULL(t.SiteRole, '') THEN 'ROLE_MISMATCH'
            ELSE 'MATCH'
        END AS SyncAction,
        'PENDING',
        CASE
            WHEN f.IsActive = 0 THEN 'User is inactive in FMIS; logging only.'
            WHEN t.TableauUserId IS NULL THEN 'User exists in FMIS but not in Tableau.'
            WHEN ISNULL(f.DesiredSiteRole, '') <> ISNULL(t.SiteRole, '') THEN 'Role mismatch detected; not updated in Phase 1.'
            ELSE 'User already exists with matching role.'
        END AS SyncMessage
    FROM Fmis f
    LEFT JOIN Tableau t
        ON t.RunId = f.RunId
       AND UPPER(LTRIM(RTRIM(t.Username))) = UPPER(LTRIM(RTRIM(f.Username)));

    INSERT INTO dbo.tableau_wrk_TableauUserSyncDelta
    (
        RunId,
        Username,
        Email,
        TableauUserId,
        DesiredSiteRole,
        CurrentSiteRole,
        SyncAction,
        SyncStatus,
        SyncMessage
    )
    SELECT
        @RunId,
        t.Username,
        t.Email,
        t.TableauUserId,
        NULL,
        t.SiteRole,
        'REVIEW',
        'PENDING',
        'User exists in Tableau but was not returned by FMIS.'
    FROM dbo.tableau_stg_TableauUsers t
    WHERE t.RunId = @RunId
      AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.tableau_stg_FMISUsers f
        WHERE f.RunId = @RunId
          AND UPPER(LTRIM(RTRIM(f.Username))) = UPPER(LTRIM(RTRIM(t.Username)))
    );
END;
