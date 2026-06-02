$ClientID = 'BG4ieh7CleIWybLu9LzCXR0IhXA'
$Secret = 'gieAwRP9dXhdcbqwYkEQobW6N_rHka05ruYL8NvO5Ku1R1OY44T-rg'
$RedirectURL = 'http://localhost:8080/'

<# $ClientIDRF = 'PpmALtMa9lOlpJBLPu1nA4_n0ls'
$SecretRF = 'tVbmJbtdN9f-I43HgjTyTSg7tp90ZpC6ZR8K77Ck77FjqRMfS8R6hw'
$RedirectURLRF = 'http://localhost:8080/' #> 

######## Client Credentials ########
# Create an API Application in NinjaOne with a Type of API Services (machine-to-machine)


$AuthBody = @{
    'grant_type' = 'client_credentials'
    'client_id' = $ClientID
    'client_secret' = $Secret
    'scope' = 'monitoring management' 
}

$Result = Invoke-WebRequest -uri "https://eu.ninjarmm.com/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

$AuthHeader = @{
    'Authorization' = "Bearer $(($Result.content | ConvertFrom-Json).access_token)"
}

$response = Invoke-RestMethod -Uri 'https://eu.ninjarmm.com/v2/noderole/list' -Method GET -Headers $AuthHeader

$NodeClassGroup = $response | Select-Object -ExpandProperty nodeClassGroup -Unique


$NodeClassGroup