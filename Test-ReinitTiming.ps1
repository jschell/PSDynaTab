# Test-ReinitTiming.ps1
# Tests post-render timing to determine minimum delay needed after packets sent

Import-Module ./PSDynaTab/PSDynaTab.psd1 -Force
Connect-DynaTab

Write-Host "`nTesting delays AFTER sending packets (for render time)..."
Write-Host "This simulates what happens in spinner: send frame, wait, send next frame"
Write-Host "=========================================================`n"

foreach ($delayMs in @(0, 50, 100, 150, 200, 250)) {
    Write-Host "Testing ${delayMs}ms delay AFTER packets sent..."

    # Send first text (RED)
    Set-DynaTabText -Text "RED" -Color Red

    # Wait AFTER sending (simulate render time)
    if ($delayMs -gt 0) {
        Start-Sleep -Milliseconds $delayMs
    }

    # Immediately send second text (simulates next spinner frame clearing display)
    Set-DynaTabText -Text "BLUE" -Color Blue

    Start-Sleep -Seconds 1
    $response = Read-Host "Did you see RED (even briefly) before BLUE? (y/n)"

    if ($response -eq 'y') {
        Write-Host "SUCCESS at ${delayMs}ms post-render delay" -ForegroundColor Green
    } else {
        Write-Host "FAILED at ${delayMs}ms post-render delay" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "`nNow testing with delay built into Set-DynaTabText simulation..."
Write-Host "This will help determine if delay should be IN the function or BETWEEN calls"
Write-Host "=========================================================`n"

foreach ($delayMs in @(100, 150, 200)) {
    Write-Host "Testing with ${delayMs}ms FrameDelay in spinner simulation..."

    $colors = @([System.Drawing.Color]::Red, [System.Drawing.Color]::Green, [System.Drawing.Color]::Blue, [System.Drawing.Color]::Yellow)
    $texts = @("RED", "GREEN", "BLUE", "YELLOW")

    for ($i = 0; $i -lt 4; $i++) {
        Set-DynaTabText -Text $texts[$i] -Color $colors[$i]
        Start-Sleep -Milliseconds $delayMs
    }

    $response = Read-Host "Did you see all 4 colors flash? (y/n)"

    if ($response -eq 'y') {
        Write-Host "SUCCESS at ${delayMs}ms between frames" -ForegroundColor Green
    } else {
        Write-Host "FAILED at ${delayMs}ms between frames" -ForegroundColor Red
    }
    Write-Host ""
}

Disconnect-DynaTab
