#SE Test Env
#Name: Adham Web AC + RT

$NinjaOneInstance     = "eu.ninjarmm.com"
$NinjaOneClientId     = ""
$NinjaOneClientSecret = ""

# Body for authentication
$body = @{
    grant_type = "client_credentials"
    client_id = $NinjaOneClientId
    client_secret = $NinjaOneClientSecret
    scope = "monitoring management"
}

# Headers for authentication
$API_AuthHeaders = @{
    'accept' = 'application/json'
    'Content-Type' = 'application/x-www-form-urlencoded'
}

# Authenticate and get access token
try {
    $auth_token = Invoke-RestMethod -Uri "https://$NinjaOneInstance/oauth/token" -Method POST -Headers $API_AuthHeaders -Body $body
    $access_token = $auth_token.access_token
}
catch {
    Write-Error "Failed to connect to NinjaOne API. Error: $_"
    exit
}
# Check if we successfully obtained an access token
if (-not $access_token) {
    Write-Host "Failed to obtain access token. Please check your client ID and client secret."
    exit
}

# Headers for subsequent API calls
$headers = @{
    'accept' = 'application/json'
    'Authorization' = "Bearer $access_token"
}




# Base API endpoint (no pagination params yet)
$baseUrl = "https://eu.ninjarmm.com/v2/activities"


0
Write-Host "Fetch complete. Total activities retrieved: $($allActivities.Count)" -ForegroundColor Cyan

# Save results to file (optional)
$allActivities | ConvertTo-Json -Depth 6 | Out-File -FilePath ".\ninja_activities.json" -Encoding UTF8
