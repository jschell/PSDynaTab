<#
.SYNOPSIS
    Phase 2 animation protocol deep-dive testing

.DESCRIPTION
    Tests advanced animation protocol features:
    - Frame count encoding (2, 4, 5 frames)
    - Frame delay timing precision
    - Packet distribution rules
    - Protocol limits and edge cases

.PARAMETER Test21
    Test frame count validation

.PARAMETER Test22
    Test frame delay timing

.PARAMETER Test23
    Test packet distribution

.PARAMETER TestAll
    Run all Phase 2 tests

.EXAMPLE
    .\Test-AnimationPhase2.ps1 -Test21
    Run frame count validation tests

.EXAMPLE
    .\Test-AnimationPhase2.ps1 -TestAll
    Run all Phase 2 tests

.NOTES
    Prerequisites: Phase 1 complete (Test-AnimationProtocol.ps1 passed)
    Based on PHASE2_TEST_PLAN.md
#>

[CmdletBinding()]
param(
    [switch]$Test21,  # Frame count validation
    [switch]$Test22,  # Frame delay timing
    [switch]$Test23,  # Packet distribution
    [switch]$TestAll = $true
)

# Load HidSharp for direct HID communication
$hidSharpPath = Join-Path $PSScriptRoot "PSDynaTab\lib\HidSharp.dll"
if (-not (Test-Path $hidSharpPath)) {
    throw "HidSharp.dll not found at: $hidSharpPath"
}
Add-Type -Path $hidSharpPath

# Device constants
$DEVICE_VID = 0x3151
$DEVICE_PID = 0x4015
$INTERFACE_INDEX = 3  # MI_02

# Script-level connection variables
$script:TestHIDStream = $null
$script:TestDevice = $null

# ============================================================================
# DEVICE CONNECTION FUNCTIONS
# ============================================================================

function Connect-TestDevice {
    Write-Host "Connecting to DynaTab keyboard..." -ForegroundColor Yellow

    try {
        $deviceList = [HidSharp.DeviceList]::Local
        $devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)

        if ($devices.Count -eq 0) {
            throw "DynaTab device not found (VID: 0x$($DEVICE_VID.ToString('X4')), PID: 0x$($DEVICE_PID.ToString('X4')))"
        }

        $targetDevice = $null
        foreach ($dev in $devices) {
            $path = $dev.DevicePath
            if ($path -match "mi_0*$($INTERFACE_INDEX - 1)") {
                $targetDevice = $dev
                break
            }
        }

        if (-not $targetDevice) {
            throw "Could not find DynaTab display interface (MI_02)"
        }

        $script:TestDevice = $targetDevice
        $script:TestHIDStream = $targetDevice.Open()

        if (-not $script:TestHIDStream) {
            throw "Failed to open HID stream"
        }

        Write-Host "✓ Connected to $($targetDevice.GetProductName())" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Connection failed: $_" -ForegroundColor Red
        $script:TestDevice = $null
        $script:TestHIDStream = $null
        return $false
    }
}

function Disconnect-TestDevice {
    try {
        if ($script:TestHIDStream) {
            $script:TestHIDStream.Close()
            $script:TestHIDStream = $null
        }
        $script:TestDevice = $null
        Write-Host "✓ Disconnected from DynaTab" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Cleanup error: $_" -ForegroundColor Yellow
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 80)" -ForegroundColor Cyan
}

function New-AnimationInitPacket {
    param(
        [byte]$Mode = 0x03,
        [byte]$DelayMS = 0x64,
        [byte]$FrameCount = 0x02,
        [uint16]$StartAddress = 0x093A
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x00
    $packet[2] = $Mode
    $packet[3] = $DelayMS
    $packet[4] = 0xe8
    $packet[5] = 0x05
    $packet[6] = 0x00
    $packet[7] = 0x02
    $packet[8] = $FrameCount
    $packet[9] = 0x00
    $packet[10] = [byte](($StartAddress -shr 8) -band 0xFF)
    $packet[11] = [byte]($StartAddress -band 0xFF)

    return $packet
}

function Send-InitPacket {
    param([byte[]]$Packet)

    try {
        if (-not $script:TestHIDStream) {
            throw "Device not connected"
        }

        $featureReport = New-Object byte[] 65
        $featureReport[0] = 0x00
        [Array]::Copy($Packet, 0, $featureReport, 1, $Packet.Length)

        $script:TestHIDStream.SetFeature($featureReport)
        Start-Sleep -Milliseconds 10
        return $true
    }
    catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        return $false
    }
}

