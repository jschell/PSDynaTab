<#
.SYNOPSIS
    Test using Python library's exact method - FULL DISPLAY ONLY

.DESCRIPTION
    The Python library ALWAYS sends full display (60×9 = 540 pixels).
    It does NOT use partial bounding boxes.

    This test replicates the Python library's exact approach:
    1. Send FIRST_PACKET (hardcoded for full display)
    2. Get_Report handshake
    3. Send 30 data packets (540 pixels / 18 per packet)
    4. Use Python library's exact addresses and overrides

.EXAMPLE
    .\Test-PythonLibMethod-FullDisplay.ps1
#>

# Load HidSharp
$hidSharpPath = Join-Path $PSScriptRoot "PSDynaTab\lib\HidSharp.dll"
if (-not (Test-Path $hidSharpPath)) {
    Write-Error "HidSharp.dll not found"
    exit 1
}
Add-Type -Path $hidSharpPath

$DEVICE_VID = 0x3151
$DEVICE_PID = 0x4015
$INTERFACE_INDEX = 3

Write-Host "=== Python Library Method: Full Display Green ===" -ForegroundColor Cyan
Write-Host ""

# Connect
$deviceList = [HidSharp.DeviceList]::Local
$devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
$targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

if (-not $targetDevice) {
    Write-Error "Device not found"
    exit 1
}

$hidStream = $targetDevice.Open()
Write-Host "✓ Device connected" -ForegroundColor Green

# Python library's FIRST_PACKET (EXACT)
Write-Host "Sending Python library FIRST_PACKET (full display 60×9)..." -ForegroundColor Yellow

$firstPacket = @(
    0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
    0x00, 0x00, 0x3c, 0x09
) + @(0x00) * 52

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $firstPacket[$i]
}

$hidStream.SetFeature($featureReport)
Write-Host "  ✓ Init packet sent" -ForegroundColor Green
Start-Sleep -Milliseconds 5

# Get_Report handshake
Write-Host "Get_Report handshake..." -ForegroundColor Yellow
try {
    $response = New-Object byte[] 65
    $hidStream.GetFeature($response)
    Write-Host "  ✓ Handshake OK" -ForegroundColor Green
} catch {
    Write-Warning "Handshake failed: $_"
}
Start-Sleep -Milliseconds 5

# Send 30 data packets (540 pixels / 18 per packet)
Write-Host "Sending 30 data packets (full green display)..." -ForegroundColor Yellow

$baseAddress = 0x389D
for ($pktIdx = 0; $pktIdx -lt 30; $pktIdx++) {
    $packet = New-Object byte[] 64
    $packet[0] = 0x29
    $packet[1] = 0x00  # Frame index
    $packet[2] = 0x01  # Frame count
    $packet[3] = 0x00  # Delay

    # Incrementing counter (little-endian)
    $packet[4] = [byte]($pktIdx -band 0xFF)
    $packet[5] = [byte](($pktIdx -shr 8) -band 0xFF)

    # Decrementing address (big-endian)
    $address = $baseAddress - $pktIdx
    $packet[6] = [byte](($address -shr 8) -band 0xFF)
    $packet[7] = [byte]($address -band 0xFF)

    # Fill with 18 green pixels
    for ($p = 0; $p -lt 18; $p++) {
        $offset = 8 + ($p * 3)
        $packet[$offset] = 0x00      # R
        $packet[$offset + 1] = 0xFF  # G
        $packet[$offset + 2] = 0x00  # B
    }

    # Last packet override (Python library)
    if ($pktIdx -eq 29) {
        $packet[6] = 0x34
        $packet[7] = 0x85
    }

    $featureReport = New-Object byte[] 65
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $packet[$i]
    }

    $hidStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    if (($pktIdx + 1) % 10 -eq 0) {
        Write-Host "  Sent $($pktIdx + 1)/30 packets..." -ForegroundColor Gray
    }
}

$hidStream.Close()

Write-Host ""
Write-Host "✓ Complete! Sent 31 packets total (1 init + 30 data)" -ForegroundColor Green
Write-Host ""
Write-Host "EXPECTED: Full display should be GREEN" -ForegroundColor Yellow
Write-Host ""

$result = Read-Host "Did you see full GREEN display? (Y/N)"

if ($result -eq 'Y') {
    Write-Host ""
    Write-Host "✓✓✓ SUCCESS! Python library method works!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This means:" -ForegroundColor Yellow
    Write-Host "  1. Our protocol implementation is CORRECT" -ForegroundColor White
    Write-Host "  2. Device REQUIRES full display init packet" -ForegroundColor White
    Write-Host "  3. Partial bounding boxes may not be supported" -ForegroundColor White
    Write-Host "  4. Python library approach is the way to go" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "✗ FAILED - Something else is wrong" -ForegroundColor Red
    Write-Host ""
    $observation = Read-Host "What did you see?"
    Write-Host "  Observation: $observation" -ForegroundColor Gray
}

Write-Host ""
