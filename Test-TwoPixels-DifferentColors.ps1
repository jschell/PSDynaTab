<#
.SYNOPSIS
    Test sequential 2-pixel images with different colors

.DESCRIPTION
    Sends 2-pixel images in sequence with different colors.
    Tests different addresses to find which one works for 2 pixels.

    Known: 1 pixel uses address 0x03D2
    Testing: What address works for 2 pixels?

.EXAMPLE
    .\Test-TwoPixels-DifferentColors.ps1
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

function Send-TwoPixels {
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
        [byte]$Blue,
        [Parameter(Mandatory)]
        [uint16]$Address
    )

    Write-Host "Sending 2 $ColorName pixels with address 0x$($Address.ToString('X4'))..." -ForegroundColor Yellow

    # Init packet for 2 pixels (2×1 region)
    $initPacket = New-Object byte[] 64
    $initPacket[0] = 0xa9
    $initPacket[1] = 0x00
    $initPacket[2] = 0x01  # 1 frame
    $initPacket[3] = 0x00  # 0ms delay
    $initPacket[4] = 0x06  # 6 bytes (2 pixels * 3)
    $initPacket[5] = 0x00
    $initPacket[6] = 0x00
    $initPacket[7] = Calculate-Checksum $initPacket
    $initPacket[8] = 0x00   # X-start = 0
    $initPacket[9] = 0x00   # Y-start = 0
    $initPacket[10] = 0x02  # X-end = 2 (2 pixels wide)
    $initPacket[11] = 0x01  # Y-end = 1 (1 pixel tall)

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

    # Data packet with specified address
    $dataPacket = New-Object byte[] 64
    $dataPacket[0] = 0x29
    $dataPacket[1] = 0x00  # Frame index
    $dataPacket[2] = 0x01  # Frame count
    $dataPacket[3] = 0x00  # Delay
    $dataPacket[4] = 0x00  # Counter low
    $dataPacket[5] = 0x00  # Counter high
    $dataPacket[6] = [byte](($Address -shr 8) -band 0xFF)  # Address high
    $dataPacket[7] = [byte]($Address -band 0xFF)           # Address low
    # First pixel
    $dataPacket[8] = $Red
    $dataPacket[9] = $Green
    $dataPacket[10] = $Blue
    # Second pixel (same color)
    $dataPacket[11] = $Red
    $dataPacket[12] = $Green
    $dataPacket[13] = $Blue

    $featureReport = New-Object byte[] 65
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $dataPacket[$i]
    }

    $HidStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    Write-Host "  ✓ Data sent" -ForegroundColor Gray
}

Write-Host "=== Test: 2 Pixels, Different Colors, Finding Address ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Known: 1 pixel uses address 0x03D2" -ForegroundColor White
Write-Host "Testing: Different addresses to find which works for 2 pixels" -ForegroundColor White
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

# Test different address hypotheses
$testCases = @(
    @{ Name = "Same as 1px (0x03D2)"; Addr = 0x03D2; Color = "RED"; R = 0xFF; G = 0x00; B = 0x00 }
    @{ Name = "0x03D2 - 1"; Addr = 0x03D1; Color = "GREEN"; R = 0x00; G = 0xFF; B = 0x00 }
    @{ Name = "0x03D2 - 2"; Addr = 0x03D0; Color = "BLUE"; R = 0x00; G = 0x00; B = 0xFF }
    @{ Name = "0x03D2 - 3"; Addr = 0x03CF; Color = "YELLOW"; R = 0xFF; G = 0xFF; B = 0x00 }
    @{ Name = "0x03D2 - 6 (2px*3)"; Addr = 0x03CC; Color = "CYAN"; R = 0x00; G = 0xFF; B = 0xFF }
    @{ Name = "0x03D2 + 1"; Addr = 0x03D3; Color = "MAGENTA"; R = 0xFF; G = 0x00; B = 0xFF }
)

$results = @()

foreach ($test in $testCases) {
    Write-Host "Test: $($test.Name) - 2 $($test.Color) pixels" -ForegroundColor Cyan
    Send-TwoPixels -HidStream $hidStream `
        -ColorName $test.Color `
        -Red $test.R -Green $test.G -Blue $test.B `
        -Address $test.Addr

    Start-Sleep -Milliseconds 500
    $result = Read-Host "Did you see 2 $($test.Color) pixels in top-left? (Y/N)"

    $results += [PSCustomObject]@{
        Address = "0x{0:X4}" -f $test.Addr
        AddressDecimal = $test.Addr
        Formula = $test.Name
        Color = $test.Color
        Worked = $result
    }

    if ($result -eq 'Y') {
        Write-Host "  ✓✓✓ SUCCESS! Address 0x$($test.Addr.ToString('X4')) works for 2 pixels!" -ForegroundColor Green
    }

    Write-Host ""
}

$hidStream.Close()

Write-Host "=== Results Summary ===" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table Address, AddressDecimal, Formula, Color, Worked -AutoSize

Write-Host ""
$working = $results | Where-Object { $_.Worked -eq 'Y' }
if ($working) {
    Write-Host "✓ Working addresses for 2 pixels:" -ForegroundColor Green
    $working | ForEach-Object {
        Write-Host "  $($_.Address) ($($_.AddressDecimal)) - $($_.Formula)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "=== Pattern Analysis ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1 pixel:  0x03D2 (978)" -ForegroundColor White
    Write-Host "2 pixels: $($working[0].Address) ($($working[0].AddressDecimal))" -ForegroundColor White

    $diff = 978 - $working[0].AddressDecimal
    Write-Host "Difference: $diff decimal" -ForegroundColor Yellow

    if ($diff -eq 1) {
        Write-Host "Pattern: Address = 0x03D2 - (pixel_count - 1)" -ForegroundColor Green
    } elseif ($diff -eq 2) {
        Write-Host "Pattern: Address = 0x03D2 - pixel_count" -ForegroundColor Green
    } elseif ($diff -eq 3) {
        Write-Host "Pattern: Address = 0x03D2 - (pixel_count + 1)" -ForegroundColor Green
    } elseif ($diff -eq 6) {
        Write-Host "Pattern: Address = 0x03D2 - (pixel_count * 3)" -ForegroundColor Green
    } else {
        Write-Host "Pattern: Unknown (diff = $diff)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ No address worked for 2 pixels!" -ForegroundColor Red
    Write-Host "Need to test more addresses or check other parameters." -ForegroundColor Yellow
}

Write-Host ""