function Get-DeviceStatus {
    try {
        if (-not $script:TestHIDStream) {
            return $null
        }

        $statusBuffer = New-Object byte[] 65
        $script:TestHIDStream.GetFeature($statusBuffer)
        return $statusBuffer
    }
    catch {
        return $null
    }
}

function Send-AnimationDataPacket {
    param(
        [byte]$Counter,
        [uint16]$Address,
        [byte]$Mode = 0x03,
        [byte]$DelayMS = 0x64,
        [byte[]]$PixelData
    )

    $pixelBytes = New-Object byte[] 56
    if ($PixelData) {
        $copyLen = [Math]::Min($PixelData.Length, 56)
        [Array]::Copy($PixelData, 0, $pixelBytes, 0, $copyLen)
    }

    $packet = New-Object byte[] 64
    $packet[0] = 0x29
    $packet[1] = 0x00
    $packet[2] = $Mode
    $packet[3] = $DelayMS
    $packet[4] = $Counter
    $packet[5] = 0x00
    $packet[6] = [byte](($Address -shr 8) -band 0xFF)
    $packet[7] = [byte]($Address -band 0xFF)

    [Array]::Copy($pixelBytes, 0, $packet, 8, 56)

    $featureReport = New-Object byte[] 65
    $featureReport[0] = 0x00
    [Array]::Copy($packet, 0, $featureReport, 1, 64)

    $script:TestHIDStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5
}

function New-FramePattern {
    param(
        [int]$FrameIndex,
        [int]$PixelCount = 8
    )

    # Create distinct color pattern per frame
    $colors = @(
        @{ R = 255; G = 0; B = 0 },      # Frame 0: Red
        @{ R = 0; G = 255; B = 0 },      # Frame 1: Green
        @{ R = 0; G = 0; B = 255 },      # Frame 2: Blue
        @{ R = 255; G = 255; B = 0 },    # Frame 3: Yellow
        @{ R = 255; G = 0; B = 255 },    # Frame 4: Magenta
        @{ R = 0; G = 255; B = 255 }     # Frame 5: Cyan
    )

    $color = $colors[$FrameIndex % $colors.Count]
    $data = New-Object byte[] 56

    # Create pattern with specified color
    for ($i = 0; $i -lt $PixelCount -and ($i * 3 + 2) -lt 56; $i++) {
        $offset = $i * 7
        if ($offset + 2 -lt 56) {
            $data[$offset] = $color.R
            $data[$offset + 1] = $color.G
            $data[$offset + 2] = $color.B
        }
    }

    return $data
}

# ============================================================================
# TEST 2.1: FRAME COUNT VALIDATION
# ============================================================================

