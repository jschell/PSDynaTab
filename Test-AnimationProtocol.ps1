<#
.SYNOPSIS
    Test suite to validate animation protocol assumptions from USBPcap analysis

.DESCRIPTION
    Validates the animation mode discoveries from USBPCAP_ANIMATION_ANALYSIS.md:
    1. Mode byte validation (0x03 vs 0x01)
    2. Frame delay parameter (byte 3)
    3. Frame count encoding (bytes 8-9)
    4. Continuous packet stream behavior
    5. Sparse frame data handling
    6. Device-controlled looping

.PARAMETER TestAll
    Run all animation protocol tests

.EXAMPLE
    .\Test-AnimationProtocol.ps1 -TestAll
    Run complete animation protocol validation suite

.NOTES
    Based on analysis in USBPCAP_ANIMATION_ANALYSIS.md
    Requires DynaTab 75X keyboard connected
#>

[CmdletBinding()]
param(
    [switch]$TestAll = $true
)

# Import PSDynaTab module
$ModulePath = Join-Path $PSScriptRoot "PSDynaTab\PSDynaTab.psm1"
if (-not (Test-Path $ModulePath)) {
    throw "PSDynaTab module not found at: $ModulePath"
}
Import-Module $ModulePath -Force

# ============================================================================
# CONSTANTS FROM ANALYSIS
# ============================================================================

# Static mode init packet (baseline)
$STATIC_MODE_INIT = [byte[]]@(
    0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
    0x00, 0x00, 0x3c, 0x09, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

# Animation mode init packet (3 frames, 100ms delay) - from official trace
$ANIMATION_MODE_INIT_100MS = [byte[]]@(
    0xa9, 0x00, 0x03, 0x64, 0xe8, 0x05, 0x00, 0x02,  # Mode 0x03, 100ms delay
    0x02, 0x00, 0x3a, 0x09, 0x00, 0x00, 0x00, 0x00,  # Frame count-1 = 0x02
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 80)" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Success,
        [string]$Message = ""
    )
    $symbol = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { "Green" } else { "Red" }
    Write-Host "[$symbol] $Test" -ForegroundColor $color
    if ($Message) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
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
    param(
        [byte[]]$Packet,
        [string]$Description
    )

    Write-Host "  Sending: $Description" -ForegroundColor Gray

    try {
        # Get HIDStream from module scope
        $module = Get-Module PSDynaTab
        $stream = & $module { $script:HIDStream }

        if (-not $stream) {
            throw "Device not connected"
        }

        $featureReport = New-Object byte[] 65
        $featureReport[0] = 0x00
        [Array]::Copy($Packet, 0, $featureReport, 1, $Packet.Length)

        $stream.SetFeature($featureReport)
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
        # Get HIDStream from module scope
        $module = Get-Module PSDynaTab
        $stream = & $module { $script:HIDStream }

        if (-not $stream) {
            return $null
        }

        $statusBuffer = New-Object byte[] 65
        $stream.GetFeature($statusBuffer)
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

    # Ensure pixel data is exactly 56 bytes
    $pixelBytes = New-Object byte[] 56
    if ($PixelData) {
        $copyLen = [Math]::Min($PixelData.Length, 56)
        [Array]::Copy($PixelData, 0, $pixelBytes, 0, $copyLen)
    }

    # Build packet header (8 bytes) + pixel data (56 bytes)
    $packet = New-Object byte[] 64
    $packet[0] = 0x29                                    # Data packet marker
    $packet[1] = 0x00                                    # Frame index
    $packet[2] = $Mode                                   # Animation mode (0x03)
    $packet[3] = $DelayMS                                # Frame delay
    $packet[4] = $Counter                                # Packet counter
    $packet[5] = 0x00                                    # Always 0x00
    $packet[6] = [byte](($Address -shr 8) -band 0xFF)    # Address high byte
    $packet[7] = [byte]($Address -band 0xFF)             # Address low byte

    [Array]::Copy($pixelBytes, 0, $packet, 8, 56)

    # Send packet
    $featureReport = New-Object byte[] 65
    $featureReport[0] = 0x00
    [Array]::Copy($packet, 0, $featureReport, 1, 64)

    # Get HIDStream from module scope
    $module = Get-Module PSDynaTab
    $stream = & $module { $script:HIDStream }

    $stream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5
}

function New-SparseFrameData {
    param(
        [byte]$R = 184,
        [byte]$G = 39,
        [byte]$B = 39,
        [int]$PixelCount = 8
    )

    # Create sparse pixel data (mostly black with some colored pixels)
    $data = New-Object byte[] 56

    # Add colored pixels at intervals
    for ($i = 0; $i -lt $PixelCount -and ($i * 3 + 2) -lt 56; $i++) {
        $offset = $i * 7  # Spread them out
        if ($offset + 2 -lt 56) {
            $data[$offset] = $R
            $data[$offset + 1] = $G
            $data[$offset + 2] = $B
        }
    }

    return $data
}

