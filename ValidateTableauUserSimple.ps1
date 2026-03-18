# =========================
# Tableau REST API User Validation
# Sign in, get users, find one username, sign out
# =========================

# ---------- CONFIG ----------
$serverUrl   = "https://tableau.med.ds.osd.mil"
$apiVersion  = "3.18"
$contentUrl  = ""
$pageSize    = 100
$pageNumber  = 1

$patName = "REPLACE_WITH_PAT_NAME"
$patSecret = "REPLACE_WITH_PAT_SECRET"
$targetUsername = "REPLACE_WITH_USERNAME"

# ---------- SIGN IN ----------
$signinUrl = "$serverUrl/api/$apiVersion/auth/signin"

$signinBody = @"
<tsRequest>
<credentials personalAccessTokenName="$patName" personalAccessTokenSecret="$patSecret">
<site contentUrl="$contentUrl" />
</credentials>
</tsRequest>
"@

$signinHeaders = @{
    "Accept"       = "application/xml"
    "Content-Type" = "application/xml"
}

$token = $null

try {
    $signinResponseRaw = Invoke-RestMethod `
        -Method Post `
        -Uri $signinUrl `
        -Headers $signinHeaders `
        -Body $signinBody

    [xml]$signinXml = $signinResponseRaw.OuterXml

    $token  = $signinXml.tsResponse.credentials.token
    $siteId = $signinXml.tsResponse.credentials.site.id

    if (-not $token -or -not $siteId) {
        throw "Sign-in succeeded but token or site ID was not returned."
    }

    Write-Host "Signed in successfully."
    Write-Host "Site ID: $siteId"
}
catch {
    Write-Error "Sign-in failed: $($_.Exception.Message) $signinUrl"
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            if ($errorBody) {
                Write-Error "Response body: $errorBody"
            }
        }
        catch {
        }
    }
    throw
}

# ---------- GET USERS ----------
$foundUser = $null

try {
    do {
        $usersUrl = "$serverUrl/api/$apiVersion/sites/$siteId/users?pageSize=$pageSize&pageNumber=$pageNumber"

        $authHeaders = @{
            "Accept"         = "application/xml"
            "X-Tableau-Auth" = $token
        }

        Write-Host "Checking page ${pageNumber}: $usersUrl"

        $usersResponseRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $usersUrl `
            -Headers $authHeaders

        [xml]$usersXml = $usersResponseRaw.OuterXml

        $users = @($usersXml.tsResponse.users.user)

        foreach ($user in $users) {
            if ($null -ne $user -and $user.name -eq $targetUsername) {
                $foundUser = $user
                break
            }
        }

        $pagination = $usersXml.tsResponse.pagination
        if ($pagination) {
            Write-Host "PageNumber: $($pagination.pageNumber)"
            Write-Host "PageSize: $($pagination.pageSize)"
            Write-Host "TotalAvailable: $($pagination.totalAvailable)"
        }

        if ($foundUser) {
            break
        }

        $pageNumber++
    }
    while (($pagination) -and (([int]$pagination.pageNumber * [int]$pagination.pageSize) -lt [int]$pagination.totalAvailable))

    if ($foundUser) {
        Write-Host "User exists in Tableau."
        Write-Host "Username: $($foundUser.name)"
        Write-Host "TableauUserId: $($foundUser.id)"
        Write-Host "SiteRole: $($foundUser.siteRole)"
        Write-Host "Email: $($foundUser.email)"
    }
    else {
        Write-Host "User not found in Tableau: $targetUsername"
    }
}
catch {
    Write-Error "Get Users failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            if ($errorBody) {
                Write-Error "Response body: $errorBody"
            }
        }
        catch {
        }
    }
    throw
}

# ---------- SIGN OUT ----------
$signoutUrl = "$serverUrl/api/$apiVersion/auth/signout"

try {
    Invoke-RestMethod `
        -Method Post `
        -Uri $signoutUrl `
        -Headers @{ "X-Tableau-Auth" = $token } | Out-Null

    Write-Host "Signed out."
}
catch {
    Write-Warning "Sign-out failed: $($_.Exception.Message)"
}
