# =========================
# Tableau REST API Missing Full Name Repair
# Loads Tableau users once, then updates created users whose fullName is blank
# or still equal to their username/EDIPI.
# =========================

# ---------- CONFIG ----------
$serverUrl = "https://tableau.med.ds.osd.mil"
$apiVersion = "3.18"
$contentUrl = ""
$pageSize = 100

$patName = "REPLACE_WITH_PAT_NAME"
$patSecret = "REPLACE_WITH_PAT_SECRET"

$sqlConnectionString = "REPLACE_WITH_SQL_CONNECTION_STRING"

# Optional: set to a specific run id to narrow the repair.
$runId = $null

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Data

function Invoke-TableauSignIn {
    param(
        [string]$ServerUrl,
        [string]$ApiVersion,
        [string]$PatName,
        [string]$PatSecret,
        [string]$ContentUrl
    )

    $signinUrl = "$ServerUrl/api/$ApiVersion/auth/signin"
    $signinBody = @"
<tsRequest>
<credentials personalAccessTokenName="$PatName" personalAccessTokenSecret="$PatSecret">
<site contentUrl="$ContentUrl" />
</credentials>
</tsRequest>
"@

    $signinHeaders = @{
        "Accept"       = "application/xml"
        "Content-Type" = "application/xml"
    }

    $signinResponseRaw = Invoke-RestMethod `
        -Method Post `
        -Uri $signinUrl `
        -Headers $signinHeaders `
        -Body $signinBody

    [xml]$signinXml = $signinResponseRaw.OuterXml

    return @{
        Token = $signinXml.tsResponse.credentials.token
        SiteId = $signinXml.tsResponse.credentials.site.id
    }
}

function Get-UsersToRepair {
    param(
        [string]$ConnectionString,
        [Nullable[Int64]]$RunId
    )

    $query = @"
SELECT DISTINCT
    l.RunId,
    l.Username,
    NULLIF(LTRIM(RTRIM(f.Email)), '') AS Email,
    NULLIF(LTRIM(RTRIM(f.DisplayName)), '') AS DisplayName
FROM dbo.tableau_audit_TableauUserSyncApiLog l
INNER JOIN dbo.tableau_wrk_TableauUserSyncDelta d
    ON d.RunId = l.RunId
   AND d.Username = l.Username
   AND d.SyncStatus = 'CREATED'
LEFT JOIN dbo.tableau_stg_FMISUsers f
    ON f.RunId = l.RunId
   AND UPPER(LTRIM(RTRIM(f.Username))) = UPPER(LTRIM(RTRIM(l.Username)))
WHERE l.[Action] = 'CREATE_USER'
  AND (@RunId IS NULL OR l.RunId = @RunId)
ORDER BY l.RunId, l.Username;
"@

    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $command = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
    $parameter = $command.Parameters.Add("@RunId", [System.Data.SqlDbType]::BigInt)
    if ($RunId.HasValue) {
        $parameter.Value = $RunId.Value
    }
    else {
        $parameter.Value = [System.DBNull]::Value
    }

    $connection.Open()
    try {
        $reader = $command.ExecuteReader()
        $rows = @()
        while ($reader.Read()) {
            $rows += [pscustomobject]@{
                RunId = [int64]$reader["RunId"]
                Username = $reader["Username"].ToString()
                Email = if ($reader["Email"] -eq [System.DBNull]::Value) { $null } else { $reader["Email"].ToString() }
                DisplayName = if ($reader["DisplayName"] -eq [System.DBNull]::Value) { $null } else { $reader["DisplayName"].ToString() }
            }
        }
        $reader.Close()
        return $rows
    }
    finally {
        $connection.Close()
    }
}

