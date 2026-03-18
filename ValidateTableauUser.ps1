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

function Get-TableauUsersPage {
    param(
        [string]$BaseUrl,
        [string]$Version,
        [string]$SiteId,
        [string]$Token,
        [int]$PageNumber,
        [int]$Size
    )

    $usersUrl = "$BaseUrl/api/$Version/sites/$SiteId/users?pageSize=$Size&pageNumber=$PageNumber"
    $headers = @{
        "Accept"         = "application/xml"
        "X-Tableau-Auth" = $Token
    }

    $response = Invoke-RestMethod -Method Get -Uri $usersUrl -Headers $headers
    [xml]$xml = $response.OuterXml

    return @{
        Users = @($xml.tsResponse.users.user)
        Pagination = $xml.tsResponse.pagination
        RequestUrl = $usersUrl
    }
}

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

    $pageNumber = 1
    $foundUser = $null
    $totalAvailable = 0

    do {
        $page = Get-TableauUsersPage -BaseUrl $ServerUrl -Version $ApiVersion -SiteId $siteId -Token $token -PageNumber $pageNumber -Size $PageSize
        $users = $page.Users
        $pagination = $page.Pagination

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
    Write-Error "Validation failed: $($_.Exception.Message)"
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
