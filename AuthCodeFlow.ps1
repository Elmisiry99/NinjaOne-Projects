$ClientID = 'BG4ieh7CleIWybLu9LzCXR0IhXA'
$Secret = 'fR2mUs7KjPhy4DJkWhHccm2X7hdLnl1D5yRtCfwC_xRVA9oWnG2Pfg'
$RedirectURL = 'http://localhost:8080/'


######## Authentication Flow ########
# Create an API Application in NinjaOne with a type of Web (PHP, Java, .Net Core, etc.)


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

$AuthURL = "https://eu.ninjarmm.com/oauth/authorize?response_type=code&client_id=$ClientID&redirect_uri=$RedirectURL&scope=monitoring%20offline_access&state=STATE"

$Result = Get-OAuthCode -AuthURL $AuthURL -RedirectURL $RedirectURL

$AuthBody = @{
    'grant_type' = 'authorization_code'
    'client_id' = $ClientID
    'client_secret' = $Secret
    'code' = $Result.code
    'redirect_uri' = $RedirectURL 
}

$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}

$Devices = (Invoke-WebRequest -uri "https://eu.ninjarmm.com/api/v2/devices" -Method Get -Headers $AuthHeader -ContentType 'application/json').Content | ConvertFrom-Json

$Devices

######## Refresh Token ########
# Ensure your API Application has Refresh Token as an allowed Grant Type. 

$RefreshToken = ($Result.content | ConvertFrom-Json).refresh_token

$AuthBody = @{
    'grant_type'    = 'refresh_token'
    'client_id'     = $ClientID
    'client_secret' = $Secret
    'refresh_token' = $RefreshToken
}

$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}

$DevicesDetailed = (Invoke-WebRequest -uri "https://eu.ninjarmm.com/api/v2/devices-detailed" -Method Get -Headers $AuthHeader -ContentType 'application/json').Content | ConvertFrom-Json

$DevicesDetailed

