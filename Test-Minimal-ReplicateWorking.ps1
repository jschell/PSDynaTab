<#
.SYNOPSIS
    Minimal test - exactly replicates working 1-pixel green capture

.DESCRIPTION
    Sends the EXACT packets from the working capture:
    usbPcap/2026-01-17-picture-topLeft-1pixel-00-ff-00.json

    This is known to work. If this fails, we have a device communication issue.
    If this works, our test scripts have a packet construction error.

.EXAMPLE
    .\Test-Minimal-ReplicateWorking.ps1
#>

# Load HidSharp
$hidSharpPath = Join-Path $PSScriptRoot "PSDynaTab\lib\HidSharp.dll"
if (-not (Test-Path $hidSharpPath)) {
    Write-Error "HidSharp.dll not found at: $hidSharpPath"
    exit 1
}
Add-Type -Path $hidSharpPath

$DEVICE_VID = 0x3151
$DEVICE_PID = 0x4015
$INTERFACE_INDEX = 3

Write-Host "=== Minimal Test: Replicate Known Working Capture ===" -ForegroundColor Cyan
Write-Host ""

# Connect to device
$deviceList = [HidSharp.DeviceList]::Local
$devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
$targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

if (-not $targetDevice) {
    Write-Error "Device not found!"
    exit 1
}

$hidStream = $targetDevice.Open()
Write-Host "✓ Device connected" -ForegroundColor Green
Write-Host ""

# EXACT init packet from working capture:
# a9 00 01 00 03 00 00 52 00 00 01 01 00 00 00...
Write-Host "Sending init packet (EXACT from working capture):" -ForegroundColor Yellow
$initPacket = @(
    0xa9, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x52,
    0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $initPacket[$i]
}

Write-Host "  Packet: $($initPacket[0..11] | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')" -ForegroundColor Gray
try {
    $hidStream.SetFeature($featureReport)
    Write-Host "  ✓ Init packet sent" -ForegroundColor Green
} catch {
    Write-Error "Failed to send init packet: $_"
    $hidStream.Close()
    exit 1
}

Start-Sleep -Milliseconds 5

# Get_Report handshake
Write-Host ""
Write-Host "Sending Get_Report handshake:" -ForegroundColor Yellow
try {
    $response = New-Object byte[] 65
    $hidStream.GetFeature($response)
    Write-Host "  ✓ Handshake successful" -ForegroundColor Green
    Write-Host "  Response: $($response[1..16] | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')" -ForegroundColor Gray
} catch {
    Write-Warning "Get_Report failed: $_"
}

Start-Sleep -Milliseconds 5

# EXACT data packet from working capture:
# 29 00 01 00 00 00 03 d2 00 ff 00 00 00 00...
Write-Host ""
Write-Host "Sending data packet (EXACT from working capture):" -ForegroundColor Yellow
$dataPacket = @(
    0x29, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0xd2,
    0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $dataPacket[$i]
}

Write-Host "  Packet: $($dataPacket[0..15] | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')" -ForegroundColor Gray
try {
    $hidStream.SetFeature($featureReport)
    Write-Host "  ✓ Data packet sent" -ForegroundColor Green
} catch {
    Write-Error "Failed to send data packet: $_"
    $hidStream.Close()
    exit 1
}

Start-Sleep -Milliseconds 5

$hidStream.Close()

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "EXPECTED: One green pixel at top-left corner" -ForegroundColor Yellow
Write-Host ""
$result = Read-Host "Did you see a GREEN pixel at top-left? (Y/N)"

if ($result -eq 'Y') {
    Write-Host ""
    Write-Host "✓ SUCCESS! Replicating exact capture works." -ForegroundColor Green
    Write-Host "This means our test scripts have packet construction errors." -ForegroundColor Yellow
    Write-Host "We need to compare our generated packets vs this working packet." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "✗ FAILED! Even exact packet replication doesn't work." -ForegroundColor Red
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  1. Wrong device interface (check INTERFACE_INDEX)" -ForegroundColor White
    Write-Host "  2. Device in wrong mode" -ForegroundColor White
    Write-Host "  3. Permissions issue" -ForegroundColor White
    Write-Host "  4. Device firmware difference" -ForegroundColor White
    Write-Host ""
    Write-Host "What DID you see?" -ForegroundColor Yellow
    $observation = Read-Host "  "
    Write-Host "  Observation: $observation" -ForegroundColor Gray
}

Write-Host ""
