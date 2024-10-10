param (
    [int]$runtimeInMinutes = 120, # Runtime duration in minutes (default 2 hours)
    [string]$url = "https://testnet-faucet.lumia.org/api/claim", # The API URL
    [string]$address = "0x2278f2601E956f576d7882E15BBb9cB7dEC6F595"  # Address for the request body
)

# Initialize counters for success and failed requests
$global:successCount = 0
$global:failedCount = 0
$global:rateLimitErrorFound = $false
$global:notSucceedYet = $true
$global:response = $null
$startTime = Get-Date

# Function to send the request
function Send-Request {
    $headers = @{
        "accept"             = "*/*"
        "accept-language"    = "en-GB,en;q=0.9,bn-BD;q=0.8,bn;q=0.7,en-US;q=0.6"
        "content-type"       = "application/json"
        "priority"           = "u=1, i"
        "sec-ch-ua"          = "`"Google Chrome`";v=`"129`", `"Not=A?Brand`";v=`"8`", `"Chromium`";v=`"129`""
        "sec-ch-ua-mobile"   = "?0"
        "sec-ch-ua-platform" = "`"Windows`""
        "sec-fetch-dest"     = "empty"
        "sec-fetch-mode"     = "cors"
        "sec-fetch-site"     = "same-origin"
    }

    $body = @{
        "address" = $address
    } | ConvertTo-Json

    try {
        # Make the request using Invoke-RestMethod to capture JSON response
        $global:response = Invoke-RestMethod -Uri $url `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ContentType "application/json"

        # Check for success
        $global:notSucceedYet = $false
        $global:successCount++
    }
    catch {
        # Detect rate limit (HTTP 429) error
        if ($_.Exception.Response.StatusCode -eq 429) {

            $str =$_ -split "`n"
            

            if ($global:notSucceedYet) {
                $global:rateLimitMessage = $false
                write-host "`nDebug: Server Busy " $str "Trying Again" -ForegroundColor Blue 
            }
            else {
                <# Action when all if and elseif conditions are false #>
                $global:rateLimitErrorFound = $true
                $global:notSucceedYet = $true
            }
            
            # Parse the response body as JSON to capture the "msg" field

            # Assign the rate limit message
            $global:rateLimitMessage = $_

            # Write-Host "`nDebug: " $global:rateLimitMessage -ForegroundColor Blue 

        }
        else {
            $global:failedCount++
        }
    }
}

# Function to show a dynamic countdown
function Show-Countdown {
    param (
        [int]$seconds
    )
    
    for ($i = $seconds; $i -gt 0; $i--) {
        Write-Host "`rRate limit reached. Retrying in $i seconds..." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1
    }
}

# Function to update status without clearing the console
function Update-Status {
    $elapsedTime = (Get-Date) - $startTime
    Write-Host ("`rTotal successful requests: {0} | Current Hash: {1} | Time elapsed: {2}" -f `
            $global:successCount, `
            $global:response, `
            $elapsedTime.ToString("hh\:mm\:ss")) -NoNewline -ForegroundColor Green
}

# Start the timer
$endTime = $startTime.AddMinutes($runtimeInMinutes)

Write-Host "Starting the process. Will run for $runtimeInMinutes minutes or until stopped by the user."
Write-Host "Requested to drop bug/issues at https://t.me/Cyber_Arm_y/10" -BackgroundColor DarkGreen -ForegroundColor White

# Run the loop until the specified duration is reached
while ((Get-Date) -lt $endTime) {
    $global:rateLimitErrorFound = $false

    # Send requests until rate limit error is detected
    while (-not $global:rateLimitErrorFound -and (Get-Date) -lt $endTime) {
        Send-Request
        $delay = Get-Random -InputObject @(1, 2)
        Write-Host "`rTo Avoid rate limit sleeping $delay seconds................................................." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds $delay
        Update-Status
    }
    
    # Handle rate limit error by showing the countdown and retrying
    if ($global:rateLimitErrorFound) {

        # Display the rate limit message if available
        if ($global:rateLimitMessage) {
            Write-Host "`nRate limit message: $global:rateLimitMessage" -ForegroundColor Red
        }

        # Random delay before retrying
        $randomDelay = Get-Random -InputObject @(59, 60, 61, 62, 63)
        Show-Countdown -seconds $randomDelay

        # Reset the flag
        $rateLimitErrorFound = $false
    }
}

# Final summary
Write-Host "`nProcess completed!"
Write-Host "Final total successful requests: $successCount"
Write-Host "Final total failed requests: $failedCount"
