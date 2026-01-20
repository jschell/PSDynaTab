<#
.SYNOPSIS
    Phase 1, Test 1C: Position Encoding Validation (FIXED)

.DESCRIPTION
    Tests bounding box encoding in bytes 8-11 of init packet.

    CORRECTED PROTOCOL (from working capture analysis):
    - Byte 1: 0x00 (NOT 0x02!)
    - Bytes 4-5: pixel_count * 3 (little-endian)
    - Byte 7: Checksum = (0x100 - SUM(bytes[0:7])) & 0xFF
    - Bytes 8-9: X-start, Y-start (bounding box origin)
    - Bytes 10-11: X-end (exclusive), Y-end (exclusive)

.EXAMPLE
    .\Test-1C-PositionEncoding-FIXED.ps1 -TestAll

.NOTES
    Requirements:
    - DynaTab 75X connected
    - HidSharp.dll in PSDynaTab\lib\
    - Visual observation required
#>

param(
    [switch]$TestAll
)

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

$script:TestHIDStream = $null
$script:TestDevice = $null
$script:Results = @()

$ResultsFile = Join-Path $PSScriptRoot "Test-1C-Results-FIXED.csv"

function Connect-TestDevice {
    $deviceList = [HidSharp.DeviceList]::Local
    $devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
    $targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

    if ($targetDevice) {
        $script:TestDevice = $targetDevice
        $script:TestHIDStream = $targetDevice.Open()
        Write-Host "✓ Device connected" -ForegroundColor Green
        return $true
    }
    Write-Error "Device not found"
    return $false
}

function Disconnect-TestDevice {
    if ($script:TestHIDStream) {
        $script:TestHIDStream.Close()
        $script:TestHIDStream = $null
    }
}

function Calculate-Checksum {
    param([byte[]]$Packet)

    # CORRECTED algorithm: byte[7] = (0xFF - SUM(bytes[0:7])) & 0xFF
    # Note: Use 0xFF (255), not 0x100 (256)
    $sum = 0
    for ($i = 0; $i -lt 7; $i++) {
        $sum += $Packet[$i]
    }
    return [byte]((0xFF - ($sum -band 0xFF)) -band 0xFF)
}

function Send-StaticPictureInit {
    param(
        [byte]$XStart,
        [byte]$YStart,
        [byte]$XEnd,
        [byte]$YEnd
    )

    $pixelCount = ($XEnd - $XStart) * ($YEnd - $YStart)
    $dataBytes = $pixelCount * 3

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x00  # CORRECTED: Always 0x00, not 0x02!
    $packet[2] = 0x01  # 1 frame
    $packet[3] = 0x00  # 0ms delay

    # Bytes 4-5: Total pixel data bytes (little-endian)
    $packet[4] = [byte]($dataBytes -band 0xFF)
    $packet[5] = [byte](($dataBytes -shr 8) -band 0xFF)

    $packet[6] = 0x00

    # Byte 7: Checksum (calculated)
    $packet[7] = Calculate-Checksum -Packet $packet

    # Bytes 8-11: Bounding box
    $packet[8] = $XStart
    $packet[9] = $YStart
    $packet[10] = $XEnd
    $packet[11] = $YEnd

    # Send init packet
    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)

    Start-Sleep -Milliseconds 120
}

function Send-StaticPictureData {
    param(
        [byte]$R,
        [byte]$G,
        [byte]$B,
        [int]$PixelCount
    )

    # Calculate packets needed (18 pixels per packet max)
    $packetsNeeded = [Math]::Ceiling($PixelCount / 18.0)
    $baseAddress = 0x389D  # From Python library

    for ($pktIdx = 0; $pktIdx -lt $packetsNeeded; $pktIdx++) {
        $packet = New-Object byte[] 64
        $packet[0] = 0x29
        $packet[1] = 0x00  # Frame index
        $packet[2] = 0x01  # Frame count
        $packet[3] = 0x00  # Delay

        # Incrementing counter (little-endian)
        $packet[4] = [byte]($pktIdx -band 0xFF)
        $packet[5] = [byte](($pktIdx -shr 8) -band 0xFF)

        # Memory address - decrement from base (big-endian)
        $address = $baseAddress - $pktIdx
        $packet[6] = [byte](($address -shr 8) -band 0xFF)
        $packet[7] = [byte]($address -band 0xFF)

        # Fill with pixel data (up to 18 pixels per packet)
        $pixelsRemaining = $PixelCount - ($pktIdx * 18)
        $pixelsThisPacket = [Math]::Min(18, $pixelsRemaining)
        for ($p = 0; $p -lt $pixelsThisPacket; $p++) {
            $offset = 8 + ($p * 3)
            $packet[$offset] = $R
            $packet[$offset + 1] = $G
            $packet[$offset + 2] = $B
        }

        # Send data packet
        $featureReport = New-Object byte[] 65
        [Array]::Copy($packet, 0, $featureReport, 1, 64)
        $script:TestHIDStream.SetFeature($featureReport)

        Start-Sleep -Milliseconds 2
    }
}

