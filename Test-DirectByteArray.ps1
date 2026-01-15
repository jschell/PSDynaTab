#Requires -Version 5.1

<#
.SYNOPSIS
    Tests full red screen using direct byte array vs bitmap conversion
.DESCRIPTION
    Compares direct byte array (like proof-of-work) vs bitmap conversion method.
    Contains embedded copies of private module functions for testing.
#>

Write-Host "`n=== Direct Byte Array vs Bitmap Test ===" -ForegroundColor Cyan

# ===== EMBEDDED PRIVATE FUNCTIONS (for testing) =====

function Local-ConvertTo-PixelData {
    param([System.Drawing.Image]$Image)

    $SCREEN_WIDTH = 60
    $SCREEN_HEIGHT = 9
    $PIXEL_BYTES = 1620

    # Convert to RGB (remove alpha channel)
    $bitmap = New-Object System.Drawing.Bitmap($Image.Width, $Image.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.DrawImage($Image, 0, 0, $Image.Width, $Image.Height)
    $graphics.Dispose()

    # Resize to 60x9 if needed
    if ($bitmap.Width -ne $SCREEN_WIDTH -or $bitmap.Height -ne $SCREEN_HEIGHT) {
        $resized = New-Object System.Drawing.Bitmap($SCREEN_WIDTH, $SCREEN_HEIGHT)
        $graphics = [System.Drawing.Graphics]::FromImage($resized)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($bitmap, 0, 0, $SCREEN_WIDTH, $SCREEN_HEIGHT)
        $graphics.Dispose()
        $bitmap.Dispose()
        $bitmap = $resized
    }

    # Convert to byte array in column-major order
    $pixelData = New-Object byte[] $PIXEL_BYTES
    $index = 0

    for ($col = 0; $col -lt $SCREEN_WIDTH; $col++) {
        for ($row = 0; $row -lt $SCREEN_HEIGHT; $row++) {
            $pixel = $bitmap.GetPixel($col, $row)
            $pixelData[$index++] = $pixel.R
            $pixelData[$index++] = $pixel.G
            $pixelData[$index++] = $pixel.B
        }
    }

    $bitmap.Dispose()
    return $pixelData
}

function Local-NewPacketChunk {
    param([byte[]]$PixelData)

    $PAYLOAD_SIZE = 56
    $BASE_ADDRESS = 0x389D

    $packets = [System.Collections.Generic.List[byte[]]]::new()
    $incrementing = 0
    $decrementing = $BASE_ADDRESS

    for ($offset = 0; $offset -lt $PixelData.Length; $offset += $PAYLOAD_SIZE) {
        $chunkSize = [Math]::Min($PAYLOAD_SIZE, $PixelData.Length - $offset)
        $packet = New-Object byte[] 64

        # Header (8 bytes)
        $packet[0] = 0x29                                    # Fixed header byte
        $packet[1] = 0x00                                    # Frame index
        $packet[2] = 0x01                                    # Image mode
        $packet[3] = 0x00                                    # Fixed
        $packet[4] = $incrementing -band 0xFF                # Incrementing LSB
        $packet[5] = ($incrementing -shr 8) -band 0xFF       # Incrementing MSB
        $packet[6] = ($decrementing -shr 8) -band 0xFF       # Decrementing MSB
        $packet[7] = $decrementing -band 0xFF                # Decrementing LSB

        # Pixel payload
        for ($i = 0; $i -lt $chunkSize; $i++) {
            $packet[8 + $i] = $PixelData[$offset + $i]
        }

        $packets.Add($packet)
        $incrementing++
        $decrementing--
    }

    return $packets.ToArray()
}

function Local-SendPackets {
    param([byte[][]]$Packets, $Stream)

    foreach ($packet in $Packets) {
        # Prepend report ID (0x00)
        $featureReport = New-Object byte[] 65
        $featureReport[0] = 0x00
        for ($i = 0; $i -lt 64; $i++) {
            $featureReport[$i + 1] = $packet[$i]
        }

        $Stream.SetFeature($featureReport)
        Start-Sleep -Milliseconds 5
    }
}

# ===== MAIN TEST =====

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

Write-Host "✓ Screen interface found`n" -ForegroundColor Green

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
    Write-Host "Sending initialization..." -ForegroundColor Cyan
    $initPacket = New-Object byte[] 65
    $initPacket[0] = 0x00
    for ($i = 0; $i -lt $FIRST_PACKET.Length; $i++) {
        $initPacket[$i + 1] = $FIRST_PACKET[$i]
    }
    $stream.SetFeature($initPacket)
    Start-Sleep -Milliseconds 10
    Write-Host "✓ Initialized`n" -ForegroundColor Green

    # ===== TEST 1: Direct Byte Array =====
    Write-Host "[Test 1] Full RED - Direct Byte Array (like proof-of-work)" -ForegroundColor Cyan
    Write-Host "Creating pixel data directly..." -ForegroundColor Gray

    $pixelDataDirect = New-Object byte[] (60 * 9 * 3)
    $index = 0
    for ($col = 0; $col -lt 60; $col++) {
        for ($row = 0; $row -lt 9; $row++) {
            $pixelDataDirect[$index++] = 0xFF  # R
            $pixelDataDirect[$index++] = 0x00  # G
            $pixelDataDirect[$index++] = 0x00  # B
        }
    }

    Write-Host "  Pixel data length: $($pixelDataDirect.Length) bytes" -ForegroundColor Gray
    Write-Host "  First 30 bytes: " -NoNewline -ForegroundColor Gray
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host ("{0:X2} " -f $pixelDataDirect[$i]) -NoNewline -ForegroundColor $(if ($pixelDataDirect[$i] -eq 0xFF) { 'Red' } else { 'Gray' })
    }
    Write-Host "`n"

    Write-Host ">>> WATCH DISPLAY - Should turn RED <<<" -ForegroundColor Magenta
    $packetsDirect = Local-NewPacketChunk -PixelData $pixelDataDirect
    Write-Host "Sending $($packetsDirect.Count) packets..." -ForegroundColor Gray
    Local-SendPackets -Packets $packetsDirect -Stream $stream
    Write-Host "✓ Sent" -ForegroundColor Green

    Start-Sleep -Seconds 3
    Write-Host "`nDid display turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    # ===== TEST 2: Bitmap Conversion =====
    Write-Host "`n[Test 2] Full RED - Using Bitmap Conversion" -ForegroundColor Cyan
    Write-Host "Creating bitmap..." -ForegroundColor Gray

    $bitmap = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 0, 0))
    $graphics.Dispose()

    Write-Host "Converting bitmap to pixel data..." -ForegroundColor Gray
    $pixelDataBitmap = Local-ConvertTo-PixelData -Image $bitmap
    $bitmap.Dispose()

    Write-Host "  Pixel data length: $($pixelDataBitmap.Length) bytes" -ForegroundColor Gray
    Write-Host "  First 30 bytes: " -NoNewline -ForegroundColor Gray
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host ("{0:X2} " -f $pixelDataBitmap[$i]) -NoNewline -ForegroundColor $(if ($pixelDataBitmap[$i] -eq 0xFF) { 'Red' } else { 'Gray' })
    }
    Write-Host "`n"

    # Compare pixel data
    Write-Host "Comparing pixel data..." -ForegroundColor Cyan
    $differences = 0
    $firstDiff = -1
    for ($i = 0; $i -lt 1620; $i++) {
        if ($pixelDataDirect[$i] -ne $pixelDataBitmap[$i]) {
            if ($firstDiff -eq -1) { $firstDiff = $i }
            $differences++
            if ($differences -le 5) {
                Write-Host "  Byte $i : Direct=0x$($pixelDataDirect[$i].ToString('X2')) vs Bitmap=0x$($pixelDataBitmap[$i].ToString('X2'))" -ForegroundColor Red
            }
        }
    }

    if ($differences -eq 0) {
        Write-Host "  ✓ Pixel data is IDENTICAL" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Found $differences differences (first at byte $firstDiff)" -ForegroundColor Red
    }

    Write-Host "`n>>> WATCH DISPLAY - Testing bitmap method <<<" -ForegroundColor Magenta
    $packetsBitmap = Local-NewPacketChunk -PixelData $pixelDataBitmap
    Write-Host "Sending $($packetsBitmap.Count) packets..." -ForegroundColor Gray
    Local-SendPackets -Packets $packetsBitmap -Stream $stream
    Write-Host "✓ Sent" -ForegroundColor Green

    Start-Sleep -Seconds 3
    Write-Host "`nDid display turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
    $response2 = Read-Host

    # ===== ANALYSIS =====
    Write-Host "`n========== RESULTS ==========" -ForegroundColor Cyan
    Write-Host "Direct byte array:  $response1" -ForegroundColor $(if ($response1 -eq 'y') { 'Green' } else { 'Red' })
    Write-Host "Bitmap conversion:  $response2" -ForegroundColor $(if ($response2 -eq 'y') { 'Green' } else { 'Red' })
    Write-Host "Pixel data match:   $(if ($differences -eq 0) { 'Yes' } else { "No ($differences diffs)" })" -ForegroundColor $(if ($differences -eq 0) { 'Green' } else { 'Red' })

    if ($response1 -eq 'y' -and $response2 -eq 'n') {
        Write-Host "`n⚠ CONCLUSION: Bitmap conversion creates bad pixel data" -ForegroundColor Yellow
        if ($differences -gt 0) {
            Write-Host "   Pixel data differs at $differences bytes" -ForegroundColor Yellow
        } else {
            Write-Host "   Pixel data identical but still doesn't work - issue in Send-DynaTabImage?" -ForegroundColor Yellow
        }
    } elseif ($response1 -eq 'y' -and $response2 -eq 'y') {
        Write-Host "`n✓ CONCLUSION: Both methods work!" -ForegroundColor Green
    } elseif ($response1 -eq 'n') {
        Write-Host "`n⚠ CONCLUSION: Even direct method failed - not a bitmap issue" -ForegroundColor Yellow
    }

    $stream.Close()

} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($stream) { $stream.Close() }
    throw
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