function Test-FrameCountValidation {
    Write-TestHeader "TEST 2.1: Frame Count Validation"

    Write-Host "`nHypothesis: Byte 8 = (frame_count - 1)" -ForegroundColor Yellow
    Write-Host "Testing: 1, 2, 3, 4, 5 frame animations" -ForegroundColor Yellow

    $testCases = @(
        @{ FrameCountByte = 0x00; FrameCount = 1; PacketCount = 9; Description = "1 frame (static?)" },
        @{ FrameCountByte = 0x01; FrameCount = 2; PacketCount = 18; Description = "2 frames" },
        @{ FrameCountByte = 0x02; FrameCount = 3; PacketCount = 27; Description = "3 frames (baseline)" },
        @{ FrameCountByte = 0x03; FrameCount = 4; PacketCount = 36; Description = "4 frames" },
        @{ FrameCountByte = 0x04; FrameCount = 5; PacketCount = 45; Description = "5 frames" }
    )

    $results = @()

    foreach ($test in $testCases) {
        Write-Host "`n--- Testing: $($test.Description) ---" -ForegroundColor Cyan
        Write-Host "  Byte 8: 0x$($test.FrameCountByte.ToString('X2'))" -ForegroundColor Gray
        Write-Host "  Expected frames: $($test.FrameCount)" -ForegroundColor Gray
        Write-Host "  Packets to send: $($test.PacketCount) (9 per frame)" -ForegroundColor Gray

        # Send init packet
        $init = New-AnimationInitPacket -FrameCount $test.FrameCountByte -DelayMS 100
        Send-InitPacket $init | Out-Null
        Start-Sleep -Milliseconds 120
        Get-DeviceStatus | Out-Null

        # Send data packets
        Write-Host "  Sending packets..." -ForegroundColor Gray
        for ($i = 0; $i -lt $test.PacketCount; $i++) {
            $frameIndex = [Math]::Floor($i / 9)
            $pixelData = New-FramePattern -FrameIndex $frameIndex
            Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -PixelData $pixelData
        }

        Write-Host "`n  VISUAL OBSERVATION:" -ForegroundColor Yellow
        Write-Host "    Expected: $($test.FrameCount) distinct frames" -ForegroundColor Yellow
        Write-Host "    Frame colors:" -ForegroundColor Yellow
        for ($f = 0; $f -lt $test.FrameCount; $f++) {
            $colors = @("Red", "Green", "Blue", "Yellow", "Magenta", "Cyan")
            Write-Host "      Frame $($f+1): $($colors[$f])" -ForegroundColor Gray
        }
        Write-Host "    Loop timing: $($test.FrameCount * 100)ms total cycle" -ForegroundColor Yellow

        # Manual confirmation
        $response = Read-Host "`n  Correct number of frames displayed? (Y/N/U=Unclear)"

        $results += [PSCustomObject]@{
            FrameCountByte = "0x$($test.FrameCountByte.ToString('X2'))"
            ExpectedFrames = $test.FrameCount
            PacketsSent = $test.PacketCount
            Result = $response
            Description = $test.Description
        }

        Write-Host ""
        Start-Sleep -Seconds 2
    }

    # Summary
    Write-Host "`n$('-' * 80)" -ForegroundColor Yellow
    Write-Host "FRAME COUNT VALIDATION SUMMARY" -ForegroundColor Yellow
    Write-Host "$('-' * 80)" -ForegroundColor Yellow

    $results | Format-Table -AutoSize

    $confirmed = ($results | Where-Object { $_.Result -eq 'Y' }).Count
    $total = $results.Count

    Write-Host "`nConfirmed: $confirmed / $total tests" -ForegroundColor $(if ($confirmed -eq $total) { "Green" } else { "Yellow" })

    if ($confirmed -eq $total) {
        Write-Host "✓ Frame count encoding CONFIRMED: Byte 8 = (frame_count - 1)" -ForegroundColor Green
    }
    else {
        Write-Host "? Frame count encoding needs further investigation" -ForegroundColor Yellow
    }

    return $results
}

# ============================================================================
# TEST 2.2: FRAME DELAY TIMING
# ============================================================================