function Test-BoundingBox {
    param(
        [string]$TestName,
        [byte]$XStart,
        [byte]$YStart,
        [byte]$XEnd,
        [byte]$YEnd,
        [string]$ExpectedResult
    )

    $pixelCount = ($XEnd - $XStart) * ($YEnd - $YStart)

    Write-Host "`n--- $TestName ---" -ForegroundColor Cyan
    Write-Host "  Bounding box: ($XStart,$YStart) to ($XEnd,$YEnd) exclusive" -ForegroundColor White
    Write-Host "  Expected: $ExpectedResult ($pixelCount pixels)" -ForegroundColor Yellow
    Write-Host ""

    # Send init with bounding box
    Send-StaticPictureInit -XStart $XStart -YStart $YStart -XEnd $XEnd -YEnd $YEnd

    # Send green pixel data
    Send-StaticPictureData -R 0x00 -G 0xFF -B 0x00 -PixelCount $pixelCount

    Write-Host "  Sent $pixelCount green pixels" -ForegroundColor Green
    Write-Host ""

    $visiblePixels = Read-Host "  How many green pixels visible?"
    $position = Read-Host "  Position description"
    $correct = Read-Host "  Matches expected? (Y/N)"

    $result = [PSCustomObject]@{
        TestName = $TestName
        XStart = $XStart
        YStart = $YStart
        XEnd = $XEnd
        YEnd = $YEnd
        ExpectedPixels = $pixelCount
        ExpectedResult = $ExpectedResult
        VisiblePixels = $visiblePixels
        Position = $position
        Correct = $correct
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $script:Results += $result
    Start-Sleep -Seconds 2
}

function Run-AllTests {
    Write-Host "`n=== Test 1C: Bounding Box Encoding (FIXED) ===" -ForegroundColor Yellow
    Write-Host "Protocol corrected based on working capture analysis"
    Write-Host ""

    # Test 1: Single pixel at (0,0)
    Test-BoundingBox `
        -TestName "1C-1_SinglePixel_TopLeft" `
        -XStart 0 -YStart 0 -XEnd 1 -YEnd 1 `
        -ExpectedResult "1 green pixel at top-left corner"

    # Test 2: Top row, 10 pixels
    Test-BoundingBox `
        -TestName "1C-2_TopRow_10Pixels" `
        -XStart 0 -YStart 0 -XEnd 10 -YEnd 1 `
        -ExpectedResult "10 green pixels across top row"

    # Test 3: Bottom-right corner pixel
    Test-BoundingBox `
        -TestName "1C-3_SinglePixel_BottomRight" `
        -XStart 59 -YStart 8 -XEnd 60 -YEnd 9 `
        -ExpectedResult "1 green pixel at bottom-right corner"

    # Test 4: Small region (5×3)
    Test-BoundingBox `
        -TestName "1C-4_SmallRegion_5x3" `
        -XStart 0 -YStart 0 -XEnd 5 -YEnd 3 `
        -ExpectedResult "15 green pixels (5 wide × 3 rows)"

    # Test 5: Full display
    Test-BoundingBox `
        -TestName "1C-5_FullDisplay" `
        -XStart 0 -YStart 0 -XEnd 60 -YEnd 9 `
        -ExpectedResult "Full display green (540 pixels)"

    # Test 6: Offset region (middle of display)
    Test-BoundingBox `
        -TestName "1C-6_OffsetRegion" `
        -XStart 25 -YStart 4 -XEnd 35 -YEnd 5 `
        -ExpectedResult "10 green pixels in middle row"

    # Test 7: Two-row region
    Test-BoundingBox `
        -TestName "1C-7_TwoRows_FullWidth" `
        -XStart 0 -YStart 0 -XEnd 60 -YEnd 2 `
        -ExpectedResult "120 green pixels (2 full rows)"
}

function Export-Results {
    if ($script:Results.Count -gt 0) {
        $script:Results | Export-Csv -Path $ResultsFile -NoTypeInformation
        Write-Host "`n✓ Results exported to: $ResultsFile" -ForegroundColor Green
        Write-Host "  Total tests: $($script:Results.Count)" -ForegroundColor Cyan
    }
}

function Show-Summary {
    Write-Host "`n=== FIXED Protocol Summary ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Init Packet Structure:" -ForegroundColor Cyan
    Write-Host "  Byte 1: 0x00 (NOT 0x02!)" -ForegroundColor Green
    Write-Host "  Bytes 4-5: pixel_count * 3 (little-endian)" -ForegroundColor Green
    Write-Host "  Byte 7: Checksum = (0x100 - SUM(bytes[0:7])) & 0xFF" -ForegroundColor Green
    Write-Host "  Bytes 8-11: [X-start, Y-start, X-end, Y-end]" -ForegroundColor Green
    Write-Host ""
    Write-Host "These corrections came from analyzing 38+ working captures." -ForegroundColor White
    Write-Host ""
}

# Main execution
try {
    Write-Host "=== Phase 1, Test 1C: Bounding Box Validation (FIXED) ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Connect-TestDevice)) {
        exit 1
    }

    Run-AllTests
    Export-Results
    Show-Summary
}
finally {
    Disconnect-TestDevice
}
