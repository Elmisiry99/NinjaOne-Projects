$apiBaseUrl = "https://eu.ninjarmm.com"
$ClientID = 'nxXuCHiPnFyorGQfFCcCuFrFKLA'
$Secret = 'w0jfcP-QwkwDOJLqR8N3TxPl_Smlm0NvK0biQ32GyF2NH2wIKoXCFA'

# Fetch OAuth Authorization Header using Client Credentials
function Get-NinjaOAuthHeader {
    param(
        [Parameter(Mandatory)]
        [string]$ApiBaseUrl,

        [Parameter(Mandatory)]
        [string]$ClientID,

        [Parameter(Mandatory)]
        [string]$Secret,

        [string]$Scope = "monitoring management"
    )

    # Build body for client credentials request
    $AuthBody = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientID
        client_secret = $Secret
        scope         = $Scope
    }

    # Request OAuth token
    $TokenUrl = "$ApiBaseUrl/ws/oauth/token"
    $Result = Invoke-RestMethod -Uri $TokenUrl -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'

    # Build Authorization header
    $AuthHeader = @{
        Authorization = "Bearer $($Result.access_token)"
    }

    # Return both for flexibility
    return [pscustomobject]@{
        AuthHeader   = $AuthHeader
        AccessToken  = $Result.access_token
    }
}

# Function to get activities from NinjaOne API with pagination
function Get-NinjaActivities {
    param(
        [string]$Status,
        [string]$Type = "CONDITION",
        [int]$afterTs,
        [int]$beforeTs
    )

    # Get OAuth Header
    $AuthHeader = (Get-NinjaOAuthHeader -ApiBaseUrl $apiBaseUrl -ClientID $ClientID -Secret $Secret).AuthHeader

    $allActivities = @()
    $lastActivityId = $null
    $hasMoreData = $true
    $requestCount = 0
    Write-Host "Starting to fetch activities from NinjaOne API..." -ForegroundColor Cyan
    while ($hasMoreData) {
        $requestCount++
        # Build the URL
        if ($null -ne $lastActivityId) {
            $url = "https://eu.ninjarmm.com/v2/activities?status=$Status&type=$Type&olderThan=$lastActivityId&pageSize=1000&after=$afterTs&before=$beforeTs"
        } else {
            $url = "https://eu.ninjarmm.com/v2/activities?status=$Status&type=$Type&pageSize=1000&after=$afterTs&before=$beforeTs"
        }
        Write-Host "[$requestCount] Fetching: $url" -ForegroundColor Yellow
        try {
            # Call the API
            $response = Invoke-WebRequest -Uri $url -Headers $AuthHeader -Method GET
            # Parse JSON content from response
            $json = $response.Content | ConvertFrom-Json
            # The endpoint returns an array of activities (adjust key if different)
            $activities = $json.activities
            if ($activities.Count -gt 0) {
                # Add to accumulated list
                $allActivities += $activities
                # Get the ID of the last (oldest) activity
                $lastActivityId = $activities[-1].id
                Write-Host "Fetched $($activities.Count) activities. Total so far: $($allActivities.Count)" -ForegroundColor Green
            } else {
                Write-Host "No more activities returned — stopping loop." -ForegroundColor Cyan
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

    #$url = "https://eu.ninjarmm.com/v2/activities?status=$Status&type=$Type&pageSize=1000&after=$afterTs&before=$beforeTs"
    #$response = Invoke-RestMethod -Method Get -Uri $url -Headers $AuthHeader
    return $allActivities
}


# Function to Get the CET time range for the last month and convert to epoch
function Get-CetEpochTimeRange {
    # CET / CEST time zone (automatically handles daylight savings)
    $cet = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Europe Standard Time")

    # Current time in CET
    $nowCet = [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $cet)

    # Exactly one month ago in CET
    $oneMonthAgoCet = $nowCet.AddMonths(-1)

    # Convert both CET times to UTC for Unix epoch conversion
    $nowUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($nowCet, $cet)
    $oneMonthAgoUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($oneMonthAgoCet, $cet)

    # Convert to epoch (seconds)
    $nowEpoch = [int][double]::Parse((Get-Date $nowUtc -UFormat %s))
    $oneMonthAgoEpoch = [int][double]::Parse((Get-Date $oneMonthAgoUtc -UFormat %s))

    # Output object
    [pscustomobject]@{
        NowCET            = $nowCet
        OneMonthAgoCET    = $oneMonthAgoCet
        NowEpoch          = $nowEpoch
        OneMonthAgoEpoch  = $oneMonthAgoEpoch
    }
}

# Function to convert epoch seconds to CET DateTime
function Convert-EpochToCET {
    param(
        [Parameter(Mandatory)]
        [long]$EpochSeconds
    )

    $utc = (Get-Date "1970-01-01") + ([TimeSpan]::FromSeconds($EpochSeconds))
    $cetTz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Europe Standard Time")
    return [System.TimeZoneInfo]::ConvertTimeFromUtc($utc, $cetTz)
}




$timeRange = Get-CetEpochTimeRange
$afterTs = $timeRange.OneMonthAgoEpoch
$beforeTs = $timeRange.NowEpoch

# Getting triggered and reset activities
$triggeredConditions = Get-NinjaActivities -Status "TRIGGERED" -afterTs $afterTs -beforeTs $beforeTs

$resetConditions = Get-NinjaActivities -Status "RESET" -afterTs $afterTs -beforeTs $beforeTs

# 
$resetBySeries = @{}
foreach ($reset in $resetConditions) {
    $resetBySeries[$reset.seriesUid] = $reset
}


# ---------------------------------------------
# MATCH TRIGGER ↔ RESET AND CALCULATE DURATION
# ---------------------------------------------
$results = foreach ($trigger in $triggeredConditions) {

    $series = $trigger.seriesUid

    if ($resetBySeries.ContainsKey($series)) {
        $reset = $resetBySeries[$series]

        # Duration in seconds
        $durationSeconds = [int]($reset.activityTime - $trigger.activityTime)

        [pscustomobject]@{
            DeviceId        = $trigger.deviceId
            ConditionName   = $trigger.message
            SeriesUid       = $series
            TriggeredAt     = Convert-EpochToCET -EpochSeconds $trigger.activityTime
            ResetAt         = Convert-EpochToCET -EpochSeconds $reset.activityTime
            DurationSeconds = $durationSeconds
            DurationHuman   = [timespan]::FromSeconds($durationSeconds).ToString()
        }
    }
}
