# ============================================================
# SaaS Backup REST API - PowerShell Client
# ============================================================

# --- Authentication & Configuration -------------------------
$ResellerToken  = "db003af0-551a-4070-afbc-45aa50979f59"
$AccessToken    = "0adf2472-23a3-4fa2-a4ef-0b20623abf25"
$BaseUrl        = "https://na-saas-npp.backup.ninjarmm.com"   # e.g. https://api.example.com

$Headers = @{
    "X-Reseller-Token" = $ResellerToken
    "X-Access-Token"   = $AccessToken
    "Content-Type"     = "application/json"
}

# ============================================================
# GET /accounts
# Returns all backed up email accounts.
# ============================================================

$Url = "$BaseUrl/api/accounts"

# --- Execute request ----------------------------------------
try {
    $Response = Invoke-RestMethod -Uri $Url -Method GET -Headers $Headers
    Write-Output "=== Backed Up Accounts ==="
    $Response | ConvertTo-Json -Depth 10
}
catch {
    Write-Error "Request failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-Error "HTTP Status: $StatusCode"
    }
}
