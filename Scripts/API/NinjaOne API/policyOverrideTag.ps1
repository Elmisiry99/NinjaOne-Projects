$ClientID = 'BG4ieh7CleIWybLu9LzCXR0IhXA'
$Secret = 'vxr2lcHBT0akcpFodqnNMCoVQY0WZVtLZFFSmbmfSd549VTp8AA1FQ'
$RedirectURL = 'http://localhost:8080/'


function Get-OAuthCode {
    param (
        [System.UriBuilder]$AuthURL,
        [string]$RedirectURL
    )
    $HTTP = [System.Net.HttpListener]::new()
    $HTTP.Prefixes.Add($RedirectURL)
    $HTTP.Start()
    Start-Process $AuthURL.ToString()
    $Result = @{}
    while ($HTTP.IsListening) {
        $Context = $HTTP.GetContext()
        if ($Context.Request.QueryString -and $Context.Request.QueryString['Code']) {
            $Result.Code = $Context.Request.QueryString['Code']
            if ($null -ne $Result.Code) {
                $Result.GotAuthorisationCode = $True
            }
            [string]$HTML = '<h1>NinjaOne Authorization Code</h1><br /><p>An authorisation code has been received. The HTTP listener will stop in 5 seconds.</p><p>Please close this tab / window.</p>'
            $Response = [System.Text.Encoding]::UTF8.GetBytes($HTML)
            $Context.Response.ContentLength64 = $Response.Length
            $Context.Response.OutputStream.Write($Response, 0, $Response.Length)
            $Context.Response.OutputStream.Close()
            Start-Sleep -Seconds 5
            $HTTP.Stop()
        }
    }
    Return $Result
}


# Getting the access token using client credentials

$AuthBody = @{
    'grant_type' = 'client_credentials'
    'client_id' = $ClientID
    'client_secret' = $Secret
    'scope' = 'monitoring management offline_access' 
}

$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}

<#
# Getting the Authorization Code
$AuthURL = "https://eu.ninjarmm.com/oauth/authorize?response_type=code&client_id=$ClientID&redirect_uri=$RedirectURL&scope=monitoring%20management%20offline_access&state=STATE"

$Result = Get-OAuthCode -AuthURL $AuthURL -RedirectURL $RedirectURL

$RefreshToken = ($Result.content | ConvertFrom-Json).refresh_token

# Composing the body of the request to get a new access token with the Refresh Token
$AuthBody = @{
    'grant_type'    = 'refresh_token'
    'client_id'     = $ClientID
    'client_secret' = $Secret
    'refresh_token' = $RefreshToken
}

# Getting a new Access Token with the Refresh Token
$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}

#>

$devicesWithOverrides = (Invoke-WebRequest -Uri 'https://eu.ninjarmm.com/v2/queries/policy-overrides' -Method GET -Headers $AuthHeader).Content | ConvertFrom-Json


$deviceIds = $response.results.devicesWithOverrides

#Write-Output $deviceIds

$allTags= Invoke-WebRequest -Uri 'https://eu.ninjarmm.com/v2/tag' -Method GET -Headers $AuthHeader

$policyOverrideTagId = $allTags.tags | Where-Object{ $_.name -eq 'PolicyOverride' } | Select-Object -ExpandProperty id

$policyOverrideTagId
