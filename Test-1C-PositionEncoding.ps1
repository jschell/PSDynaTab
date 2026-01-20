<#
.SYNOPSIS
    Phase 1, Test 1C: Position Encoding Validation

.DESCRIPTION
    Tests how bytes 10-11 in init packet encode region dimensions.

    Question: Do bytes 10-11 represent:
    - Option A: X-end/Y-end (exclusive bounds)
    - Option B: Width/Height (dimensions)

    Known working example: 0x0d09 (static picture)
    - If Option A: Region from (0,0) to (13,9) exclusive = 13×9 pixels
    - If Option B: Region width=13, height=9 = 13×9 pixels

.PARAMETER TestAll
    Run all position encoding tests

.EXAMPLE
    .\Test-1C-PositionEncoding.ps1 -TestAll
    Test all position configurations to determine encoding

.NOTES
    Requirements:
    - DynaTab 75X connected
    - HidSharp.dll in PSDynaTab\lib\
    - Visual observation required (photos recommended)
    - Display is 60×9 pixels

    Output:
    - Test-1C-Results.csv: Test configurations and observations
    - Console: Real-time test progress and visual prompts
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

# Output file
$ResultsFile = Join-Path $PSScriptRoot "Test-1C-Results.csv"

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

function Send-StaticPictureInit {
    param(
        [byte]$Byte10,
        [byte]$Byte11
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x02  # Static picture mode
    $packet[2] = 0x01  # 1 frame
    $packet[3] = 0x64  # 100ms delay (not used in static)
    $packet[4] = 0x00  # Unknown
    $packet[5] = 0x00  # Unknown
    $packet[6] = 0x00  # Checksum (unknown)
    $packet[7] = 0x00  # Checksum (unknown)
    $packet[8] = 0x00  # Variant flags
    $packet[9] = 0x00  # Variant flags
    $packet[10] = $Byte10  # Position parameter 1
    $packet[11] = $Byte11  # Position parameter 2

    # Send init packet
    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)

    Start-Sleep -Milliseconds 120

    # Get_Report handshake
    try {
        $response = New-Object byte[] 65
        $script:TestHIDStream.GetFeature($response)
    } catch {
        # Optional handshake
    }

    Start-Sleep -Milliseconds 105
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
    $address = 0x389D  # Static picture start address

    for ($pktIndex = 0; $pktIndex -lt $packetsNeeded; $pktIndex++) {
        $packet = New-Object byte[] 64
        $packet[0] = 0x29
        $packet[1] = 0x00  # Frame index
        $packet[2] = 0x01  # Frame count
        $packet[3] = 0x64  # Delay
        $packet[4] = $pktIndex  # Packet counter

        # Memory address (big-endian, decrements)
        $packet[6] = [byte](($address -shr 8) -band 0xFF)
        $packet[7] = [byte]($address -band 0xFF)
        $address--

        # Fill with pixel data
        $pixelsThisPacket = [Math]::Min(18, $PixelCount - ($pktIndex * 18))
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

function Test-PositionConfiguration {
    param(
        [string]$TestName,
        [byte]$Byte10,
        [byte]$Byte11,
        [string]$HypothesisA,  # If X-end/Y-end
        [string]$HypothesisB,  # If Width/Height
        [int]$ExpectedPixels
    )

    Write-Host "`n--- $TestName ---" -ForegroundColor Cyan
    Write-Host "  Bytes 10-11: 0x$($Byte10.ToString('X2'))$($Byte11.ToString('X2'))" -ForegroundColor White
    Write-Host ""
    Write-Host "  Hypothesis A (X-end/Y-end): $HypothesisA" -ForegroundColor Yellow
    Write-Host "  Hypothesis B (Width/Height): $HypothesisB" -ForegroundColor Yellow
    Write-Host "  Expected pixels: $ExpectedPixels" -ForegroundColor White
    Write-Host ""

    # Send init with test bytes
    Send-StaticPictureInit -Byte10 $Byte10 -Byte11 $Byte11

    # Send green pixel data
    Send-StaticPictureData -R 0x00 -G 0xFF -B 0x00 -PixelCount $ExpectedPixels

    Write-Host "  Sent $ExpectedPixels green pixels" -ForegroundColor Green
    Write-Host ""
    Write-Host "  VISUAL CHECK:" -ForegroundColor Yellow
    Write-Host "    - Take photo of display"
    Write-Host "    - Count visible green pixels"
    Write-Host "    - Note their position (row, column)"
    Write-Host ""

    $visiblePixels = Read-Host "  How many green pixels visible?"
    $position = Read-Host "  Position description (e.g., 'top-left 10 pixels', 'full row')"
    $matchesA = Read-Host "  Matches Hypothesis A? (Y/N)"
    $matchesB = Read-Host "  Matches Hypothesis B? (Y/N)"

    # Log result
    $result = [PSCustomObject]@{
        TestName = $TestName
        Byte10 = "0x{0:X2}" -f $Byte10
        Byte11 = "0x{0:X2}" -f $Byte11
        HypothesisA = $HypothesisA
        HypothesisB = $HypothesisB
        ExpectedPixels = $ExpectedPixels
        VisiblePixels = $visiblePixels
        Position = $position
        MatchesHypothesisA = $matchesA
        MatchesHypothesisB = $matchesB
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $script:Results += $result

    Start-Sleep -Seconds 2
}

function Run-AllTests {
    Write-Host "`n=== Test 1C: Position Encoding Validation ===" -ForegroundColor Yellow
    Write-Host "Objective: Determine if bytes 10-11 are X-end/Y-end or Width/Height"
    Write-Host ""
    Write-Host "Display dimensions: 60×9 pixels (width × height)"
    Write-Host "Coordinate system: (0,0) = top-left, (59,8) = bottom-right"
    Write-Host ""

    # Test 1: Single row, 10 pixels
    Test-PositionConfiguration `
        -TestName "1C-1_TopRow10Pixels" `
        -Byte10 0x0A `
        -Byte11 0x01 `
        -HypothesisA "Region (0,0) to (10,1) exclusive = 10×1 = 10 pixels" `
        -HypothesisB "Region width=10, height=1 = 10 pixels" `
        -ExpectedPixels 10

    # Test 2: Two rows, full width
    Test-PositionConfiguration `
        -TestName "1C-2_TwoFullRows" `
        -Byte10 0x3C `
        -Byte11 0x02 `
        -HypothesisA "Region (0,0) to (60,2) exclusive = 60×2 = 120 pixels" `
        -HypothesisB "Region width=60, height=2 = 120 pixels" `
        -ExpectedPixels 120

    # Test 3: Baseline (known working: 0x0d09)
    # From static picture tests: 0x0d = 13, 0x09 = 9
    # But does this mean 13×9 or (0,0)→(13,9)?
    Test-PositionConfiguration `
        -TestName "1C-3_Baseline_0d09" `
        -Byte10 0x0D `
        -Byte11 0x09 `
        -HypothesisA "Region (0,0) to (13,9) exclusive = 13×9 = 117 pixels" `
        -HypothesisB "Region width=13, height=9 = 13×9 = 117 pixels" `
        -ExpectedPixels 117

    # Test 4: Small region to differentiate
    # 5×2 vs (0,0)→(5,2) gives same result, need asymmetric test
    Test-PositionConfiguration `
        -TestName "1C-4_SmallRegion" `
        -Byte10 0x05 `
        -Byte11 0x03 `
        -HypothesisA "Region (0,0) to (5,3) exclusive = 5×3 = 15 pixels" `
        -HypothesisB "Region width=5, height=3 = 5×3 = 15 pixels" `
        -ExpectedPixels 15

    # Test 5: Single pixel
    # This should differentiate: 1×1 vs (0,0)→(1,1)
    Test-PositionConfiguration `
        -TestName "1C-5_SinglePixel" `
        -Byte10 0x01 `
        -Byte11 0x01 `
        -HypothesisA "Region (0,0) to (1,1) exclusive = 1×1 = 1 pixel" `
        -HypothesisB "Region width=1, height=1 = 1 pixel" `
        -ExpectedPixels 1

    # Test 6: Maximum (full display)
    Test-PositionConfiguration `
        -TestName "1C-6_FullDisplay" `
        -Byte10 0x3C `
        -Byte11 0x09 `
        -HypothesisA "Region (0,0) to (60,9) exclusive = 60×9 = 540 pixels" `
        -HypothesisB "Region width=60, height=9 = 60×9 = 540 pixels" `
        -ExpectedPixels 540

    # Test 7: Edge case - zero values
    Test-PositionConfiguration `
        -TestName "1C-7_ZeroValues" `
        -Byte10 0x00 `
        -Byte11 0x00 `
        -HypothesisA "Region (0,0) to (0,0) exclusive = 0 pixels (no display?)" `
        -HypothesisB "Region width=0, height=0 = 0 pixels (no display?)" `
        -ExpectedPixels 0
}

function Export-Results {
    if ($script:Results.Count -gt 0) {
        $script:Results | Export-Csv -Path $ResultsFile -NoTypeInformation
        Write-Host "`n✓ Results exported to: $ResultsFile" -ForegroundColor Green
        Write-Host "  Total tests: $($script:Results.Count)" -ForegroundColor Cyan
    }
}

function Show-AnalysisGuidance {
    Write-Host "`n=== Analysis Guidance ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Open Test-1C-Results.csv"
    Write-Host "2. Compare observations:"
    Write-Host "   - Did visible pixels match Hypothesis A or B?"
    Write-Host "   - Were there any ambiguous cases?"
    Write-Host ""
    Write-Host "3. Key differentiators:"
    Write-Host "   - Test 1C-5 (single pixel): Should show 1 pixel"
    Write-Host "   - Test 1C-7 (zeros): Should show nothing or error"
    Write-Host ""
    Write-Host "4. Expected conclusion:"
    Write-Host "   - Both hypotheses give same result for most tests"
    Write-Host "   - Likely encoding: Width × Height (more common)"
    Write-Host "   - Or: X-end/Y-end with exclusive bounds"
    Write-Host ""
    Write-Host "5. Next steps:"
    Write-Host "   - Document encoding in DYNATAB_PROTOCOL_SPECIFICATION.md"
    Write-Host "   - Update PSDynaTab implementation"
    Write-Host "   - Test non-zero starting positions (requires more protocol knowledge)"
    Write-Host ""
}

# Main execution
try {
    Write-Host "=== Phase 1, Test 1C: Position Encoding Validation ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Connect-TestDevice)) {
        exit 1
    }

    Run-AllTests

    Export-Results
    Show-AnalysisGuidance
}
finally {
    Disconnect-TestDevice
}
