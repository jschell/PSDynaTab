#Requires -Version 5.1

<#
.SYNOPSIS
    Tests if device needs reinitialization between sends
.DESCRIPTION
    Sends full red screen twice:
    - Test 1: Fresh connection
    - Test 2: After reinitializing (send init packet again)
    - Test 3: Without reinit (just send directly)
#>

Write-Host "`n=== Device Reinitialization Test ===" -ForegroundColor Cyan

# Load HidSharp
$hidSharpPath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
if (-not (Test-Path $hidSharpPath)) {
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $hidSharpPath = "$documentsPath\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
}

Add-Type -Path $hidSharpPath

# Find device
$devices = @([HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015))
$screenDevice = $null
foreach ($dev in $devices) {
    if ($dev.DevicePath -like "*mi_02*" -and $dev.GetMaxFeatureReportLength() -eq 65) {
        $screenDevice = $dev
        break
    }
}

if (-not $screenDevice) { throw "Device not found!" }

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

function Send-RedScreen {
    param($Stream, [string]$Color = "Red")

    # Create pixel data
    $pixelData = New-Object byte[] (60 * 9 * 3)
    $index = 0

    $r = if ($Color -eq "Red") { 0xFF } else { 0x00 }
    $g = if ($Color -eq "Green") { 0xFF } else { 0x00 }
    $b = if ($Color -eq "Blue") { 0xFF } else { 0x00 }

    for ($col = 0; $col -lt 60; $col++) {
        for ($row = 0; $row -lt 9; $row++) {
            $pixelData[$index++] = $r
            $pixelData[$index++] = $g
            $pixelData[$index++] = $b
        }
    }

    # Chunk and send
    $incrementing = 0
    $decrementing = 0x389D

    for ($offset = 0; $offset -lt $pixelData.Length; $offset += 56) {
        $chunkSize = [Math]::Min(56, $pixelData.Length - $offset)
        $packet = New-Object byte[] 65
        $packet[0] = 0x00
        $packet[1] = 0x29
        $packet[2] = 0x00
        $packet[3] = 0x01
        $packet[4] = 0x00
        $packet[5] = $incrementing -band 0xFF
        $packet[6] = ($incrementing -shr 8) -band 0xFF
        $packet[7] = ($decrementing -shr 8) -band 0xFF
        $packet[8] = $decrementing -band 0xFF

        for ($i = 0; $i -lt $chunkSize; $i++) {
            $packet[9 + $i] = $pixelData[$offset + $i]
        }

        $Stream.SetFeature($packet)
        $incrementing++
        $decrementing--
        Start-Sleep -Milliseconds 5
    }
}

function Send-Init {
    param($Stream)

    $initPacket = New-Object byte[] 65
    $initPacket[0] = 0x00
    for ($i = 0; $i -lt $FIRST_PACKET.Length; $i++) {
        $initPacket[$i + 1] = $FIRST_PACKET[$i]
    }
    $Stream.SetFeature($initPacket)
    Start-Sleep -Milliseconds 10
}

try {
    $stream = $screenDevice.Open()
    Write-Host "✓ Device opened`n" -ForegroundColor Green

    # ===== TEST 1: First send (fresh init) =====
    Write-Host "[Test 1] First RED send (fresh connection)" -ForegroundColor Cyan
    Send-Init -Stream $stream
    Write-Host ">>> WATCH DISPLAY - Should turn RED <<<" -ForegroundColor Magenta
    Send-RedScreen -Stream $stream -Color "Red"
    Start-Sleep -Seconds 3
    Write-Host "Did display turn RED? (y/n): " -NoNewline -ForegroundColor Yellow
    $response1 = Read-Host

    # ===== TEST 2: Second send WITHOUT reinit =====
    Write-Host "`n[Test 2] GREEN send WITHOUT reinit" -ForegroundColor Cyan
    Write-Host ">>> WATCH DISPLAY - Should turn GREEN <<<" -ForegroundColor Magenta
    Send-RedScreen -Stream $stream -Color "Green"
    Start-Sleep -Seconds 3
    Write-Host "Did display turn GREEN? (y/n): " -NoNewline -ForegroundColor Yellow
    $response2 = Read-Host

    # ===== TEST 3: Third send WITH reinit =====
    Write-Host "`n[Test 3] BLUE send WITH reinit" -ForegroundColor Cyan
    Write-Host "Sending init packet again..." -ForegroundColor Gray
    Send-Init -Stream $stream
    Write-Host ">>> WATCH DISPLAY - Should turn BLUE <<<" -ForegroundColor Magenta
    Send-RedScreen -Stream $stream -Color "Blue"
    Start-Sleep -Seconds 3
    Write-Host "Did display turn BLUE? (y/n): " -NoNewline -ForegroundColor Yellow
    $response3 = Read-Host

    $stream.Close()

    # ===== RESULTS =====
    Write-Host "`n========== RESULTS ==========" -ForegroundColor Cyan
    Write-Host "Test 1 (RED, fresh init):    $response1" -ForegroundColor $(if ($response1 -eq 'y') { 'Green' } else { 'Red' })
    Write-Host "Test 2 (GREEN, no reinit):   $response2" -ForegroundColor $(if ($response2 -eq 'y') { 'Green' } else { 'Red' })
    Write-Host "Test 3 (BLUE, with reinit):  $response3" -ForegroundColor $(if ($response3 -eq 'y') { 'Green' } else { 'Red' })

    if ($response1 -eq 'y' -and $response2 -eq 'n' -and $response3 -eq 'y') {
        Write-Host "`n✓✓✓ CONFIRMED: Device needs REINIT between sends!" -ForegroundColor Green
        Write-Host "Solution: Send init packet before each image" -ForegroundColor Yellow
    } elseif ($response1 -eq 'y' -and $response2 -eq 'y') {
        Write-Host "`n✓ Multiple sends work without reinit" -ForegroundColor Green
        Write-Host "Issue must be elsewhere" -ForegroundColor Yellow
    } else {
        Write-Host "`nUnexpected results - further investigation needed" -ForegroundColor Yellow
    }

} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($stream) { $stream.Close() }
    throw
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