function Get-AllTableauUsers {
    param(
        [string]$ServerUrl,
        [string]$ApiVersion,
        [string]$SiteId,
        [string]$Token,
        [int]$PageSize
    )

    $pageNumber = 1
    $totalAvailable = 0
    $allUsers = @()

    do {
        $usersUrl = "$ServerUrl/api/$ApiVersion/sites/$SiteId/users?pageSize=$PageSize&pageNumber=$pageNumber"
        $headers = @{
            "Accept"         = "application/xml"
            "X-Tableau-Auth" = $Token
        }

        $usersResponseRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $usersUrl `
            -Headers $headers

        [xml]$usersXml = $usersResponseRaw.OuterXml
        $users = @($usersXml.tsResponse.users.user)
        if ($users) {
            $allUsers += $users
        }

        $pagination = $usersXml.tsResponse.pagination
        if ($pagination) {
            $totalAvailable = [int]$pagination.totalAvailable
        }

        $pageNumber++
    }
    while ((($pageNumber - 1) * $PageSize) -lt $totalAvailable)

    return $allUsers
}

function Update-TableauUserProfile {
    param(
        [string]$ServerUrl,
        [string]$ApiVersion,
        [string]$SiteId,
        [string]$Token,
        [string]$UserId,
        [string]$FullName,
        [string]$Email
    )

    $updateUrl = "$ServerUrl/api/$ApiVersion/sites/$SiteId/users/$UserId"
    $headers = @{
        "Accept"         = "application/xml"
        "Content-Type"   = "application/xml"
        "X-Tableau-Auth" = $Token
    }

    $attributes = @()
    if (-not [string]::IsNullOrWhiteSpace($FullName)) {
        $escapedFullName = [Security.SecurityElement]::Escape($FullName)
        $attributes += "fullName=`"$escapedFullName`""
    }

    if (-not [string]::IsNullOrWhiteSpace($Email)) {
        $escapedEmail = [Security.SecurityElement]::Escape($Email)
        $attributes += "email=`"$escapedEmail`""
    }

    if ($attributes.Count -eq 0) {
        return "Skipped update because fullName and email were blank."
    }

    $updateBody = "<tsRequest><user $($attributes -join ' ') /></tsRequest>"

    Invoke-RestMethod `
        -Method Put `
        -Uri $updateUrl `
        -Headers $headers `
        -Body $updateBody | Out-Null

    return "Updated profile."
}

function Test-MissingDisplayName {
    param($TableauUser)

    if ($null -eq $TableauUser) {
        return $false
    }

    $fullName = if ($TableauUser.fullName) { $TableauUser.fullName.ToString().Trim() } else { "" }
    $username = if ($TableauUser.name) { $TableauUser.name.ToString().Trim() } else { "" }

    return [string]::IsNullOrWhiteSpace($fullName) -or ($fullName -eq $username)
}

$token = $null

try {
    $serverUrl = $serverUrl.Trim().TrimEnd('/')
    $signIn = Invoke-TableauSignIn -ServerUrl $serverUrl -ApiVersion $apiVersion -PatName $patName -PatSecret $patSecret -ContentUrl $contentUrl
    $token = $signIn.Token
    $siteId = $signIn.SiteId

    if (-not $token -or -not $siteId) {
        throw "Sign-in succeeded but token or site ID was not returned."
    }

    Write-Host "Signed in successfully."
    Write-Host "Site ID: $siteId"

    $usersToRepair = Get-UsersToRepair -ConnectionString $sqlConnectionString -RunId $runId
    if (-not $usersToRepair -or $usersToRepair.Count -eq 0) {
        Write-Host "No created users were found to repair."
        exit 0
    }

    $candidateByUsername = @{}
    foreach ($row in $usersToRepair) {
        $candidateByUsername[$row.Username] = $row
    }

    $tableauUsers = Get-AllTableauUsers -ServerUrl $serverUrl -ApiVersion $apiVersion -SiteId $siteId -Token $token -PageSize $pageSize
    $matchedUsernames = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($tableauUser in $tableauUsers) {
        $username = if ($tableauUser.name) { $tableauUser.name.ToString() } else { $null }
        if ([string]::IsNullOrWhiteSpace($username)) {
            continue
        }

        if (-not $candidateByUsername.ContainsKey($username)) {
            continue
        }

        $null = $matchedUsernames.Add($username)
        $candidate = $candidateByUsername[$username]

        if (-not (Test-MissingDisplayName -TableauUser $tableauUser)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($candidate.DisplayName)) {
            Write-Warning "Skipping $username because no FMIS display name was found."
            continue
        }

        Write-Host ""
        Write-Host "RunId: $($candidate.RunId)"
        Write-Host "Username: $username"
        Write-Host "CurrentFullName: $($tableauUser.fullName)"
        Write-Host "NewFullName: $($candidate.DisplayName)"
        Write-Host "Email: $($candidate.Email)"

        $result = Update-TableauUserProfile `
            -ServerUrl $serverUrl `
            -ApiVersion $apiVersion `
            -SiteId $siteId `
            -Token $token `
            -UserId $tableauUser.id `
            -FullName $candidate.DisplayName `
            -Email $candidate.Email

        Write-Host $result
    }

    foreach ($username in $candidateByUsername.Keys) {
        if (-not $matchedUsernames.Contains($username)) {
            Write-Warning "Created user not found in Tableau during repair scan: $username"
        }
    }
}
catch {
    Write-Error "Repair failed: $($_.Exception.Message)"
    throw
}
finally {
    if ($token) {
        try {
            $signoutUrl = "$serverUrl/api/$apiVersion/auth/signout"
            Invoke-RestMethod `
                -Method Post `
                -Uri $signoutUrl `
                -Headers @{ "X-Tableau-Auth" = $token } | Out-Null
            Write-Host "Signed out."
        }
        catch {
            Write-Warning "Sign-out failed: $($_.Exception.Message)"
        }
    }
}
