SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE dbo.tableau_stg_usp_LoadFmisUsers
    @RunId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.tableau_stg_FMISUsers
    WHERE RunId = @RunId;

    INSERT INTO dbo.tableau_stg_FMISUsers
    (
        RunId,
        UserKey,
        Username,
        Email,
        DisplayName,
        DesiredSiteRole,
        IsActive
    )
    SELECT
        @RunId,
        CAST(u.Edipi AS NVARCHAR(100)) AS UserKey,
        CAST(u.Edipi AS NVARCHAR(255)) AS Username,
        NULLIF(LTRIM(RTRIM(u.Email)), '') AS Email,
        NULLIF(
            LTRIM(RTRIM(
                u.LastName + ', ' + u.FirstName +
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(u.MiddleName)), '') IS NULL THEN ''
                    ELSE ' ' + LTRIM(RTRIM(u.MiddleName))
                END
            )),
            ''
        ) AS DisplayName,
        N'Viewer' AS DesiredSiteRole,
        CASE
            WHEN u.IsDisabled = 1 THEN CAST(0 AS BIT)
            ELSE CAST(1 AS BIT)
        END AS IsActive
    FROM dbo.fw_Users u;
END;
GO
