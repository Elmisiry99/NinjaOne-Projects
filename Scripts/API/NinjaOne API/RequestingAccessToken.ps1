$ClientID = $env:NINJA_CLIENT_ID
$Secret = $env:NINJA_CLIENT_SECRET
$RedirectURL = $env:NINJA_REDIRECT_URL

<# $ClientIDRF = 'PpmALtMa9lOlpJBLPu1nA4_n0ls'
$SecretRF = 'tVbmJbtdN9f-I43HgjTyTSg7tp90ZpC6ZR8K77Ck77FjqRMfS8R6hw'
$RedirectURLRF = 'http://localhost:8080/' #> 

######## Client Credentials ########
# Create an API Application in NinjaOne with a Type of API Services (machine-to-machine)


$AuthBody = @{
    grant_type = 'client_credentials'
    client_id = $ClientID
    client_secret = $Secret
    scope = 'monitoring management' 
}

$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}


######## Authentication Flow ########
# Create an API Application in NinjaOne with a type of Web (PHP, Java, .Net Core, etc.)


function Get-OAuthCode {
    param (
        [string]$AuthURL,
        [string]$RedirectURL
    )
    $HTTP = [System.Net.HttpListener]::new()
    $HTTP.Prefixes.Add("http://localhost:8080/")
    $HTTP.Start()
    Start-Process $AuthURL
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

$AuthURL = "https://eu.ninjarmm.com/oauth/authorize?response_type=code&client_id=$ClientID&redirect_uri=$RedirectURL&scope=monitoring%20management%20control%20offline_access&state=STATE"


$Result = Get-OAuthCode -AuthURL $AuthURL -RedirectURL $RedirectURL


#Composing the body of the requet to get the access token
$AuthBody = @{
    'grant_type' = 'authorization_code'
    'client_id' = $ClientID
    'client_secret' = $Secret
    'code' = $Result.code
    'redirect_uri' = $RedirectURL
}

## Requesting the access token
$ResultAccessToken = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'


$AuthHeader = @{
    'Authorization' = "Bearer $(($ResultAccessToken.content | ConvertFrom-Json).access_token)"
}


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

