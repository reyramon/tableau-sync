# SSIS Package Outline

## Package Variables

Use these package-level variables to match the pipeline design:

- `ServerUrl` (`String`)
- `ApiVersion` (`String`) default `3.18`
- `PatName` (`String`)
- `PatSecret` (`String`)
- `SiteContentUrl` (`String`) empty string for the default site
- `SqlConnectionString` (`String`) optional override SQL Server connection string used by the script task
- `SqlConnectionManagerName` (`String`) optional package connection manager name, default `Proddb.med.ds.osd.mil.J8BI_Prd_apps`
- `Token` (`String`)
- `SiteId` (`String`)
- `RunId` (`Int64`)
- `IsDryRun` (`Boolean`) default `True`
- `PageSize` (`Int32`) default `100`
- `PageNumber` (`Int32`) default `1`
- `CurrentUsername` (`String`)
- `CurrentSiteRole` (`String`)
- `CurrentEmail` (`String`)

## Control Flow

1. `Execute SQL Task` Initialize Run
2. `Script Task` Sign In
3. `Script Task` Get Tableau Users
4. `Data Flow Task` Load FMIS Users
5. `Execute SQL Task` Build Delta
6. `Foreach Loop Container` Iterate `CREATE` candidates
7. `Script Task` Create User
8. `Execute SQL Task` Final Audit Summary
9. `Script Task` Sign Out

## Execute SQL Task Notes

### Initialize Run

- execute `dbo.tableau_audit_usp_TableauUserSyncInitializeRun`
- capture the output `RunId`

### Build Delta

- execute `dbo.tableau_wrk_usp_BuildTableauUserSyncDelta`

### Load FMIS Users

- execute `dbo.tableau_stg_usp_LoadFmisUsers`
- pass the current `RunId`
- current mapping from `dbo.fw_Users`:
  `Edipi -> UserKey/Username`, `Email -> Email`, names -> `DisplayName`,
  `DesiredSiteRole = 'Viewer'`, `IsActive = NOT IsDisabled`

### Final Audit Summary

- execute `dbo.tableau_audit_usp_TableauUserSyncFinalizeRun`
- pass a final status such as `SUCCESS` or `FAILED`

## Foreach Loop Query

Use an ADO recordset source with a query similar to:

```sql
SELECT Username, Email, DesiredSiteRole
FROM dbo.tableau_wrk_TableauUserSyncDelta
WHERE RunId = ?
  AND SyncAction = 'CREATE'
ORDER BY Username;
```

In Phase 1, keep `IsDryRun = 1` so the loop logs intended actions without calling Tableau create-user.

## Script Task Mapping

- `SignInScriptTask.cs`: reads PAT variables, stores `Token` and `SiteId`
- `GetUsersScriptTask.cs`: pages Tableau users into `dbo.tableau_stg_TableauUsers`
- `CreateUserScriptTask.cs`: creates a single Tableau user or logs a dry-run action
- `SignOutScriptTask.cs`: revokes the Tableau session token

The current package script can also orchestrate the end-to-end sync in one Script Task. If
`SqlConnectionString` is blank, the script falls back to the package connection manager named in
`SqlConnectionManagerName`, which currently defaults to `Proddb.med.ds.osd.mil.J8BI_Prd_apps`.
When that connection manager is OLE DB-based, the script strips OLE DB-only keywords such as
`Provider` before creating the SQL connection.
