<#
.SYNOPSIS
    Systematically find the address formula for different pixel counts

.DESCRIPTION
    Tests multiple pixel counts (1, 2, 3, 4, 5, 10) with calculated addresses
    based on common formulas to find the pattern.

    Known: 1 pixel = 0x03D2 (978 decimal)

    Testing formulas:
    - Formula A: 0x03D2 - pixel_count
    - Formula B: 0x03D2 - (pixel_count - 1)
    - Formula C: 0x03D2 - (pixel_count * 3)

.EXAMPLE
    .\Test-FindAddressFormula.ps1
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

function Send-PixelTest {
    param(
        [Parameter(Mandatory)]
        $HidStream,
        [Parameter(Mandatory)]
        [int]$PixelCount,
        [Parameter(Mandatory)]
        [uint16]$Address,
        [Parameter(Mandatory)]
        [string]$Formula,
        [Parameter(Mandatory)]
        [byte]$Red,
        [Parameter(Mandatory)]
        [byte]$Green,
        [Parameter(Mandatory)]
        [byte]$Blue
    )

    # Init packet
    $initPacket = New-Object byte[] 64
    $initPacket[0] = 0xa9
    $initPacket[1] = 0x00
    $initPacket[2] = 0x01  # 1 frame
    $initPacket[3] = 0x00  # 0ms delay

    $dataBytes = $PixelCount * 3
    $initPacket[4] = [byte]($dataBytes -band 0xFF)
    $initPacket[5] = [byte](($dataBytes -shr 8) -band 0xFF)

    $initPacket[6] = 0x00
    $initPacket[7] = Calculate-Checksum $initPacket
    $initPacket[8] = 0x00   # X-start = 0
    $initPacket[9] = 0x00   # Y-start = 0
    $initPacket[10] = [byte]$PixelCount  # X-end = pixel_count (horizontal line)
    $initPacket[11] = 0x01  # Y-end = 1 (1 row)

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
    } catch { }
    Start-Sleep -Milliseconds 5

    # Data packet
    $dataPacket = New-Object byte[] 64
    $dataPacket[0] = 0x29
    $dataPacket[1] = 0x00  # Frame index
    $dataPacket[2] = 0x01  # Frame count
    $dataPacket[3] = 0x00  # Delay
    $dataPacket[4] = 0x00  # Counter low
    $dataPacket[5] = 0x00  # Counter high
    $dataPacket[6] = [byte](($Address -shr 8) -band 0xFF)  # Address high
    $dataPacket[7] = [byte]($Address -band 0xFF)           # Address low

    # Fill pixels (up to 18)
    $pixelsToSend = [Math]::Min($PixelCount, 18)
    for ($p = 0; $p -lt $pixelsToSend; $p++) {
        $offset = 8 + ($p * 3)
        $dataPacket[$offset] = $Red
        $dataPacket[$offset + 1] = $Green
        $dataPacket[$offset + 2] = $Blue
    }

    $featureReport = New-Object byte[] 65
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $dataPacket[$i]
    }

    $HidStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    Write-Host ("  {0} pixels, addr 0x{1:X4} ({2})" -f $PixelCount, $Address, $Formula) -ForegroundColor Gray
}

Write-Host "=== Finding Address Formula ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing pixel counts: 1, 2, 3, 4, 5, 10" -ForegroundColor White
Write-Host "Testing formulas for each count" -ForegroundColor White
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

$testResults = @()
$colors = @(
    @{Name="Red"; R=0xFF; G=0x00; B=0x00}
    @{Name="Green"; R=0x00; G=0xFF; B=0x00}
    @{Name="Blue"; R=0x00; G=0x00; B=0xFF}
    @{Name="Yellow"; R=0xFF; G=0xFF; B=0x00}
    @{Name="Cyan"; R=0x00; G=0xFF; B=0xFF}
    @{Name="Magenta"; R=0xFF; G=0x00; B=0xFF}
    @{Name="White"; R=0xFF; G=0xFF; B=0xFF}
)

$pixelCounts = @(2, 3, 4, 5, 10)
$baseAddr = 0x03D2

$colorIdx = 0