function Test-FrameDelayTiming {
    Write-TestHeader "TEST 2.2: Frame Delay Timing Precision"

    Write-Host "`nHypothesis: Byte 3 = delay in milliseconds (8-bit)" -ForegroundColor Yellow
    Write-Host "Testing: 50ms, 100ms, 200ms, 255ms delays" -ForegroundColor Yellow

    $testCases = @(
        @{ DelayMS = 50; Byte = 0x32 },
        @{ DelayMS = 100; Byte = 0x64 },
        @{ DelayMS = 200; Byte = 0xC8 },
        @{ DelayMS = 255; Byte = 0xFF }
    )

    $results = @()

    foreach ($test in $testCases) {
        Write-Host "`n--- Testing: ${test.DelayMS}ms delay ---" -ForegroundColor Cyan
        Write-Host "  Byte 3: 0x$($test.Byte.ToString('X2'))" -ForegroundColor Gray

        # Send 3-frame animation
        $init = New-AnimationInitPacket -DelayMS $test.Byte -FrameCount 0x02
        Send-InitPacket $init | Out-Null
        Start-Sleep -Milliseconds 120
        Get-DeviceStatus | Out-Null

        # Send 27 packets (3 frames)
        for ($i = 0; $i -lt 27; $i++) {
            $frameIndex = [Math]::Floor($i / 9)
            $pixelData = New-FramePattern -FrameIndex $frameIndex
            Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -DelayMS $test.Byte -PixelData $pixelData
        }

        Write-Host "`n  TIMING OBSERVATION:" -ForegroundColor Yellow
        Write-Host "    Expected delay: ${test.DelayMS}ms per frame" -ForegroundColor Yellow
        Write-Host "    Total cycle: $($test.DelayMS * 3)ms (3 frames)" -ForegroundColor Yellow
        Write-Host "    Cycles per minute: $([Math]::Round(60000 / ($test.DelayMS * 3), 1))" -ForegroundColor Yellow

        Write-Host "`n  MEASUREMENT METHODS:" -ForegroundColor Gray
        Write-Host "    - Count cycles in 10 seconds" -ForegroundColor Gray
        Write-Host "    - Use smartphone slow-motion video (120/240fps)" -ForegroundColor Gray
        Write-Host "    - Compare relative timing to other delays" -ForegroundColor Gray

        Start-Sleep -Seconds 5

        $actualDelay = Read-Host "`n  Estimated actual delay (ms) [or press Enter to skip]"
        $visualConfirm = Read-Host "  Does timing match expected? (Y/N/U=Unclear)"

        $results += [PSCustomObject]@{
            ConfiguredDelay = "${test.DelayMS}ms"
            ByteValue = "0x$($test.Byte.ToString('X2'))"
            EstimatedActual = if ($actualDelay) { "${actualDelay}ms" } else { "Not measured" }
            MatchesExpected = $visualConfirm
        }

        Start-Sleep -Seconds 2
    }

    # Summary
    Write-Host "`n$('-' * 80)" -ForegroundColor Yellow
    Write-Host "FRAME DELAY TIMING SUMMARY" -ForegroundColor Yellow
    Write-Host "$('-' * 80)" -ForegroundColor Yellow

    $results | Format-Table -AutoSize

    Write-Host "`nNote: Precise timing requires high-speed video capture" -ForegroundColor Gray
    Write-Host "Recommendation: Use 60fps+ camera and frame-by-frame analysis" -ForegroundColor Gray

    return $results
}

# ============================================================================
# TEST 2.3: PACKET DISTRIBUTION
# ============================================================================