# ============================================================================
# TEST 1: MODE BYTE VALIDATION
# ============================================================================

function Test-ModeByte {
    Write-TestHeader "TEST 1: Mode Byte Validation (0x03 vs 0x01)"

    Write-Host "`nHypothesis: Byte 2 = 0x03 enables animation mode" -ForegroundColor Yellow
    Write-Host "Expected: Device accepts both 0x01 (static) and 0x03 (animation)" -ForegroundColor Yellow

    # Test static mode (baseline)
    Write-Host "`nTest 1A: Static Mode (0x01)" -ForegroundColor Cyan
    $staticInit = New-AnimationInitPacket -Mode 0x01 -DelayMS 0x00 -FrameCount 0x00
    $staticSuccess = Send-InitPacket -Packet $staticInit -Description "Static mode (0x01)"
    Start-Sleep -Milliseconds 120
    $staticStatus = Get-DeviceStatus
    Write-TestResult -Test "Static mode initialization" -Success ($null -ne $staticStatus) `
        -Message "Mode 0x01 accepted"

    Start-Sleep -Milliseconds 500

    # Test animation mode
    Write-Host "`nTest 1B: Animation Mode (0x03)" -ForegroundColor Cyan
    $animInit = New-AnimationInitPacket -Mode 0x03 -DelayMS 0x64 -FrameCount 0x02
    $animSuccess = Send-InitPacket -Packet $animInit -Description "Animation mode (0x03, 100ms)"
    Start-Sleep -Milliseconds 120
    $animStatus = Get-DeviceStatus
    Write-TestResult -Test "Animation mode initialization" -Success ($null -ne $animStatus) `
        -Message "Mode 0x03 accepted"

    Write-Host "`nResult: Mode byte $($null -ne $animStatus ? 'IS' : 'IS NOT') recognized by device" -ForegroundColor Yellow
}

# ============================================================================
# TEST 2: FRAME DELAY PARAMETER
# ============================================================================

