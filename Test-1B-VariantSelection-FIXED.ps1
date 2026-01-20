<#
.SYNOPSIS
    Phase 1, Test 1B: Animation Variant Discovery (FIXED)

.DESCRIPTION
    Tests animation packet structure with corrected protocol.

    CORRECTED PROTOCOL:
    - Byte 1: 0x00 (NOT 0x02!)
    - Bytes 4-5: Total pixel data bytes (pixel_count * 3)
    - Byte 7: Checksum = (0x100 - SUM(bytes[0:7])) & 0xFF
    - Bytes 8-11: Still testing - may be bounding box OR variant flags

    This test sends properly formatted animation packets to discover
    what controls the animation variant (packets per frame).

.EXAMPLE
    .\Test-1B-VariantSelection-FIXED.ps1 -TestAll

.NOTES
    Requirements:
    - DynaTab 75X connected
    - HidSharp.dll in PSDynaTab\lib\
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

$ResultsFile = Join-Path $PSScriptRoot "Test-1B-Results-FIXED.csv"

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

function Send-AnimationInit {
    param(
        [byte]$FrameCount,
        [byte]$Delay,
        [byte]$Byte8,
        [byte]$Byte9,
        [byte]$Byte10,
        [byte]$Byte11
    )

    # For full display animation
    $pixelCount = 60 * 9  # 540 pixels
    $dataBytes = $pixelCount * 3  # 1620 bytes

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x00  # Always 0x00
    $packet[2] = $FrameCount
    $packet[3] = $Delay

    # Bytes 4-5: Total data bytes
    $packet[4] = [byte]($dataBytes -band 0xFF)
    $packet[5] = [byte](($dataBytes -shr 8) -band 0xFF)

    $packet[6] = 0x00
    $packet[7] = Calculate-Checksum -Packet $packet

    # Test bytes 8-11
    $packet[8] = $Byte8
    $packet[9] = $Byte9
    $packet[10] = $Byte10
    $packet[11] = $Byte11

    # Send init packet
    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5

    # Get_Report handshake (REQUIRED per Python library)
    try {
        $response = New-Object byte[] 65
        $script:TestHIDStream.GetFeature($response)
        Start-Sleep -Milliseconds 5
    } catch {
        Write-Warning "Get_Report handshake failed (may be optional)"
    }
}

