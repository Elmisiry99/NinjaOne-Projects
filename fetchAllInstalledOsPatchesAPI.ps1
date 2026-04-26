#SE Test Env
#Name: Adham Web AC + RT

$NinjaOneInstance     = "eu.ninjarmm.com"
$NinjaOneClientId     = "BG4ieh7CleIWybLu9LzCXR0IhXA"
$NinjaOneClientSecret = "gieAwRP9dXhdcbqwYkEQobW6N_rHka05ruYL8NvO5Ku1R1OY44T-rg"

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
    $auth_token = Invoke-RestMethod -Uri "https://eu.ninjarmm.com/oauth/token" -Method POST -Headers $API_AuthHeaders -Body $body
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


$response = (Invoke-WebRequest -Uri 'https://eu.ninjarmm.com/v2/queries/os-patch-installs?installedAfter=1761955200' -Method GET -Headers $headers).Content | ConvertFrom-Json




# Initialize variables
$allPatches = @()
$cursor = $null
$hasMoreData = $true
$requestCount = 0

Write-Host "Starting to fetch patches from NinjaOne API..." -ForegroundColor Cyan

while ($hasMoreData) {
    $requestCount++

    # Build the URL
    if ($null -ne $cursor) {
        $url = "https://eu.ninjarmm.com/v2/queries/os-patch-installs?cursor=$cursor&pageSize=1000"
    } else {
        $url = "https://eu.ninjarmm.com/v2/queries/os-patch-installs?pageSize=1000"
    }

    Write-Host "[$requestCount] Fetching: $url" -ForegroundColor Yellow

    try {
        # Call the API
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET

        # Parse JSON content from response
        $json = $response.Content | ConvertFrom-Json
        $json | Get-Member        

        # The endpoint returns an array of patches (adjust key if different)
        $patches = $json.results

        if ($patches.Count -gt 0) {
            # Add to accumulated list
            $allPatches += $patches

            # Get the ID of the last (oldest) patch
            $lastPatchId = $patches[-1].id
            $cursor = $json.cursor.name
            Write-Host "Cursor name: $($cursor)"
            Write-Host "Fetched $($patches.Count) patches. Total so far: $($allPatches.Count)" -ForegroundColor Green
        } else {
            Write-Host "No more patches returned — stopping loop." -ForegroundColor Cyan
            $hasMoreData = $false
        }
    }
    catch {
        Write-Host "Error fetching data: $($_.Exception.Message)" -ForegroundColor Red
        $hasMoreData = $false
    }

    # Optional delay to avoid hitting rate limits
    Start-Sleep -Seconds 1
}

Write-Host "Fetch complete. Total patches retrieved: $($allpatches.Count)" -ForegroundColor Cyan

# Save results to file (optional)
$allpatches | ConvertTo-Json -Depth 6 | Out-File -FilePath ".\ninja_installedPatches.json" -Encoding UTF8