param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,

    [Parameter(Mandatory = $true)]
    [string]$PatName,

    [Parameter(Mandatory = $true)]
    [string]$PatSecret,

    [Parameter(Mandatory = $true)]
    [string]$Username,

    [string]$ApiVersion = "3.18",

    [string]$ContentUrl = "",

    [int]$PageSize = 100
)

$ErrorActionPreference = "Stop"
$ServerUrl = $ServerUrl.Trim().TrimEnd('/')
$Username = $Username.Trim()

$token = $null

try {
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

    $signinResponse = Invoke-RestMethod -Method Post -Uri $signinUrl -Headers $signinHeaders -Body $signinBody
    [xml]$signinXml = $signinResponse.OuterXml

    $token = $signinXml.tsResponse.credentials.token
    $siteId = $signinXml.tsResponse.credentials.site.id

    if (-not $token -or -not $siteId) {
        throw "Sign-in succeeded but token or site ID was not returned."
    }

    Write-Host "Signed in successfully."
    Write-Host "Site ID: $siteId"

    $pageNumber = 1
    $foundUser = $null
    $totalAvailable = 0

    do {
        $usersUrl = "$ServerUrl/api/$ApiVersion/sites/$siteId/users?pageSize=$PageSize&pageNumber=$pageNumber"
        $authHeaders = @{
            "Accept"         = "application/xml"
            "X-Tableau-Auth" = $token
        }

        Write-Host "Checking page $pageNumber: $usersUrl"

        $usersResponseRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $usersUrl `
            -Headers $authHeaders

        [xml]$usersXml = $usersResponseRaw.OuterXml
        $users = @($usersXml.tsResponse.users.user)
        $pagination = $usersXml.tsResponse.pagination

        if ($pagination) {
            $totalAvailable = [int]$pagination.totalAvailable
        }

        foreach ($user in $users) {
            if ($null -ne $user -and $user.name -eq $Username) {
                $foundUser = $user
                break
            }
        }

        if ($foundUser) {
            break
        }

        $pageNumber++
    }
    while ((($pageNumber - 1) * $PageSize) -lt $totalAvailable)

    if ($foundUser) {
        Write-Host "User exists in Tableau."
        Write-Host "Username: $($foundUser.name)"
        Write-Host "TableauUserId: $($foundUser.id)"
        Write-Host "SiteRole: $($foundUser.siteRole)"
        if ($foundUser.email) {
            Write-Host "Email: $($foundUser.email)"
        }
        exit 0
    }

    Write-Host "User not found in Tableau: $Username"
    exit 1
}
catch {
    Write-Error "Validation failed for server [$ServerUrl] and username [$Username]: $($_.Exception.Message)"
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
finally {
    if ($token) {
        try {
            $signoutUrl = "$ServerUrl/api/$ApiVersion/auth/signout"
            Invoke-RestMethod -Method Post -Uri $signoutUrl -Headers @{ "X-Tableau-Auth" = $token } | Out-Null
        }
        catch {
            Write-Warning "Sign-out failed: $($_.Exception.Message)"
        }
    }
}
