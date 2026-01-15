#Requires -Version 5.1

<#
.SYNOPSIS
    Tests full red screen using direct byte array (like proof-of-work)
.DESCRIPTION
    Creates pixel data directly without using Bitmap to test if that's the issue.
    Uses direct HID calls (no private module functions).
#>

Write-Host "`n=== Direct Byte Array Test ===" -ForegroundColor Cyan
Write-Host "Testing full red screen WITHOUT using System.Drawing.Bitmap" -ForegroundColor Yellow
Write-Host "Using direct HID method (like proof-of-work)`n" -ForegroundColor Yellow

# Load HidSharp
Write-Host "Loading HidSharp..." -ForegroundColor Cyan
$hidSharpPath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
if (-not (Test-Path $hidSharpPath)) {
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $hidSharpPath = "$documentsPath\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
}

Add-Type -Path $hidSharpPath
Write-Host "✓ HidSharp loaded" -ForegroundColor Green

# Find device
Write-Host "Finding device..." -ForegroundColor Cyan
$devices = @([HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015))

$screenDevice = $null
foreach ($dev in $devices) {
    $path = $dev.DevicePath
    if ($path -like "*mi_02*") {
        $featureReportSize = $dev.GetMaxFeatureReportLength()
        if ($featureReportSize -eq 65) {
            $screenDevice = $dev
            break
        }
    }
}

if (-not $screenDevice) {
    throw "Screen interface not found!"
}

Write-Host "✓ Screen interface found" -ForegroundColor Green

