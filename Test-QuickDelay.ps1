# Test-QuickDelay.ps1
# Quick test of specific delay values

param(
    [Parameter(Mandatory=$false)]
    [int]$DelayMs = 200
)

Import-Module PSDynaTab -Force
Connect-DynaTab

Write-Host "`n=== Testing ${DelayMs}ms Post-Render Delay ===" -ForegroundColor Cyan
Write-Host "(Current internal delay: 100ms, Testing with ${DelayMs}ms additional)`n"

Write-Host "Test: RED -> BLUE (no external delay between calls)"
Set-DynaTabText -Text "RED" -Color Red
Set-DynaTabText -Text "BLUE" -Color Blue

$result1 = Read-Host "`nDid you see RED flash? (y/n)"

Write-Host "`nTest: 4-color sequence (no external delays)"
$colors = @([System.Drawing.Color]::Red, [System.Drawing.Color]::Green, [System.Drawing.Color]::Blue, [System.Drawing.Color]::Yellow)
$texts = @("RED", "GREEN", "BLUE", "YELLOW")

for ($i = 0; $i -lt 4; $i++) {
    Set-DynaTabText -Text $texts[$i] -Color $colors[$i]
}

$result2 = Read-Host "`nDid you see all 4 colors flash? (y/n)"

if ($result1 -eq 'y' -and $result2 -eq 'y') {
    Write-Host "`n✓ SUCCESS at ${DelayMs}ms!" -ForegroundColor Green
} else {
    Write-Host "`n✗ FAILED at ${DelayMs}ms" -ForegroundColor Red
    Write-Host "Try a higher value: .\Test-QuickDelay.ps1 -DelayMs $([int]$DelayMs + 100)" -ForegroundColor Yellow
}

Disconnect-DynaTab
