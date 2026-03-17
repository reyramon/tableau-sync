Below is a clean .md file with no special formatting blocks. You can copy it directly.

Tableau User Sync Pipeline (SSIS + REST API)
Objective

Build an SSIS-based pipeline to synchronize users from FMIS (SQL Server) to Tableau Server using the Tableau REST API.

This process will:

Authenticate to Tableau using a Personal Access Token (PAT)

Retrieve existing Tableau users

Retrieve FMIS users from SQL Server

Compute differences (delta)

Create missing users in Tableau

Log all activity for audit and troubleshooting

Architecture Overview
High-Level Flow

Sign in to Tableau using the REST API

Get Tableau users using the paged API

Load FMIS users from SQL Server

Store both datasets in staging tables

Compute delta in SQL

Create missing Tableau users via REST API

Log results

Sign out of Tableau

Tableau REST endpoints follow this pattern:

{server}/api/{api-version}/sites/{site-id}/...

Examples:

GET /api/3.18/sites/{site-id}/users

POST /api/3.18/auth/signin

Reference:
https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api_concepts_versions.htm

Tech Stack

SSIS for orchestration

SQL Server for staging and delta logic

C# Script Task for REST API calls

Tableau REST API version 3.18

SSIS Package Design
Control Flow

Execute SQL Task: Initialize Run

Script Task: Sign In and get token plus siteId

Script Task: Get Tableau Users with pagination

Data Flow Task: Load FMIS Users

Execute SQL Task: Build Delta

Foreach Loop: Create Missing Users

Script Task: Add User to Tableau

Execute SQL Task: Final Audit Summary

Script Task: Sign Out

SSIS Variables
Variable	Description
ServerUrl	Tableau base URL
ApiVersion	3.18
Token	Tableau auth token
SiteId	Tableau site ID
RunId	Audit run identifier
IsDryRun	True or False toggle
PageSize	Default 100
PageNumber	Pagination control
SQL Table Design
Audit Table

Audit.TableauUserSyncRun

RunId (PK)

StartTime

EndTime

Status

TotalProcessed

TotalCreated

TotalErrors

Tableau Users Staging

stg.TableauUsers

RunId

TableauUserId

Username

Email

SiteRole

LastLogin

FMIS Users Staging

stg.FMISUsers

RunId

UserKey

Username

Email

DisplayName

DesiredSiteRole

IsActive

Delta Table

wrk.TableauUserSyncDelta

RunId

Username

Email

TableauUserId

DesiredSiteRole

CurrentSiteRole

SyncAction

SyncStatus

SyncMessage

Delta Logic

Classify users into:

CREATE: exists in FMIS but not Tableau

MATCH: exists in both

ROLE_MISMATCH: role differs

INACTIVE: disabled in FMIS

REVIEW: anything unclear

Initial version should only process:

CREATE

Do not:

delete users

deactivate users

mass update roles

REST API Implementation
1. Sign In with PAT
<tsRequest>
  <credentials personalAccessTokenName="PAT_NAME" personalAccessTokenSecret="PAT_SECRET">
    <site contentUrl="" />
  </credentials>
</tsRequest>

Reference:
https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api_ref_authentication.htm

2. Get Users

GET /api/3.18/sites/{site-id}/users?pageSize=100&pageNumber=1

Notes:

Must handle pagination

Default page size is 100

Maximum page size is 1000

Reference:
https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api_ref_users_and_groups.htm

3. Create User

POST /api/3.18/sites/{site-id}/users

Body example:

<tsRequest>
  <user name="username" siteRole="Viewer" />
</tsRequest>

Reference:
https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api.htm

4. Sign Out

POST /api/3.18/auth/signout

Script Task Responsibilities
Script Task 1: Sign In

Send POST request

Parse XML response

Store Token and SiteId

Script Task 2: Get Users

Loop pages until all users are retrieved

Insert results into stg.TableauUsers

Script Task 3: Create User

Input: Username and Role

Call Add User endpoint

Capture status code and response body

Update delta table

Script Task 4: Sign Out

Call signout endpoint

Clear token

Logging and Auditing

Every API call must log:

RunId

Username

Action (SIGNIN, GET_USERS, CREATE_USER, SIGNOUT)

RequestUrl

HttpStatusCode

ResponseBody

Timestamp

Safety Controls
Dry Run Mode

IsDryRun = TRUE

Behavior:

Compute delta

Log intended actions

Do not call create user API

Idempotency

Never create duplicate users

Always compare before action

Business Rules To Define Before Build
Identity Key

Choose one:

Username (recommended)

Email

Role Mapping
FMIS Role	Tableau Role
Admin	Creator
Analyst	Explorer
Viewer	Viewer

Reference:
https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api_concepts_new_site_roles.htm

Inactive Users

Initial behavior:

Log only

No removal

Development Phases
Phase 1

Sign in

Get Tableau users

Load FMIS users

Build delta

Output report

Phase 2

Enable CREATE action

Phase 3

Add role updates if needed

Phase 4

Add notifications and reporting

Expected Outcome

Fully automated Tableau user provisioning pipeline

Controlled, auditable, repeatable process

Minimal manual Tableau user management

Notes for Codex

Use multiple files, not one large script

Separate API client logic, SQL logic, and SSIS orchestration

Keep functions small and reusable

Prefer clarity over abstraction

Assume enterprise constraints and no external installs