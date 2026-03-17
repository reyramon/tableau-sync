# SSIS Package Outline

## Package Variables

Use these package-level variables to match the pipeline design:

- `ServerUrl` (`String`)
- `ApiVersion` (`String`) default `3.18`
- `PatName` (`String`)
- `PatSecret` (`String`)
- `SiteContentUrl` (`String`) empty string for the default site
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
