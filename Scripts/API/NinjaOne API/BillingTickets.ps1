$ClientID = $env:NINJA_CLIENT_ID
$Secret = $env:NINJA_CLIENT_SECRET
$RedirectURL = $env:NINJA_REDIRECT_URL



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

$descriptionPattern = (
    'Ticket:\s*(?<TicketID>\d+)\s*-\s*' +
    'Subject:\s*(?<Subject>.+?)\s*-\s*' +
    'Comment:\s*(?<Comment>.+?)\s*-\s*' +
    'In Hours:\s*(?<InHours>.+?)\s*-\s*' +
    'Time:\s*(?<BilledHours>.+?)\s*-\s*' +
    '(?<TimeEntryStartDate>\d{4}-\d{2}-\d{2})\s*-\s*' +
    '(?<TicketRequester>.+?)\s*-\s*' +
    'Tech:\s*(?<TimeEntryTechnician>.+?)\s*-\s*' +
    'Comment Time:\s*(?<TimeEntryCreationDateTime>.+)$'
)

function Get-BillingTicketInfo {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ClientId,

        [Parameter(Mandatory = $false)]
        [int]$AgreementId
    )

    $today        = Get-Date
    $firstOfMonth = (Get-Date -Year $today.Year -Month $today.Month -Day 1).ToString('yyyy-MM-dd')
    $lastOfMonth  = (Get-Date -Year $today.Year -Month $today.Month -Day ([DateTime]::DaysInMonth($today.Year, $today.Month))).ToString('yyyy-MM-dd')

    $queryParams = [System.Collections.Generic.Dictionary[string,string]]::new()
    $queryParams['clientId']        = $ClientId
    $queryParams['createdDateFrom'] = $firstOfMonth
    $queryParams['createdDateTo']   = $lastOfMonth
    $queryParams['periodFrom']      = $firstOfMonth
    $queryParams['periodTo']        = $lastOfMonth

    if ($PSBoundParameters.ContainsKey('AgreementId')) {
        $queryParams['agreementId'] = $AgreementId
    }

    $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
    $invoices    = Invoke-RestMethod -Uri "https://se-test-env.rmmservice.eu/v2/billing/invoices?$queryString" -Method GET -Headers $AuthHeader

    $result = $invoices | ForEach-Object {
        $invoiceDetail = Invoke-RestMethod -Uri "https://se-test-env.rmmservice.eu/v2/billing/invoices/112" -Method GET -Headers $AuthHeader

        $invoiceDetail.agreementProducts |
            Where-Object { $_.quantityType -eq "TIME_ENTRIES" -and $_.description -match $descriptionPattern } |
            ForEach-Object {
                $product = $_
                $null = $product.description -match $descriptionPattern

                [PSCustomObject]@{
                    TicketId                  = $matches['TicketID']
                    Subject                   = $matches['Subject']
                    Comment                   = $matches['Comment']
                    InHours                   = $matches['InHours']
                    BilledHours               = $matches['BilledHours']
                    TimeEntryStartDate        = $matches['TimeEntryStartDate']
                    TicketRequester           = $matches['TicketRequester']
                    TimeEntryTechnician       = $matches['TimeEntryTechnician']
                    TimeEntryCreationDateTime = $matches['TimeEntryCreationDateTime']
                    Total                     = $product.total
                    BillingPeriodStartDate    = $product.billingPeriodStartDate
                }
            }
    }

    return $result
}

$EndResult = Get-BillingTicketInfo -ClientId 113