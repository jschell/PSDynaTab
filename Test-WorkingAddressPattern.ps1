<#
.SYNOPSIS
    Test with working capture's exact address pattern

.DESCRIPTION
    Now that we know exact packet replication works, this test uses
    the working capture's address (0x03D2) instead of Python library's
    addresses (0x389D / 0x3485).

    Goal: Verify if address is the ONLY difference.

.EXAMPLE
    .\Test-WorkingAddressPattern.ps1
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

function Calculate-Checksum {
    param([byte[]]$Packet)
    $sum = 0
    for ($i = 0; $i -lt 7; $i++) {
        $sum += $Packet[$i]
    }
    return [byte]((0xFF - ($sum -band 0xFF)) -band 0xFF)
}

Write-Host "=== Test: Working Address Pattern ===" -ForegroundColor Cyan
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
Write-Host ""

# Test 1: One red pixel using working address pattern
Write-Host "Test 1: One RED pixel at (0,0) using address 0x03D2" -ForegroundColor Yellow

$initPacket = New-Object byte[] 64
$initPacket[0] = 0xa9
$initPacket[1] = 0x00
$initPacket[2] = 0x01
$initPacket[3] = 0x00
$initPacket[4] = 0x03  # 1 pixel = 3 bytes
$initPacket[5] = 0x00
$initPacket[6] = 0x00
$initPacket[7] = Calculate-Checksum $initPacket
$initPacket[8] = 0x00   # X-start
$initPacket[9] = 0x00   # Y-start
$initPacket[10] = 0x01  # X-end
$initPacket[11] = 0x01  # Y-end

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $initPacket[$i]
}

$hidStream.SetFeature($featureReport)
Start-Sleep -Milliseconds 5

# Handshake
try {
    $response = New-Object byte[] 65
    $hidStream.GetFeature($response)
} catch {
    Write-Warning "Handshake failed"
}
Start-Sleep -Milliseconds 5

# Data packet with working address 0x03D2
$dataPacket = New-Object byte[] 64
$dataPacket[0] = 0x29
$dataPacket[1] = 0x00  # Frame index
$dataPacket[2] = 0x01  # Frame count
$dataPacket[3] = 0x00  # Delay
$dataPacket[4] = 0x00  # Counter low
$dataPacket[5] = 0x00  # Counter high
$dataPacket[6] = 0x03  # Address high (from working capture)
$dataPacket[7] = 0xD2  # Address low (from working capture)
$dataPacket[8] = 0xFF  # Red pixel R
$dataPacket[9] = 0x00  # Red pixel G
$dataPacket[10] = 0x00 # Red pixel B

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $dataPacket[$i]
}

$hidStream.SetFeature($featureReport)
Start-Sleep -Milliseconds 5

Write-Host "  ✓ Sent with address 0x03D2" -ForegroundColor Green
$result = Read-Host "Did you see RED pixel? (Y/N)"

if ($result -eq 'Y') {
    Write-Host "  ✓ Works with 0x03D2!" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed even with working address" -ForegroundColor Red
}

Write-Host ""

# Test 2: Try 10 pixels in top row
Write-Host "Test 2: 10 RED pixels in top row using working address pattern" -ForegroundColor Yellow

$initPacket[4] = 0x1E  # 30 bytes (10 pixels * 3)
$initPacket[5] = 0x00
$initPacket[7] = Calculate-Checksum $initPacket
$initPacket[10] = 0x0A  # X-end = 10

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $initPacket[$i]
}

$hidStream.SetFeature($featureReport)
Start-Sleep -Milliseconds 5

try {
    $response = New-Object byte[] 65
    $hidStream.GetFeature($response)
} catch { }
Start-Sleep -Milliseconds 5

# Send 10 red pixels (fits in one packet)
$dataPacket[6] = 0x03
$dataPacket[7] = 0xD2

for ($p = 0; $p -lt 10; $p++) {
    $offset = 8 + ($p * 3)
    $dataPacket[$offset] = 0xFF      # R
    $dataPacket[$offset + 1] = 0x00  # G
    $dataPacket[$offset + 2] = 0x00  # B
}

$featureReport = New-Object byte[] 65
for ($i = 0; $i -lt 64; $i++) {
    $featureReport[$i + 1] = $dataPacket[$i]
}

$hidStream.SetFeature($featureReport)
Start-Sleep -Milliseconds 5

Write-Host "  ✓ Sent with address 0x03D2" -ForegroundColor Green
$result = Read-Host "Did you see 10 RED pixels across top row? (Y/N)"

if ($result -eq 'Y') {
    Write-Host "  ✓ Works with 0x03D2!" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed" -ForegroundColor Red
}

$hidStream.Close()

Write-Host ""
Write-Host "=== Analysis ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Working address: 0x03D2 (978 decimal)" -ForegroundColor Yellow
Write-Host "Python library base: 0x389D (14493 decimal)" -ForegroundColor White
Write-Host "Python library override: 0x3485 (13445 decimal)" -ForegroundColor White
Write-Host ""
Write-Host "The working captures use a COMPLETELY DIFFERENT address!" -ForegroundColor Red
Write-Host "This is the Epomaker official software protocol, not Python library." -ForegroundColor Yellow
Write-Host ""
