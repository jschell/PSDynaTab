# Test-500ms.ps1
# Quick test of 500ms internal delay

Import-Module PSDynaTab -Force
Connect-DynaTab

Write-Host "`n=== Testing 500ms Internal Post-Render Delay ===" -ForegroundColor Cyan

Write-Host "`nTest 1: RED -> BLUE (rapid successive, no external delay)"
Set-DynaTabText -Text "RED" -Color Red
Set-DynaTabText -Text "BLUE" -Color Blue
Start-Sleep -Seconds 1

$test1 = Read-Host "Did you see RED flash before BLUE? (y/n)"

Write-Host "`nTest 2: 4-color rapid sequence"
$colors = @([System.Drawing.Color]::Red, [System.Drawing.Color]::Green, [System.Drawing.Color]::Blue, [System.Drawing.Color]::Yellow)
$texts = @("RED", "GREEN", "BLUE", "YELLOW")

for ($i = 0; $i -lt 4; $i++) {
    Set-DynaTabText -Text $texts[$i] -Color $colors[$i]
}
Start-Sleep -Seconds 1

$test2 = Read-Host "Did you see all 4 colors flash? (y/n)"

Write-Host "`nTest 3: Show-DynaTabSpinner (3 seconds, 250ms frames)"
Show-DynaTabSpinner -Text "LOADING" -Seconds 3 -FrameDelayMs 250 -CompletionText "DONE"
Start-Sleep -Seconds 1

$test3 = Read-Host "Did spinner animate and show DONE? (y/n)"

if ($test1 -eq 'y' -and $test2 -eq 'y' -and $test3 -eq 'y') {
    Write-Host "`n✓ ALL TESTS PASSED with 500ms delay!" -ForegroundColor Green
} else {
    Write-Host "`n✗ Some tests failed:" -ForegroundColor Red
    Write-Host "  Test 1 (RED/BLUE): $test1"
    Write-Host "  Test 2 (4 colors): $test2"
    Write-Host "  Test 3 (Spinner): $test3"

    if ($test1 -eq 'n') {
        Write-Host "`nTry 750ms or 1000ms delay" -ForegroundColor Yellow
    }
}

Disconnect-DynaTab
