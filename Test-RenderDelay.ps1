# Test-RenderDelay.ps1
# Tests if the post-render delay fix works for rapid successive calls

Import-Module PSDynaTab -Force
Connect-DynaTab

Write-Host "`n=== Testing Post-Render Delay Fix ===" -ForegroundColor Cyan
Write-Host "With 200ms internal delay in Set-DynaTabText`n"

# Test 1: Rapid successive calls (no delay between)
Write-Host "Test 1: Four rapid successive calls (no delay between calls)"
Write-Host "Expected: All four colors should flash briefly"
$colors = @([System.Drawing.Color]::Red, [System.Drawing.Color]::Green, [System.Drawing.Color]::Blue, [System.Drawing.Color]::Yellow)
$texts = @("RED", "GREEN", "BLUE", "YELLOW")

for ($i = 0; $i -lt 4; $i++) {
    Set-DynaTabText -Text $texts[$i] -Color $colors[$i]
}

$response = Read-Host "`nDid you see all 4 colors flash? (y/n)"
if ($response -eq 'y') {
    Write-Host "✓ SUCCESS - Post-render delay fix working!" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED - Need longer delay" -ForegroundColor Red
}

# Test 2: Spinner simulation with 250ms frames
Write-Host "`nTest 2: Spinner simulation (250ms frame delay)"
Write-Host "Expected: All spinner characters should be visible"
$spinnerFrames = @('-', '\', '|', '/')

for ($i = 0; $i -lt 8; $i++) {
    $spinnerChar = $spinnerFrames[$i % 4]
    Set-DynaTabText -Text "$spinnerChar LOAD" -Alignment Left
    Start-Sleep -Milliseconds 250
}

$response = Read-Host "`nDid you see all spinner frames? (y/n)"
if ($response -eq 'y') {
    Write-Host "✓ SUCCESS - Spinner animation working!" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED - Spinner still broken" -ForegroundColor Red
}

# Test 3: Fast spinner (100ms frames)
Write-Host "`nTest 3: Fast spinner (100ms frame delay)"
Write-Host "Expected: Spinner visible but may be too fast to see individual frames"

for ($i = 0; $i -lt 12; $i++) {
    $spinnerChar = $spinnerFrames[$i % 4]
    Set-DynaTabText -Text "$spinnerChar FAST" -Alignment Left
    Start-Sleep -Milliseconds 100
}

$response = Read-Host "`nDid you see spinner animation (even if fast)? (y/n)"
if ($response -eq 'y') {
    Write-Host "✓ SUCCESS - Fast spinner working!" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED - Too fast or delay insufficient" -ForegroundColor Red
}

# Test 4: Show-DynaTabSpinner function
Write-Host "`nTest 4: Show-DynaTabSpinner function (3 seconds)"
Write-Host "Expected: Smooth spinner animation for 3 seconds, then 'DONE'"

Show-DynaTabSpinner -Text "TESTING" -Seconds 3 -CompletionText "DONE" -FrameDelayMs 250

$response = Read-Host "`nDid spinner work correctly and show DONE at end? (y/n)"
if ($response -eq 'y') {
    Write-Host "✓ SUCCESS - Show-DynaTabSpinner working!" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED - Show-DynaTabSpinner broken" -ForegroundColor Red
}

Write-Host "`n=== Tests Complete ===" -ForegroundColor Cyan

Disconnect-DynaTab