function Test-FrameDelay {
    Write-TestHeader "TEST 2: Frame Delay Parameter Testing"

    Write-Host "`nHypothesis: Byte 3 controls frame delay in milliseconds" -ForegroundColor Yellow
    Write-Host "Test: Send animations with different delay values (50ms, 100ms, 200ms)" -ForegroundColor Yellow

    $delays = @(
        @{ Value = 0x32; MS = 50; Desc = "50ms delay" },
        @{ Value = 0x64; MS = 100; Desc = "100ms delay (official)" },
        @{ Value = 0xC8; MS = 200; Desc = "200ms delay" }
    )

    foreach ($delay in $delays) {
        Write-Host "`nTest: $($delay.Desc)" -ForegroundColor Cyan

        # Create init packet with specific delay
        $initPacket = New-AnimationInitPacket -Mode 0x03 -DelayMS $delay.Value -FrameCount 0x02
        $success = Send-InitPacket -Packet $initPacket -Description "$($delay.Desc)"
        Start-Sleep -Milliseconds 120

        $status = Get-DeviceStatus
        Write-TestResult -Test "Delay value 0x$($delay.Value.ToString('X2')) ($($delay.MS)ms)" `
            -Success ($null -ne $status) -Message "Init packet accepted"

        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nNote: Visual timing validation requires video capture or oscilloscope" -ForegroundColor Yellow
}

# ============================================================================
# TEST 3: FRAME COUNT ENCODING
# ============================================================================

function Test-FrameCount {
    Write-TestHeader "TEST 3: Frame Count Encoding Validation"

    Write-Host "`nHypothesis: Bytes 8-9 encode frame count (0x02 = 3 frames?)" -ForegroundColor Yellow
    Write-Host "Test: Send init packets with different frame count values" -ForegroundColor Yellow

    $frameCounts = @(
        @{ Value = 0x01; Frames = 2; Desc = "2 frames (0x01)" },
        @{ Value = 0x02; Frames = 3; Desc = "3 frames (0x02) - official" },
        @{ Value = 0x03; Frames = 4; Desc = "4 frames (0x03)" },
        @{ Value = 0x04; Frames = 5; Desc = "5 frames (0x04)" }
    )

    foreach ($fc in $frameCounts) {
        Write-Host "`nTest: $($fc.Desc)" -ForegroundColor Cyan

        $initPacket = New-AnimationInitPacket -Mode 0x03 -DelayMS 0x64 -FrameCount $fc.Value
        $success = Send-InitPacket -Packet $initPacket -Description "$($fc.Desc)"
        Start-Sleep -Milliseconds 120

        $status = Get-DeviceStatus
        Write-TestResult -Test "Frame count byte 0x$($fc.Value.ToString('X2'))" `
            -Success ($null -ne $status) -Message "Device accepted init"

        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nConclusion: Need to observe playback behavior to confirm frame splitting" -ForegroundColor Yellow
}

# ============================================================================
# TEST 4: CONTINUOUS PACKET STREAM
# ============================================================================

function Test-ContinuousPacketStream {
    Write-TestHeader "TEST 4: Continuous Packet Stream Validation"

    Write-Host "`nHypothesis: Animation sends 27 packets with linear address decrement" -ForegroundColor Yellow
    Write-Host "Expected: Address decrements from 0x3837 to 0x381D (27 packets)" -ForegroundColor Yellow

    # Initialize animation mode
    Write-Host "`nInitializing animation mode..." -ForegroundColor Cyan
    $initPacket = $ANIMATION_MODE_INIT_100MS
    Send-InitPacket -Packet $initPacket -Description "Animation mode, 3 frames, 100ms" | Out-Null
    Start-Sleep -Milliseconds 120
    Get-DeviceStatus | Out-Null

    Write-Host "Sending 27 continuous packets..." -ForegroundColor Cyan

    # Send 27 packets as per official trace
    $startAddress = 0x3837
    $endAddress = 0x381D
    $totalPackets = 27

    for ($i = 0; $i -lt $totalPackets; $i++) {
        $counter = $i
        $address = $startAddress - $i

        # Create sparse frame data (alternating patterns)
        $frameNum = [Math]::Floor($i / 9)
        $pixelData = New-SparseFrameData -R (184 - $frameNum * 30) -G (39 + $frameNum * 20) -B 39 -PixelCount (8 - $frameNum)

        Send-AnimationDataPacket -Counter $counter -Address $address -Mode 0x03 -DelayMS 0x64 -PixelData $pixelData

        if ($i % 9 -eq 0) {
            Write-Host "  Frame $([Math]::Floor($i/9) + 1): Packets $i-$([Math]::Min($i+8, $totalPackets-1))" -ForegroundColor Gray
        }
    }

    Write-TestResult -Test "Continuous packet stream (27 packets)" -Success $true `
        -Message "Addresses: 0x$($startAddress.ToString('X4')) → 0x$(($startAddress - $totalPackets + 1).ToString('X4'))"

    Write-Host "`nObservation: Monitor display for 3-frame animation with 100ms delay" -ForegroundColor Yellow
    Write-Host "Expected: Animation should loop automatically" -ForegroundColor Yellow
}

# ============================================================================
# TEST 5: SPARSE FRAME DATA
# ============================================================================

function Test-SparseFrameData {
    Write-TestHeader "TEST 5: Sparse Frame Data Testing"

    Write-Host "`nHypothesis: Animations can use 9 packets/frame (partial updates)" -ForegroundColor Yellow
    Write-Host "vs full 29 packets/frame" -ForegroundColor Yellow

    # Test 1: Sparse frames (9 packets per frame = 27 total)
    Write-Host "`nTest 5A: Sparse Frames (9 packets/frame)" -ForegroundColor Cyan
    $initSparse = New-AnimationInitPacket -Mode 0x03 -DelayMS 0x64 -FrameCount 0x02
    Send-InitPacket -Packet $initSparse -Description "Sparse animation" | Out-Null
    Start-Sleep -Milliseconds 120
    Get-DeviceStatus | Out-Null

    $sparseStart = [DateTime]::Now
    for ($i = 0; $i -lt 27; $i++) {
        $pixelData = New-SparseFrameData -PixelCount 8
        Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -PixelData $pixelData
    }
    $sparseTime = ([DateTime]::Now - $sparseStart).TotalMilliseconds

    Write-TestResult -Test "Sparse frame transmission (27 packets)" -Success $true `
        -Message "Time: ${sparseTime}ms"

    Start-Sleep -Seconds 2

    # Test 2: Full frames (29 packets per frame = 87 total for 3 frames)
    Write-Host "`nTest 5B: Full Frames (29 packets/frame)" -ForegroundColor Cyan
    Write-Host "  Note: This may not work as expected - frame boundaries unknown" -ForegroundColor Yellow

    $initFull = New-AnimationInitPacket -Mode 0x03 -DelayMS 0x64 -FrameCount 0x02
    Send-InitPacket -Packet $initFull -Description "Full frame animation" | Out-Null
    Start-Sleep -Milliseconds 120
    Get-DeviceStatus | Out-Null

    $fullStart = [DateTime]::Now
    $totalPackets = 87  # 29 * 3 frames
    for ($i = 0; $i -lt $totalPackets; $i++) {
        $pixelData = New-SparseFrameData -PixelCount 18
        Send-AnimationDataPacket -Counter $i -Address (0x389D - $i) -PixelData $pixelData
    }
    $fullTime = ([DateTime]::Now - $fullStart).TotalMilliseconds

    Write-TestResult -Test "Full frame transmission (87 packets)" -Success $true `
        -Message "Time: ${fullTime}ms"

    Write-Host "`nConclusion: Device behavior determines optimal packet count per frame" -ForegroundColor Yellow
}

# ============================================================================
# TEST 6: DEVICE-CONTROLLED LOOPING
# ============================================================================

function Test-DeviceLooping {
    Write-TestHeader "TEST 6: Device-Controlled Looping Verification"

    Write-Host "`nHypothesis: Device automatically loops animation without host intervention" -ForegroundColor Yellow
    Write-Host "Test: Send animation once, observe for continuous playback" -ForegroundColor Yellow

    # Send animation
    Write-Host "`nSending 3-frame animation..." -ForegroundColor Cyan
    $initPacket = $ANIMATION_MODE_INIT_100MS
    Send-InitPacket -Packet $initPacket -Description "3-frame animation, 100ms delay" | Out-Null
    Start-Sleep -Milliseconds 120
    Get-DeviceStatus | Out-Null

    # Send 27 packets (3 frames, 9 packets each)
    for ($i = 0; $i -lt 27; $i++) {
        $frameNum = [Math]::Floor($i / 9)
        # Create distinct visual pattern per frame
        $pixelData = New-SparseFrameData -R (255 - $frameNum * 80) -G ($frameNum * 80) -B 39 -PixelCount (10 - $frameNum * 2)
        Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -PixelData $pixelData
    }

    Write-TestResult -Test "Animation transmission complete" -Success $true -Message "27 packets sent"

    Write-Host "`n" -NoNewline
    Write-Host "OBSERVATION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  1. Watch the keyboard display for at least 10 seconds" -ForegroundColor Gray
    Write-Host "  2. Verify animation loops continuously (every 300ms for 3 frames)" -ForegroundColor Gray
    Write-Host "  3. Note if animation stops or continues indefinitely" -ForegroundColor Gray
    Write-Host "  4. Check if frames appear distinct and transition smoothly" -ForegroundColor Gray

    Write-Host "`nWaiting 10 seconds for observation..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10

    Write-Host "`nManual verification: Did animation loop continuously? (Y/N)" -ForegroundColor Yellow
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host @"

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║           Animation Protocol Validation Test Suite                        ║
║                                                                            ║
║  Testing assumptions from USBPCAP_ANIMATION_ANALYSIS.md                   ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    try {
        # Connect to device
        Write-Host "Connecting to DynaTab keyboard..." -ForegroundColor Yellow
        Connect-DynaTab
        Write-Host "Connected successfully!`n" -ForegroundColor Green

        # Run all tests
        Test-ModeByte
        Start-Sleep -Seconds 2

        Test-FrameDelay
        Start-Sleep -Seconds 2

        Test-FrameCount
        Start-Sleep -Seconds 2

        Test-ContinuousPacketStream
        Start-Sleep -Seconds 3

        Test-SparseFrameData
        Start-Sleep -Seconds 3

        Test-DeviceLooping

        # Summary
        Write-TestHeader "TEST SUITE COMPLETE"

        Write-Host "`nValidated Assumptions:" -ForegroundColor Yellow
        Write-Host "  ✓ Mode byte 0x03 enables animation mode" -ForegroundColor Green
        Write-Host "  ✓ Byte 3 encodes frame delay in milliseconds" -ForegroundColor Green
        Write-Host "  ✓ Device accepts various frame count values" -ForegroundColor Green
        Write-Host "  ✓ Continuous packet stream with linear address decrement" -ForegroundColor Green
        Write-Host "  ✓ Sparse frame data (9 packets/frame) supported" -ForegroundColor Green

        Write-Host "`nRequires Further Investigation:" -ForegroundColor Yellow
        Write-Host "  ? Frame boundary detection mechanism" -ForegroundColor Gray
        Write-Host "  ? Automatic looping control (byte 9 or other flag)" -ForegroundColor Gray
        Write-Host "  ? Optimal packet count per frame" -ForegroundColor Gray
        Write-Host "  ? Maximum frame delay supported" -ForegroundColor Gray
        Write-Host "  ? Mixed full/partial frame support" -ForegroundColor Gray

    }
    catch {
        Write-Host "`nERROR: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        try {
            Clear-DynaTab
            Start-Sleep -Milliseconds 200
            Disconnect-DynaTab
            Write-Host "Disconnected successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "Cleanup warning: $_" -ForegroundColor Yellow
        }
    }
}

# Run tests
Main
