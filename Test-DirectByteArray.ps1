#Requires -Version 5.1

<#
.SYNOPSIS
    Tests full red screen using direct byte array (like proof-of-work)
.DESCRIPTION
    Creates pixel data directly without using Bitmap to test if that's the issue
#>

Write-Host "`n=== Direct Byte Array Test ===" -ForegroundColor Cyan
Write-Host "Testing full red screen WITHOUT using System.Drawing.Bitmap" -ForegroundColor Yellow

Import-Module PSDynaTab -Force

try {
    Write-Host "`nConnecting..." -ForegroundColor Cyan
    Connect-DynaTab
    Start-Sleep -Seconds 1

    # Test 1: Full RED using DIRECT byte array (like proof-of-work)
    Write-Host "`n[Test 1] Full RED - Direct Byte Array Method" -ForegroundColor Cyan
    Write-Host "Creating 1620 bytes of pixel data directly (no bitmap)..." -ForegroundColor Gray

    # Create pixel data directly: all red (FF 00 00 repeated 540 times)
    $pixelData = New-Object byte[] (60 * 9 * 3)  # 1620 bytes

    # Column-major order: for each column (0-59), set 9 rows to red
    $index = 0
    for ($col = 0; $col -lt 60; $col++) {
        for ($row = 0; $row -lt 9; $row++) {
            $pixelData[$index++] = 0xFF  # R
            $pixelData[$index++] = 0x00  # G
            $pixelData[$index++] = 0x00  # B
        }
    }

    Write-Host "  Created $($pixelData.Length) bytes" -ForegroundColor Gray
    Write-Host "  First 30 bytes: " -NoNewline -ForegroundColor Gray
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host ("{0:X2} " -f $pixelData[$i]) -NoNewline -ForegroundColor $(if ($pixelData[$i] -eq 0xFF) { 'Red' } else { 'Gray' })
    }
    Write-Host ""

    # Send using module's packet chunking
    Write-Host "`n>>> WATCH DISPLAY - Should turn completely RED <<<" -ForegroundColor Magenta
    $packets = New-PacketChunk -PixelData $pixelData

    Write-Host "Sending $($packets.Count) packets..." -ForegroundColor Gray
    foreach ($packet in $packets) {
        Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
    }

    Write-Host "✓ All packets sent" -ForegroundColor Green
    Start-Sleep -Seconds 3

    Write-Host "`nDid the display turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    if ($response1 -eq 'y') {
        Write-Host "`n✓✓✓ SUCCESS! Direct byte array works!" -ForegroundColor Green
        Write-Host "This confirms the issue is in how Bitmap creates pixel data" -ForegroundColor Yellow

        # Now test with Bitmap method to compare
        Write-Host "`n[Test 2] Full RED - Using Bitmap Method (for comparison)" -ForegroundColor Cyan
        Clear-DynaTab
        Start-Sleep -Seconds 1

        $bitmap = New-Object System.Drawing.Bitmap(60, 9)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 0, 0))
        $graphics.Dispose()

        Write-Host "Converting bitmap to pixel data..." -ForegroundColor Gray
        $bitmapPixelData = ConvertTo-PixelData -Image $bitmap

        Write-Host "  First 30 bytes from bitmap: " -NoNewline -ForegroundColor Gray
        for ($i = 0; $i -lt 30; $i++) {
            Write-Host ("{0:X2} " -f $bitmapPixelData[$i]) -NoNewline -ForegroundColor $(if ($bitmapPixelData[$i] -eq 0xFF) { 'Red' } else { 'Gray' })
        }
        Write-Host ""

        # Compare
        Write-Host "`nComparing direct vs bitmap pixel data..." -ForegroundColor Cyan
        $differences = 0
        for ($i = 0; $i -lt 30; $i++) {
            if ($pixelData[$i] -ne $bitmapPixelData[$i]) {
                Write-Host "  Byte $i : Direct=0x$($pixelData[$i].ToString('X2')) vs Bitmap=0x$($bitmapPixelData[$i].ToString('X2'))" -ForegroundColor Red
                $differences++
            }
        }

        if ($differences -eq 0) {
            Write-Host "  ✓ First 30 bytes are IDENTICAL" -ForegroundColor Green
            Write-Host "  Checking all 1620 bytes..." -ForegroundColor Gray

            for ($i = 0; $i -lt 1620; $i++) {
                if ($pixelData[$i] -ne $bitmapPixelData[$i]) {
                    Write-Host "  ✗ Difference at byte $i : Direct=0x$($pixelData[$i].ToString('X2')) vs Bitmap=0x$($bitmapPixelData[$i].ToString('X2'))" -ForegroundColor Red
                    $differences++
                    if ($differences -gt 10) {
                        Write-Host "  (stopping after 10 differences...)" -ForegroundColor Yellow
                        break
                    }
                }
            }

            if ($differences -eq 0) {
                Write-Host "  ✓ ALL bytes are identical!" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Found $differences differences" -ForegroundColor Red
            }
        }

        Write-Host "`n>>> WATCH DISPLAY - Testing bitmap method <<<" -ForegroundColor Magenta
        Send-DynaTabImage -Image $bitmap
        $bitmap.Dispose()

        Start-Sleep -Seconds 3
        Write-Host "`nDid bitmap method turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
        $response2 = Read-Host

        if ($response2 -eq 'n' -and $differences -eq 0) {
            Write-Host "`n⚠ STRANGE: Pixel data is identical but bitmap method doesn't work!" -ForegroundColor Yellow
            Write-Host "Issue might be in Send-DynaTabImage function itself" -ForegroundColor Yellow
        }

    } else {
        Write-Host "`n✗ Direct byte array also failed" -ForegroundColor Red
        Write-Host "Issue is NOT with bitmap conversion" -ForegroundColor Yellow

        # Verify single column still works
        Write-Host "`nVerifying single column (which we know works)..." -ForegroundColor Cyan
        Clear-DynaTab
        Start-Sleep -Seconds 1

        $singleColData = New-Object byte[] (60 * 9 * 3)
        # Only color first column
        for ($row = 0; $row -lt 9; $row++) {
            $singleColData[$row * 3] = 0xFF      # R
            $singleColData[$row * 3 + 1] = 0x00  # G
            $singleColData[$row * 3 + 2] = 0x00  # B
        }

        $singlePackets = New-PacketChunk -PixelData $singleColData
        foreach ($packet in $singlePackets) {
            Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
        }

        Start-Sleep -Seconds 2
        Write-Host "Did single column work? (y/n): " -ForegroundColor Yellow -NoNewline
        $responseSingle = Read-Host

        if ($responseSingle -eq 'y') {
            Write-Host "✓ Single column works, full screen doesn't" -ForegroundColor Yellow
            Write-Host "This suggests a device limitation with too much color data" -ForegroundColor Yellow
        }
    }

} finally {
    Write-Host "`nDisconnecting..." -ForegroundColor Gray
    Disconnect-DynaTab
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
