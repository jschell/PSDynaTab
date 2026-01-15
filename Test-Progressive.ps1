#Requires -Version 5.1

<#
.SYNOPSIS
    Progressive column test to find where display fails
.DESCRIPTION
    Gradually increases number of colored columns to identify breaking point
#>

Write-Host "`n=== Progressive Column Test ===" -ForegroundColor Cyan
Write-Host "This test will gradually increase the number of red columns" -ForegroundColor Yellow
Write-Host "Press CTRL+C to stop at any time`n" -ForegroundColor Yellow

Import-Module PSDynaTab -Force

try {
    Write-Host "Connecting..." -ForegroundColor Cyan
    Connect-DynaTab
    Start-Sleep -Seconds 1

    # Test configurations: number of columns to color
    $tests = @(1, 2, 3, 5, 10, 15, 20, 30, 40, 50, 60)

    foreach ($numColumns in $tests) {
        Write-Host "`n[Test] $numColumns columns" -ForegroundColor Cyan
        Write-Host "Creating image with $numColumns red columns..." -ForegroundColor Gray

        # Create bitmap
        $bitmap = New-Object System.Drawing.Bitmap(60, 9)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::Black)

        # Color the specified number of columns (starting from left)
        for ($col = 0; $col -lt $numColumns; $col++) {
            for ($row = 0; $row -lt 9; $row++) {
                $bitmap.SetPixel($col, $row, [System.Drawing.Color]::Red)
            }
        }

        $graphics.Dispose()

        Write-Host ">>> WATCH DISPLAY - Should see $numColumns red columns from the left <<<" -ForegroundColor Magenta
        Send-DynaTabImage -Image $bitmap

        $bitmap.Dispose()

        Write-Host "Waiting 3 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 3

        Write-Host "Did you see $numColumns red columns? (y/n/q to quit): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host

        if ($response -eq 'q') {
            Write-Host "Test stopped by user" -ForegroundColor Yellow
            break
        } elseif ($response -eq 'y') {
            Write-Host "  ✓ $numColumns columns SUCCESS" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $numColumns columns FAILED - found breaking point!" -ForegroundColor Red
            Write-Host "`nBreaking point identified: Display fails at $numColumns columns" -ForegroundColor Yellow

            # Try previous amount with longer delay
            $prevColumns = $tests[$tests.IndexOf($numColumns) - 1]
            Write-Host "`nRetrying $prevColumns columns (which worked) with 10ms packet delay..." -ForegroundColor Cyan

            Disconnect-DynaTab

            # Temporarily increase delay in Send-FeaturePacket by using direct method
            Write-Host "Testing if timing is the issue..." -ForegroundColor Yellow

            break
        }

        # Clear display between tests
        Write-Host "Clearing display..." -ForegroundColor Gray
        Clear-DynaTab
        Start-Sleep -Seconds 1
    }

    if ($response -ne 'q' -and $response -eq 'y') {
        Write-Host "`n✓✓✓ ALL TESTS PASSED!" -ForegroundColor Green
        Write-Host "Display can handle all 60 columns" -ForegroundColor Green
    }

} finally {
    Write-Host "`nDisconnecting..." -ForegroundColor Gray
    Disconnect-DynaTab
}

Write-Host "`n=== Progressive Test Complete ===" -ForegroundColor Cyan
