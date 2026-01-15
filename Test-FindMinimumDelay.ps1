# Test-FindMinimumDelay.ps1
# Find the minimum post-render delay that allows display to work

Import-Module PSDynaTab -Force
Connect-DynaTab

Write-Host "`n=== Finding Minimum Render Delay ===" -ForegroundColor Cyan
Write-Host "Testing incremental delays to find minimum that works`n"

# Test delays - note: internal delay already 100ms, so these are ADDITIONAL
# Total delay = 100ms (internal) + external value
# Starting higher since 350ms total (100+250) already failed in previous tests
$delayValues = @(400, 500, 600, 700, 800, 900, 1000)

foreach ($delayMs in $delayValues) {
    Write-Host "Testing ${delayMs}ms delay..." -ForegroundColor Yellow

    # Manually modify the delay for this test
    # We'll send two texts rapidly to see if first displays

    # First, let's just test if a single text displays with current 100ms
    # Then we'll know if we need to modify the internal delay

    Write-Host "  Sending RED, waiting ${delayMs}ms, sending BLUE..."
    Set-DynaTabText -Text "RED" -Color Red
    Start-Sleep -Milliseconds $delayMs
    Set-DynaTabText -Text "BLUE" -Color Blue

    Start-Sleep -Seconds 1
    $response = Read-Host "  Did you see RED flash before BLUE? (y/n/q to quit)"

    if ($response -eq 'q') {
        Write-Host "`nTest aborted by user" -ForegroundColor Yellow
        break
    }

    if ($response -eq 'y') {
        Write-Host "  ✓ SUCCESS at ${delayMs}ms!" -ForegroundColor Green
        Write-Host "`nMinimum working delay: ${delayMs}ms" -ForegroundColor Green
        Write-Host "This is the EXTERNAL delay. Internal delay is currently 100ms." -ForegroundColor Cyan
        Write-Host "Total time needed: 100ms (internal) + ${delayMs}ms (external) = $([int]100 + $delayMs)ms" -ForegroundColor Cyan
        Write-Host "`nRecommendation: Set internal delay to $([int]100 + $delayMs)ms and remove external delays" -ForegroundColor Yellow
        break
    } else {
        Write-Host "  ✗ Failed at ${delayMs}ms" -ForegroundColor Red
    }
}

Disconnect-DynaTab
