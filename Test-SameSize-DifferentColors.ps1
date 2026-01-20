<#
.SYNOPSIS
    Test sequential images with same pixel count, different colors

.DESCRIPTION
    Sends three 1-pixel images in sequence:
    - Red pixel
    - Green pixel
    - Blue pixel

    All use the same address (0x03D2) and same bounding box (1×1).
    This tests if we can send multiple images without device issues.

.EXAMPLE
    .\Test-SameSize-DifferentColors.ps1
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

function Send-OnePixel {
    param(
        [Parameter(Mandatory)]
        $HidStream,
        [Parameter(Mandatory)]
        [string]$ColorName,
        [Parameter(Mandatory)]
        [byte]$Red,
        [Parameter(Mandatory)]
        [byte]$Green,
        [Parameter(Mandatory)]
        [byte]$Blue
    )

    Write-Host "Sending 1 $ColorName pixel..." -ForegroundColor Yellow

    # Init packet for 1 pixel
    $initPacket = New-Object byte[] 64
    $initPacket[0] = 0xa9
    $initPacket[1] = 0x00
    $initPacket[2] = 0x01  # 1 frame
    $initPacket[3] = 0x00  # 0ms delay
    $initPacket[4] = 0x03  # 3 bytes (1 pixel)
    $initPacket[5] = 0x00
    $initPacket[6] = 0x00
    $initPacket[7] = Calculate-Checksum $initPacket
    $initPacket[8] = 0x00   # X-start = 0
    $initPacket[9] = 0x00   # Y-start = 0
    $initPacket[10] = 0x01  # X-end = 1
    $initPacket[11] = 0x01  # Y-end = 1

    $featureReport = New-Object byte[] 65
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $initPacket[$i]
    }

    $HidStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    # Get_Report handshake
    try {
        $response = New-Object byte[] 65
        $HidStream.GetFeature($response)
        Write-Host "  ✓ Init sent, handshake OK" -ForegroundColor Gray
    } catch {
        Write-Warning "  Handshake failed"
    }
    Start-Sleep -Milliseconds 5

    # Data packet with address 0x03D2
    $dataPacket = New-Object byte[] 64
    $dataPacket[0] = 0x29
    $dataPacket[1] = 0x00  # Frame index
    $dataPacket[2] = 0x01  # Frame count
    $dataPacket[3] = 0x00  # Delay
    $dataPacket[4] = 0x00  # Counter low
    $dataPacket[5] = 0x00  # Counter high
    $dataPacket[6] = 0x03  # Address high
    $dataPacket[7] = 0xD2  # Address low (working address)
    $dataPacket[8] = $Red
    $dataPacket[9] = $Green
    $dataPacket[10] = $Blue

    $featureReport = New-Object byte[] 65
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $dataPacket[$i]
    }

    $HidStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    Write-Host "  ✓ Data sent with address 0x03D2" -ForegroundColor Gray
}

Write-Host "=== Test: Same Size (1 pixel), Different Colors ===" -ForegroundColor Cyan
Write-Host ""

# Connect once
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

# Test 1: RED pixel
Write-Host "Test 1: RED pixel" -ForegroundColor Cyan
Send-OnePixel -HidStream $hidStream -ColorName "RED" -Red 0xFF -Green 0x00 -Blue 0x00
Start-Sleep -Milliseconds 500
$result1 = Read-Host "Did you see RED pixel? (Y/N)"

Write-Host ""

# Test 2: GREEN pixel (same size, different color)
Write-Host "Test 2: GREEN pixel (same size as test 1)" -ForegroundColor Cyan
Send-OnePixel -HidStream $hidStream -ColorName "GREEN" -Red 0x00 -Green 0xFF -Blue 0x00
Start-Sleep -Milliseconds 500
$result2 = Read-Host "Did you see GREEN pixel? (Y/N)"

Write-Host ""

# Test 3: BLUE pixel (same size, different color)
Write-Host "Test 3: BLUE pixel (same size as test 1 & 2)" -ForegroundColor Cyan
Send-OnePixel -HidStream $hidStream -ColorName "BLUE" -Red 0x00 -Green 0x00 -Blue 0xFF
Start-Sleep -Milliseconds 500
$result3 = Read-Host "Did you see BLUE pixel? (Y/N)"

Write-Host ""

# Test 4: YELLOW pixel (R+G)
Write-Host "Test 4: YELLOW pixel (same size)" -ForegroundColor Cyan
Send-OnePixel -HidStream $hidStream -ColorName "YELLOW" -Red 0xFF -Green 0xFF -Blue 0x00
Start-Sleep -Milliseconds 500
$result4 = Read-Host "Did you see YELLOW pixel? (Y/N)"

$hidStream.Close()

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test 1 (RED):    $result1" -ForegroundColor $(if ($result1 -eq 'Y') { 'Green' } else { 'Red' })
Write-Host "Test 2 (GREEN):  $result2" -ForegroundColor $(if ($result2 -eq 'Y') { 'Green' } else { 'Red' })
Write-Host "Test 3 (BLUE):   $result3" -ForegroundColor $(if ($result3 -eq 'Y') { 'Green' } else { 'Red' })
Write-Host "Test 4 (YELLOW): $result4" -ForegroundColor $(if ($result4 -eq 'Y') { 'Green' } else { 'Red' })
Write-Host ""

if ($result1 -eq 'Y' -and $result2 -eq 'Y' -and $result3 -eq 'Y' -and $result4 -eq 'Y') {
    Write-Host "✓✓✓ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This confirms:" -ForegroundColor Yellow
    Write-Host "  1. Address 0x03D2 is CORRECT for 1 pixel" -ForegroundColor White
    Write-Host "  2. Device accepts multiple sequential images" -ForegroundColor White
    Write-Host "  3. No device reset needed between images" -ForegroundColor White
    Write-Host "  4. Different address needed for different pixel counts" -ForegroundColor White
    Write-Host ""
    Write-Host "Next step: Run Extract-Addresses-From-Captures.ps1" -ForegroundColor Yellow
    Write-Host "to find the address formula for different pixel counts." -ForegroundColor Yellow
} else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    Write-Host ""
    if ($result1 -eq 'Y' -and $result2 -ne 'Y') {
        Write-Host "First test worked but second failed - device state issue!" -ForegroundColor Yellow
    } elseif ($result1 -ne 'Y') {
        Write-Host "Even first test failed - something's wrong!" -ForegroundColor Yellow
    }
}

Write-Host ""