function Send-AnimationData {
    param(
        [byte]$FrameIndex,
        [byte]$FrameCount,
        [byte]$Delay,
        [int]$PacketIndex,
        [int]$OverallPacketCount,
        [int]$PacketsPerFrame,
        [byte[]]$ColorPattern
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0x29
    $packet[1] = $FrameIndex
    $packet[2] = $FrameCount
    $packet[3] = $Delay

    # Incrementing counter (little-endian, per Python library)
    $packet[4] = [byte]($OverallPacketCount -band 0xFF)
    $packet[5] = [byte](($OverallPacketCount -shr 8) -band 0xFF)

    # Memory address - decrement from base (big-endian, per Python library)
    $address = 0x3861 - $OverallPacketCount  # Python library uses 0x3861 for animations
    $packet[6] = [byte](($address -shr 8) -band 0xFF)
    $packet[7] = [byte]($address -band 0xFF)

    # Fill with pattern (18 pixels max)
    for ($p = 0; $p -lt 18; $p++) {
        $offset = 8 + ($p * 3)
        $colorIndex = $p % $ColorPattern.Length
        $packet[$offset] = $ColorPattern[$colorIndex]
        $packet[$offset + 1] = $ColorPattern[$colorIndex + 1]
        $packet[$offset + 2] = $ColorPattern[$colorIndex + 2]
    }

    # Last packet override for this frame (per Python library)
    if ($PacketIndex -eq ($PacketsPerFrame - 1)) {
        $packet[6] = 0x34
        $packet[7] = 0x49 - $FrameIndex  # Decrements per frame
    }

    # Send data packet
    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5  # 5ms per Python library
}

function Test-AnimationVariant {
    param(
        [string]$TestName,
        [byte]$Byte8,
        [byte]$Byte9,
        [byte]$Byte10,
        [byte]$Byte11,
        [int]$PacketsPerFrame,
        [string]$Description
    )

    Write-Host "`n--- $TestName ---" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor White
    Write-Host "  Bytes 8-11: 0x$($Byte8.ToString('X2')) $($Byte9.ToString('X2')) $($Byte10.ToString('X2')) $($Byte11.ToString('X2'))" -ForegroundColor Yellow
    Write-Host "  Testing $PacketsPerFrame packets/frame" -ForegroundColor Yellow
    Write-Host ""

    # Send init
    Send-AnimationInit `
        -FrameCount 3 `
        -Delay 100 `
        -Byte8 $Byte8 `
        -Byte9 $Byte9 `
        -Byte10 $Byte10 `
        -Byte11 $Byte11

    # Color pattern: red, green, blue
    $colorPattern = @(0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF)

    # Send data packets for 3 frames
    $overallPacketCount = 0
    for ($frame = 0; $frame -lt 3; $frame++) {
        $color = $colorPattern[($frame * 3)..(($frame * 3) + 2)]

        for ($pkt = 0; $pkt -lt $PacketsPerFrame; $pkt++) {
            Send-AnimationData `
                -FrameIndex $frame `
                -FrameCount 3 `
                -Delay 100 `
                -PacketIndex $pkt `
                -OverallPacketCount $overallPacketCount `
                -PacketsPerFrame $PacketsPerFrame `
                -ColorPattern $color

            $overallPacketCount++
        }
    }

    $totalPackets = $overallPacketCount

    Write-Host "  Sent $totalPackets packets total ($PacketsPerFrame × 3 frames)" -ForegroundColor Green
    Write-Host ""

    $visible = Read-Host "  Did animation display? (Y/N)"
    $color = Read-Host "  What did you see? (describe)"

    $result = [PSCustomObject]@{
        TestName = $TestName
        Byte8 = "0x{0:X2}" -f $Byte8
        Byte9 = "0x{0:X2}" -f $Byte9
        Byte10 = "0x{0:X2}" -f $Byte10
        Byte11 = "0x{0:X2}" -f $Byte11
        PacketsPerFrame = $PacketsPerFrame
        TotalPackets = $totalPackets
        AnimationVisible = $visible
        Observation = $color
        Description = $Description
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $script:Results += $result
    Start-Sleep -Seconds 2
}

function Run-AllTests {
    Write-Host "`n=== Test 1B: Animation Variant Discovery (FIXED) ===" -ForegroundColor Yellow
    Write-Host "Testing with corrected protocol structure"
    Write-Host ""

    # Test 1: Baseline - full display (from working captures)
    Test-AnimationVariant `
        -TestName "1B-1_Baseline_FullDisplay" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x3C -Byte11 0x09 `
        -PacketsPerFrame 29 `
        -Description "Full display bounding box (60×9)"

    # Test 2: Try small region
    Test-AnimationVariant `
        -TestName "1B-2_SmallRegion" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x0A -Byte11 0x01 `
        -PacketsPerFrame 1 `
        -Description "Small region (10×1 = 10 pixels = 1 packet)"

    # Test 3: Medium region
    Test-AnimationVariant `
        -TestName "1B-3_MediumRegion" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x1E -Byte11 0x03 `
        -PacketsPerFrame 6 `
        -Description "Medium region (30×3 = 90 pixels = 6 packets)"

    # Test 4: Two rows
    Test-AnimationVariant `
        -TestName "1B-4_TwoRows" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x3C -Byte11 0x02 `
        -PacketsPerFrame 9 `
        -Description "Two full rows (60×2 = 120 pixels = 9 packets)"

    # Test 5: Half display
    Test-AnimationVariant `
        -TestName "1B-5_HalfDisplay" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x1E -Byte11 0x09 `
        -PacketsPerFrame 15 `
        -Description "Half width (30×9 = 270 pixels = 15 packets)"

    # Test 6: Single row
    Test-AnimationVariant `
        -TestName "1B-6_SingleRow" `
        -Byte8 0x00 -Byte9 0x00 -Byte10 0x3C -Byte11 0x01 `
        -PacketsPerFrame 4 `
        -Description "Single full row (60×1 = 60 pixels = 4 packets)"
}

function Export-Results {
    if ($script:Results.Count -gt 0) {
        $script:Results | Export-Csv -Path $ResultsFile -NoTypeInformation
        Write-Host "`n✓ Results exported to: $ResultsFile" -ForegroundColor Green
        Write-Host "  Total tests: $($script:Results.Count)" -ForegroundColor Cyan

        $successCount = ($script:Results | Where-Object { $_.AnimationVisible -eq 'Y' }).Count
        Write-Host "  Success rate: $successCount / $($script:Results.Count)" -ForegroundColor $(if ($successCount -gt 0) { "Green" } else { "Yellow" })
    }
}

function Show-Summary {
    Write-Host "`n=== Animation Structure Summary ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Hypothesis: Bytes 8-11 define bounding box" -ForegroundColor Cyan
    Write-Host "  Byte 8-9: X-start, Y-start" -ForegroundColor White
    Write-Host "  Byte 10-11: X-end (exclusive), Y-end (exclusive)" -ForegroundColor White
    Write-Host ""
    Write-Host "Packets per frame = CEIL((width × height) / 18)" -ForegroundColor White
    Write-Host "  Each data packet holds 18 RGB pixels max" -ForegroundColor White
    Write-Host ""
    Write-Host "If all tests work, we've confirmed the bounding box hypothesis!" -ForegroundColor Green
    Write-Host ""
}

# Main execution
try {
    Write-Host "=== Phase 1, Test 1B: Animation Variant Discovery (FIXED) ===" -ForegroundColor Cyan
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