# Init packet
$FIRST_PACKET = [byte[]]@(
    0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
    0x00, 0x00, 0x3c, 0x09, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

try {
    $stream = $screenDevice.Open()
    Write-Host "✓ Device opened" -ForegroundColor Green

    # Send init packet
    Write-Host "`nSending initialization packet..." -ForegroundColor Cyan
    $initPacket = New-Object byte[] 65
    $initPacket[0] = 0x00  # Report ID
    for ($i = 0; $i -lt $FIRST_PACKET.Length; $i++) {
        $initPacket[$i + 1] = $FIRST_PACKET[$i]
    }

    $stream.SetFeature($initPacket)
    Write-Host "✓ Init packet sent" -ForegroundColor Green
    Start-Sleep -Milliseconds 10

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

    # Chunk and send packets (direct implementation, no private functions)
    Write-Host "`n>>> WATCH DISPLAY - Should turn completely RED <<<" -ForegroundColor Magenta
    Write-Host "Sending packets..." -ForegroundColor Gray

    $base_address = 0x0000389D
    $incrementing = 0
    $decrementing = $base_address
    $packetCount = 0

    for ($offset = 0; $offset -lt $pixelData.Length; $offset += 56) {
        $chunkSize = [Math]::Min(56, $pixelData.Length - $offset)

        $packet = New-Object byte[] 65
        $packet[0] = 0x00   # Report ID
        $packet[1] = 0x29   # Fixed header byte
        $packet[2] = 0x00   # Frame index
        $packet[3] = 0x01   # Image mode
        $packet[4] = 0x00   # Fixed

        # Incrementing (little endian)
        $packet[5] = $incrementing -band 0xFF
        $packet[6] = ($incrementing -shr 8) -band 0xFF

        # Decrementing (big endian)
        $packet[7] = ($decrementing -shr 8) -band 0xFF
        $packet[8] = $decrementing -band 0xFF

        # Copy pixel data
        for ($i = 0; $i -lt $chunkSize; $i++) {
            $packet[9 + $i] = $pixelData[$offset + $i]
        }

        $stream.SetFeature($packet)
        $packetCount++

        if ($packetCount % 10 -eq 0) {
            Write-Host "  Sent $packetCount packets" -ForegroundColor Gray
        }

        $incrementing++
        $decrementing--

        Start-Sleep -Milliseconds 5
    }

    Write-Host "✓ Sent $packetCount packets" -ForegroundColor Green
    Start-Sleep -Seconds 3

    Write-Host "`nDid the display turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    if ($response1 -eq 'y') {
        Write-Host "`n✓✓✓ SUCCESS! Direct byte array works!" -ForegroundColor Green
        Write-Host "This confirms the issue is in how Bitmap creates pixel data" -ForegroundColor Yellow

        # Now test with Bitmap method via module
        Write-Host "`n[Test 2] Full RED - Using Module's Bitmap Method (for comparison)" -ForegroundColor Cyan

        $stream.Close()
        Import-Module PSDynaTab -Force
        Connect-DynaTab
        Start-Sleep -Seconds 1

        $bitmap = New-Object System.Drawing.Bitmap(60, 9)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 0, 0))
        $graphics.Dispose()

        Write-Host ">>> WATCH DISPLAY - Testing bitmap method <<<" -ForegroundColor Magenta
        Send-DynaTabImage -Image $bitmap
        $bitmap.Dispose()

        Start-Sleep -Seconds 3
        Write-Host "`nDid bitmap method turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
        $response2 = Read-Host

        if ($response2 -eq 'n') {
            Write-Host "`n⚠ CONFIRMED: Direct byte array works, bitmap doesn't!" -ForegroundColor Yellow
            Write-Host "Issue is in bitmap-to-pixel conversion or Send-DynaTabImage" -ForegroundColor Yellow
        } else {
            Write-Host "`n✓ Both methods work!" -ForegroundColor Green
        }

        Disconnect-DynaTab

    } else {
        Write-Host "`n✗ Direct byte array also failed" -ForegroundColor Red
        Write-Host "Issue is NOT with bitmap conversion" -ForegroundColor Yellow

        # Verify single column still works
        Write-Host "`nVerifying single column (which we know works)..." -ForegroundColor Cyan

        # Send all-black first
        $blackData = New-Object byte[] (60 * 9 * 3)
        $blackInc = 0
        $blackDec = 0x389D
        for ($offset = 0; $offset -lt $blackData.Length; $offset += 56) {
            $chunkSize = [Math]::Min(56, $blackData.Length - $offset)
            $packet = New-Object byte[] 65
            $packet[0] = 0x00
            $packet[1] = 0x29
            $packet[2] = 0x00
            $packet[3] = 0x01
            $packet[4] = 0x00
            $packet[5] = $blackInc -band 0xFF
            $packet[6] = ($blackInc -shr 8) -band 0xFF
            $packet[7] = ($blackDec -shr 8) -band 0xFF
            $packet[8] = $blackDec -band 0xFF
            for ($i = 0; $i -lt $chunkSize; $i++) {
                $packet[9 + $i] = $blackData[$offset + $i]
            }
            $stream.SetFeature($packet)
            $blackInc++
            $blackDec--
            Start-Sleep -Milliseconds 5
        }
        Start-Sleep -Seconds 1

        # Single column
        $singleColData = New-Object byte[] (60 * 9 * 3)
        for ($row = 0; $row -lt 9; $row++) {
            $singleColData[$row * 3] = 0xFF      # R
            $singleColData[$row * 3 + 1] = 0x00  # G
            $singleColData[$row * 3 + 2] = 0x00  # B
        }

        $singleInc = 0
        $singleDec = 0x389D
        for ($offset = 0; $offset -lt $singleColData.Length; $offset += 56) {
            $chunkSize = [Math]::Min(56, $singleColData.Length - $offset)
            $packet = New-Object byte[] 65
            $packet[0] = 0x00
            $packet[1] = 0x29
            $packet[2] = 0x00
            $packet[3] = 0x01
            $packet[4] = 0x00
            $packet[5] = $singleInc -band 0xFF
            $packet[6] = ($singleInc -shr 8) -band 0xFF
            $packet[7] = ($singleDec -shr 8) -band 0xFF
            $packet[8] = $singleDec -band 0xFF
            for ($i = 0; $i -lt $chunkSize; $i++) {
                $packet[9 + $i] = $singleColData[$offset + $i]
            }
            $stream.SetFeature($packet)
            $singleInc++
            $singleDec--
            Start-Sleep -Milliseconds 5
        }

        Start-Sleep -Seconds 2
        Write-Host "Did single column work? (y/n): " -ForegroundColor Yellow -NoNewline
        $responseSingle = Read-Host

        if ($responseSingle -eq 'y') {
            Write-Host "✓ Single column works, full screen doesn't" -ForegroundColor Yellow
            Write-Host "This suggests a device limitation with too much color data" -ForegroundColor Yellow
        }

        $stream.Close()
    }

} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($stream) { $stream.Close() }
    throw
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
