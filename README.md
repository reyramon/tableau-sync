# Tableau User Sync Pipeline

This workspace contains the initial scaffold for an SSIS-based Tableau user synchronization pipeline.

## Scope

Phase 1 is focused on:

- authenticating to Tableau with a PAT
- retrieving Tableau users with pagination
- loading FMIS users into staging
- computing the user delta in SQL
- writing auditable run and API-call logs

The current SSIS package can stage Tableau users, build the SQL delta, and perform `CREATE`
actions when `IsDryRun` is set to `False` and the SQL staging data is available for the run.

## Structure

- `docs/` package design and implementation notes
- `sql/` table and stored procedure scripts
- `src/ScriptTasks/` reusable C# code for SSIS Script Tasks

## Suggested Build Order

1. Run `sql/001_create_schema.sql`
2. Run `sql/002_build_delta_proc.sql`
3. Run `sql/003_audit_procs.sql`
4. Run `sql/004_load_fmis_users_proc.sql`
5. Create the SSIS package and variables documented in `docs/ssis-package-outline.md`
6. Paste or adapt the C# files in `src/ScriptTasks/` into SSIS Script Tasks
7. Validate in dry-run mode before enabling user creation
