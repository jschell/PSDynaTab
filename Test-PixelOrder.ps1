#Requires -Version 5.1

<#
.SYNOPSIS
    Test pixel data ordering to diagnose display issues
.DESCRIPTION
    Tests different pixel patterns to identify the exact problem
#>

Write-Host "`n=== Pixel Data Order Test ===" -ForegroundColor Cyan

Import-Module PSDynaTab -Force

try {
    Connect-DynaTab

    Write-Host "`n[Test 1] Single Red Column (like proof of work)" -ForegroundColor Cyan
    Write-Host ">>> WATCH THE DISPLAY - Should show ONE red column on the left <<<" -ForegroundColor Magenta
    Start-Sleep -Seconds 2

    # Create image with only first column red (matching proof of work)
    $img1 = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($img1)
    $graphics.Clear([System.Drawing.Color]::Black)

    # Set only first column to red
    for ($row = 0; $row -lt 9; $row++) {
        $img1.SetPixel(0, $row, [System.Drawing.Color]::Red)
    }
    $graphics.Dispose()

    Send-DynaTabImage -Image $img1
    $img1.Dispose()

    Write-Host "`nDid you see a red column on the left? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    if ($response1 -eq 'y') {
        Write-Host "✓ Single column works!" -ForegroundColor Green
    } else {
        Write-Host "✗ Single column failed" -ForegroundColor Red
    }

    Start-Sleep -Seconds 2

    Write-Host "`n[Test 2] Two Red Columns" -ForegroundColor Cyan
    Write-Host ">>> WATCH THE DISPLAY - Should show TWO red columns <<<" -ForegroundColor Magenta
    Start-Sleep -Seconds 2

    $img2 = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($img2)
    $graphics.Clear([System.Drawing.Color]::Black)

    # Set first two columns to red
    for ($row = 0; $row -lt 9; $row++) {
        $img2.SetPixel(0, $row, [System.Drawing.Color]::Red)
        $img2.SetPixel(1, $row, [System.Drawing.Color]::Red)
    }
    $graphics.Dispose()

    Send-DynaTabImage -Image $img2
    $img2.Dispose()

    Write-Host "`nDid you see TWO red columns? (y/n): " -ForegroundColor Yellow -NoNewline
    $response2 = Read-Host

    if ($response2 -eq 'y') {
        Write-Host "✓ Two columns work!" -ForegroundColor Green
    } else {
        Write-Host "✗ Two columns failed" -ForegroundColor Red
    }

    Start-Sleep -Seconds 2

    Write-Host "`n[Test 3] Full Red Display" -ForegroundColor Cyan
    Write-Host ">>> WATCH THE DISPLAY - Should be completely red <<<" -ForegroundColor Magenta
    Start-Sleep -Seconds 2

    $img3 = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($img3)
    $graphics.Clear([System.Drawing.Color]::Red)
    $graphics.Dispose()

    Send-DynaTabImage -Image $img3
    $img3.Dispose()

    Write-Host "`nDid the entire display turn red? (y/n): " -ForegroundColor Yellow -NoNewline
    $response3 = Read-Host

    if ($response3 -eq 'y') {
        Write-Host "✓ Full display works!" -ForegroundColor Green
    } else {
        Write-Host "✗ Full display failed" -ForegroundColor Red
    }

    Start-Sleep -Seconds 2

    Write-Host "`n[Test 4] Analyze Pixel Data" -ForegroundColor Cyan

    # Create test images and dump first few bytes
    Write-Host "`nSingle column red (what SHOULD work):" -ForegroundColor Yellow
    $testImg = New-Object System.Drawing.Bitmap(60, 9)
    for ($row = 0; $row -lt 9; $row++) {
        $testImg.SetPixel(0, $row, [System.Drawing.Color]::Red)
    }

    # Manually convert to see pixel data
    $pixelData = New-Object byte[] 1620
    $index = 0
    for ($col = 0; $col -lt 60; $col++) {
        for ($row = 0; $row -lt 9; $row++) {
            $pixel = $testImg.GetPixel($col, $row)
            $pixelData[$index++] = $pixel.R
            $pixelData[$index++] = $pixel.G
            $pixelData[$index++] = $pixel.B
        }
    }

    Write-Host "  First 30 bytes: " -NoNewline
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host ("{0:X2} " -f $pixelData[$i]) -NoNewline -ForegroundColor Gray
    }
    Write-Host ""

    $testImg.Dispose()

    Write-Host "`nFull red display:" -ForegroundColor Yellow
    $testImg2 = New-Object System.Drawing.Bitmap(60, 9)
    $graphics2 = [System.Drawing.Graphics]::FromImage($testImg2)
    $graphics2.Clear([System.Drawing.Color]::Red)
    $graphics2.Dispose()

    $pixelData2 = New-Object byte[] 1620
    $index = 0
    for ($col = 0; $col -lt 60; $col++) {
        for ($row = 0; $row -lt 9; $row++) {
            $pixel = $testImg2.GetPixel($col, $row)
            $pixelData2[$index++] = $pixel.R
            $pixelData2[$index++] = $pixel.G
            $pixelData2[$index++] = $pixel.B
        }
    }

    Write-Host "  First 30 bytes: " -NoNewline
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host ("{0:X2} " -f $pixelData2[$i]) -NoNewline -ForegroundColor Gray
    }
    Write-Host ""

    $testImg2.Dispose()

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Test 1 (1 column): $response1"
    Write-Host "Test 2 (2 columns): $response2"
    Write-Host "Test 3 (Full red): $response3"

} finally {
    Disconnect-DynaTab
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