foreach ($px in $pixelCounts) {
    Write-Host "Testing $px pixels:" -ForegroundColor Cyan

    # Calculate addresses using different formulas
    $addrA = $baseAddr - $px
    $addrB = $baseAddr - ($px - 1)
    $addrC = $baseAddr - ($px * 3)

    # Test Formula A: 0x03D2 - pixel_count
    $color = $colors[$colorIdx++ % $colors.Count]
    Write-Host "  Formula A (0x03D2 - $px = 0x$($addrA.ToString('X4')))" -ForegroundColor Yellow
    Send-PixelTest -HidStream $hidStream -PixelCount $px -Address $addrA `
        -Formula "A" -Red $color.R -Green $color.G -Blue $color.B
    Start-Sleep -Milliseconds 300

    $result = Read-Host "  Did you see $px $($color.Name) pixels? (Y/N/S=skip)"

    if ($result -eq 'S') {
        Write-Host "  Skipping remaining formulas for $px pixels" -ForegroundColor Gray
        Write-Host ""
        continue
    }

    if ($result -eq 'Y') {
        $testResults += [PSCustomObject]@{
            Pixels = $px
            Address = "0x{0:X4}" -f $addrA
            AddressDecimal = $addrA
            Formula = "0x03D2 - pixel_count"
            Worked = "YES"
        }
        Write-Host "  ✓✓✓ Formula A works for $px pixels!" -ForegroundColor Green
        Write-Host ""
        continue
    }

    # Test Formula B: 0x03D2 - (pixel_count - 1)
    $color = $colors[$colorIdx++ % $colors.Count]
    Write-Host "  Formula B (0x03D2 - ($px - 1) = 0x$($addrB.ToString('X4')))" -ForegroundColor Yellow
    Send-PixelTest -HidStream $hidStream -PixelCount $px -Address $addrB `
        -Formula "B" -Red $color.R -Green $color.G -Blue $color.B
    Start-Sleep -Milliseconds 300

    $result = Read-Host "  Did you see $px $($color.Name) pixels? (Y/N/S=skip)"

    if ($result -eq 'S') {
        Write-Host "  Skipping formula C for $px pixels" -ForegroundColor Gray
        Write-Host ""
        continue
    }

    if ($result -eq 'Y') {
        $testResults += [PSCustomObject]@{
            Pixels = $px
            Address = "0x{0:X4}" -f $addrB
            AddressDecimal = $addrB
            Formula = "0x03D2 - (pixel_count - 1)"
            Worked = "YES"
        }
        Write-Host "  ✓✓✓ Formula B works for $px pixels!" -ForegroundColor Green
        Write-Host ""
        continue
    }

    # Test Formula C: 0x03D2 - (pixel_count * 3)
    if ($px * 3 -lt 1000) {  # Don't test if it would underflow
        $color = $colors[$colorIdx++ % $colors.Count]
        Write-Host "  Formula C (0x03D2 - ($px * 3) = 0x$($addrC.ToString('X4')))" -ForegroundColor Yellow
        Send-PixelTest -HidStream $hidStream -PixelCount $px -Address $addrC `
            -Formula "C" -Red $color.R -Green $color.G -Blue $color.B
        Start-Sleep -Milliseconds 300

        $result = Read-Host "  Did you see $px $($color.Name) pixels? (Y/N)"

        if ($result -eq 'Y') {
            $testResults += [PSCustomObject]@{
                Pixels = $px
                Address = "0x{0:X4}" -f $addrC
                AddressDecimal = $addrC
                Formula = "0x03D2 - (pixel_count * 3)"
                Worked = "YES"
            }
            Write-Host "  ✓✓✓ Formula C works for $px pixels!" -ForegroundColor Green
        } else {
            $testResults += [PSCustomObject]@{
                Pixels = $px
                Address = "NONE"
                AddressDecimal = 0
                Formula = "No formula worked"
                Worked = "NO"
            }
            Write-Host "  ✗ No formula worked for $px pixels" -ForegroundColor Red
        }
    }

    Write-Host ""
}

$hidStream.Close()

Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Known: 1 pixel = 0x03D2 (978 decimal)" -ForegroundColor White
Write-Host ""

if ($testResults.Count -gt 0) {
    $testResults | Format-Table Pixels, Address, AddressDecimal, Formula, Worked -AutoSize

    $workingResults = $testResults | Where-Object { $_.Worked -eq "YES" }

    if ($workingResults.Count -gt 0) {
        Write-Host ""
        Write-Host "=== FORMULA FOUND ===" -ForegroundColor Green
        Write-Host ""

        $formulas = $workingResults | Select-Object -ExpandProperty Formula -Unique
        if ($formulas.Count -eq 1) {
            Write-Host "Consistent formula: $($formulas[0])" -ForegroundColor Green
            Write-Host ""
            Write-Host "All test scripts can now be updated with:" -ForegroundColor Yellow
            Write-Host "  `$address = $($formulas[0])" -ForegroundColor White
        } else {
            Write-Host "Multiple formulas found - pattern may be more complex:" -ForegroundColor Yellow
            $workingResults | Format-Table Pixels, Formula -AutoSize
        }
    }
}

Write-Host ""