function Test-PacketDistribution {
    Write-TestHeader "TEST 2.3: Packet Distribution Rules"

    Write-Host "`nHypothesis: Total packets = frame_count × packets_per_frame" -ForegroundColor Yellow
    Write-Host "Testing: Even, uneven, and alternative packet counts" -ForegroundColor Yellow

    $testCases = @(
        @{ Frames = 2; FrameByte = 0x01; Packets = 18; PPF = 9; Distribution = "9+9"; Description = "Even (baseline)" },
        @{ Frames = 2; FrameByte = 0x01; Packets = 20; PPF = 10; Distribution = "10+10"; Description = "Even (10 per frame)" },
        @{ Frames = 3; FrameByte = 0x02; Packets = 27; PPF = 9; Distribution = "9+9+9"; Description = "Even (baseline)" },
        @{ Frames = 3; FrameByte = 0x02; Packets = 30; PPF = 10; Distribution = "10+10+10"; Description = "Even (10 per frame)" },
        @{ Frames = 3; FrameByte = 0x02; Packets = 25; PPF = 8.33; Distribution = "9+8+8?"; Description = "Uneven total" },
        @{ Frames = 3; FrameByte = 0x02; Packets = 24; PPF = 8; Distribution = "8+8+8"; Description = "Even (8 per frame)" }
    )

    $results = @()

    foreach ($test in $testCases) {
        Write-Host "`n--- Testing: $($test.Description) ---" -ForegroundColor Cyan
        Write-Host "  Frames: $($test.Frames) (byte 8 = 0x$($test.FrameByte.ToString('X2')))" -ForegroundColor Gray
        Write-Host "  Total packets: $($test.Packets)" -ForegroundColor Gray
        Write-Host "  Expected distribution: $($test.Distribution)" -ForegroundColor Gray

        # Send init
        $init = New-AnimationInitPacket -FrameCount $test.FrameByte -DelayMS 100
        Send-InitPacket $init | Out-Null
        Start-Sleep -Milliseconds 120
        Get-DeviceStatus | Out-Null

        # Send packets
        Write-Host "  Sending $($test.Packets) packets..." -ForegroundColor Gray
        for ($i = 0; $i -lt $test.Packets; $i++) {
            $frameIndex = [Math]::Floor($i / $test.PPF)
            $pixelData = New-FramePattern -FrameIndex $frameIndex
            Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -PixelData $pixelData
        }

        Write-Host "`n  VISUAL OBSERVATION:" -ForegroundColor Yellow
        Write-Host "    Expected frames: $($test.Frames)" -ForegroundColor Yellow
        Write-Host "    Check for:" -ForegroundColor Yellow
        Write-Host "      - Correct frame count" -ForegroundColor Gray
        Write-Host "      - No corruption or artifacts" -ForegroundColor Gray
        Write-Host "      - Smooth transitions" -ForegroundColor Gray

        $frameCount = Read-Host "`n  How many distinct frames visible? (number)"
        $quality = Read-Host "  Visual quality? (Good/Corrupted/Partial)"

        $results += [PSCustomObject]@{
            ConfigFrames = $test.Frames
            TotalPackets = $test.Packets
            Distribution = $test.Distribution
            ActualFrames = $frameCount
            Quality = $quality
            Match = if ($frameCount -eq $test.Frames.ToString() -and $quality -eq 'Good') { "✓" } else { "✗" }
        }

        Start-Sleep -Seconds 2
    }

    # Summary
    Write-Host "`n$('-' * 80)" -ForegroundColor Yellow
    Write-Host "PACKET DISTRIBUTION SUMMARY" -ForegroundColor Yellow
    Write-Host "$('-' * 80)" -ForegroundColor Yellow

    $results | Format-Table -AutoSize

    $successes = ($results | Where-Object { $_.Match -eq "✓" }).Count
    Write-Host "`nSuccessful configurations: $successes / $($results.Count)" -ForegroundColor $(if ($successes -eq $results.Count) { "Green" } else { "Yellow" })

    return $results
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host @"

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║               Phase 2: Animation Protocol Deep Dive                       ║
║                                                                            ║
║  Advanced testing: Frame counts, timing, packet distribution              ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    $runAll = $TestAll -or (-not ($Test21 -or $Test22 -or $Test23))

    try {
        # Connect to device
        if (-not (Connect-TestDevice)) {
            throw "Failed to connect to device"
        }
        Write-Host ""

        $allResults = @{}

        if ($Test21 -or $runAll) {
            $allResults['FrameCount'] = Test-FrameCountValidation
            if ($runAll) { Start-Sleep -Seconds 3 }
        }

        if ($Test22 -or $runAll) {
            $allResults['FrameDelay'] = Test-FrameDelayTiming
            if ($runAll) { Start-Sleep -Seconds 3 }
        }

        if ($Test23 -or $runAll) {
            $allResults['PacketDist'] = Test-PacketDistribution
        }

        # Final summary
        Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
        Write-Host "  PHASE 2 TEST SUITE COMPLETE" -ForegroundColor Cyan
        Write-Host "$('=' * 80)" -ForegroundColor Cyan

        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "  1. Review results and update PHASE2_TEST_RESULTS.md" -ForegroundColor Gray
        Write-Host "  2. Test edge cases (max delay, max frames, zero delay)" -ForegroundColor Gray
        Write-Host "  3. Measure precise timing with high-speed camera" -ForegroundColor Gray
        Write-Host "  4. Begin PSDynaTab animation implementation" -ForegroundColor Gray

        return $allResults
    }
    catch {
        Write-Host "`nERROR: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        Disconnect-TestDevice
    }
}

# Run tests
Main
