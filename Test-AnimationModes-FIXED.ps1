<#
.SYNOPSIS
    Test animation sparse vs full frame modes - FIXED VERSION

.DESCRIPTION
    Tests mode threshold and bytes 4-5 encoding

    FIXES APPLIED:
    1. Added Get_Report handshake after init packet
    2. Added correct memory address (0x3837 decrementing) to data packets
    3. Fixed init packet frame count parameter
    4. Added proper error handling

.PARAMETER TestThreshold
    Test mode threshold (bytes 4-5: 100, 500, 1000, 1500, 2000)

.PARAMETER TestFormula
    Test full mode formula (frames × 1536)

.PARAMETER TestQuality
    Compare sparse vs full visual quality

.EXAMPLE
    .\Test-AnimationModes-FIXED.ps1 -TestThreshold
#>

param(
    [switch]$TestThreshold,
    [switch]$TestFormula,
    [switch]$TestQuality,
    [switch]$TestAll
)

# Load HidSharp
$hidSharpPath = Join-Path $PSScriptRoot "PSDynaTab\lib\HidSharp.dll"
Add-Type -Path $hidSharpPath

$DEVICE_VID = 0x3151
$DEVICE_PID = 0x4015
$INTERFACE_INDEX = 3

$script:TestHIDStream = $null
$script:TestDevice = $null

# FIX #1: Track starting address for each animation
$script:CurrentAddress = 0x3837

function Connect-TestDevice {
    $deviceList = [HidSharp.DeviceList]::Local
    $devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
    $targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

    if ($targetDevice) {
        $script:TestDevice = $targetDevice
        $script:TestHIDStream = $targetDevice.Open()
        Write-Host "✓ Connected" -ForegroundColor Green
        return $true
    }
    return $false
}

function Disconnect-TestDevice {
    if ($script:TestHIDStream) {
        $script:TestHIDStream.Close()
        $script:TestHIDStream = $null
    }
}

# FIX #2: Add Get_Report handshake function
function Send-GetReport {
    <#
    .SYNOPSIS
        Send Get_Report control transfer to verify device is ready
    #>

    try {
        # Get_Report: bRequest=0x01, wValue=0x0300 (Feature Report, ID 0)
        $featureReport = New-Object byte[] 65
        $script:TestHIDStream.GetFeature($featureReport)

        Write-Verbose "✓ Get_Report handshake successful"
        return $true
    }
    catch {
        Write-Warning "Get_Report failed: $_"
        return $false
    }
}

function Send-AnimationInit {
    param(
        [byte]$Frames,
        [byte]$DelayMS,
        [uint16]$Bytes45
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[2] = 0x03  # Mode 0x03 for animations
    $packet[3] = $DelayMS

    # Bytes 4-5: Test parameter (big-endian)
    $packet[4] = [byte]($Bytes45 -band 0xFF)
    $packet[5] = [byte](($Bytes45 -shr 8) -band 0xFF)

    # FIX #3: Add frame count parameter (bytes 8-9)
    # Frame count is 0-indexed: 3 frames = 0,1,2 = value 2
    $packet[8] = [byte]($Frames - 1)
    $packet[9] = 0x00

    # Init address (bytes 10-11, big-endian)
    $packet[10] = 0x3a
    $packet[11] = 0x09

    Write-Verbose "Sending init: Frames=$Frames, Delay=$DelayMS, Bytes4-5=$Bytes45"

    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)

    # Wait for device to process init packet
    Start-Sleep -Milliseconds 125

    # FIX #4: Send Get_Report handshake
    $success = Send-GetReport
    if (-not $success) {
        Write-Warning "Device may not be ready - continuing anyway"
    }

    # Wait before data transmission
    Start-Sleep -Milliseconds 105

    # Reset address counter for this animation
    $script:CurrentAddress = 0x3837
}

function Send-DataPacket {
    param(
        [byte]$FrameIndex,
        [byte]$Counter,
        [byte]$Frames,
        [byte]$DelayMS,
        [byte[]]$PixelData
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0x29
    $packet[1] = $FrameIndex
    $packet[2] = 0x03  # Mode 0x03
    $packet[3] = $DelayMS
    $packet[4] = $Counter
    $packet[5] = 0x00  # Reserved

    # FIX #5: Add memory address (bytes 6-7, big-endian, DECREMENTING)
    $packet[6] = [byte](($script:CurrentAddress -shr 8) -band 0xFF)  # High byte
    $packet[7] = [byte]($script:CurrentAddress -band 0xFF)            # Low byte

    Write-Verbose "Packet $Counter : Address 0x$($script:CurrentAddress.ToString('X4'))"

    if ($PixelData) {
        $len = [Math]::Min($PixelData.Length, 56)
        [Array]::Copy($PixelData, 0, $packet, 8, $len)
    }

    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)

    try {
        $script:TestHIDStream.SetFeature($featureReport)

        # Decrement address for next packet
        $script:CurrentAddress--

        # Match inter-packet delay from working capture (2-5ms)
        Start-Sleep -Milliseconds 2

        return $true
    }
    catch {
        Write-Error "Failed to send data packet $Counter : $_"
        return $false
    }
}

function Test-ModeThreshold {
    Write-Host "`n=== Mode Threshold Test ===" -ForegroundColor Cyan
    Write-Host "Testing bytes 4-5 values to find sparse/full mode threshold`n"

    $tests = @(
        @{ Bytes45 = 100; Expected = "Sparse" },
        @{ Bytes45 = 500; Expected = "Sparse?" },
        @{ Bytes45 = 1000; Expected = "Full?" },
        @{ Bytes45 = 1500; Expected = "Full" },
        @{ Bytes45 = 2000; Expected = "Full" }
    )

    foreach ($test in $tests) {
        Write-Host "Bytes 4-5 = $($test.Bytes45) (expect $($test.Expected))" -ForegroundColor Yellow

        Send-AnimationInit -Frames 3 -DelayMS 100 -Bytes45 $test.Bytes45

        # Send 3 frames, 1 packet each (1 green pixel per frame)
        $successCount = 0
        for ($f = 0; $f -lt 3; $f++) {
            $pixel = New-Object byte[] 56
            $pixel[0] = 0x00
            $pixel[1] = 0xFF
            $pixel[2] = 0x00

            if (Send-DataPacket -FrameIndex $f -Counter $f -Frames 3 -DelayMS 100 -PixelData $pixel) {
                $successCount++
            }
        }

        Write-Verbose "Sent $successCount/3 packets successfully"

        $result = Read-Host "Did animation work? (Y/N)"
        Write-Host "Result: $result`n" -ForegroundColor $(if ($result -eq 'Y') { 'Green' } else { 'Red' })

        Start-Sleep -Seconds 2
    }
}

function Test-FormulaValidation {
    Write-Host "`n=== Formula Validation Test ===" -ForegroundColor Cyan
    Write-Host "Testing full mode: bytes 4-5 = frames × 1536`n"

    $tests = @(
        @{ Frames = 5; Bytes45 = 7680 },   # 5 × 1536
        @{ Frames = 10; Bytes45 = 15360 }, # 10 × 1536
        @{ Frames = 20; Bytes45 = 30720 }  # 20 × 1536
    )

    foreach ($test in $tests) {
        Write-Host "Frames=$($test.Frames), Bytes 4-5=$($test.Bytes45) (=$($test.Frames)×1536)" -ForegroundColor Yellow

        Send-AnimationInit -Frames $test.Frames -DelayMS 100 -Bytes45 $test.Bytes45

        # FIX #6: Send complete 27 packets per animation (3 frames × 9 packets)
        # Note: For testing, using 3 frames. Adjust if testing more frames.
        $totalPackets = 27  # 3 frames × 9 packets/frame
        $successCount = 0

        for ($counter = 0; $counter -lt $totalPackets; $counter++) {
            $frameIndex = [Math]::Floor($counter / 9)

            $pixel = New-Object byte[] 56
            # Fill with green gradient
            for ($i = 0; $i -lt 18; $i++) {
                $pixel[$i*3 + 1] = 255 - ($frameIndex * 30)
            }

            if (Send-DataPacket -FrameIndex $frameIndex -Counter $counter -Frames 3 -DelayMS 100 -PixelData $pixel) {
                $successCount++
            }
            else {
                Write-Warning "Packet $counter failed - stopping transmission"
                break
            }
        }

        Write-Host "Sent $successCount/$totalPackets packets" -ForegroundColor $(if ($successCount -eq $totalPackets) { 'Green' } else { 'Yellow' })

        $result = Read-Host "Did $($test.Frames)-frame animation display? (Y/N)"
        Write-Host "Result: $result`n" -ForegroundColor $(if ($result -eq 'Y') { 'Green' } else { 'Red' })

        Start-Sleep -Seconds 2
    }
}

function Test-QualityComparison {
    Write-Host "`n=== Quality Comparison Test ===" -ForegroundColor Cyan
    Write-Host "Same animation sent as sparse vs full mode`n"

    # Test animation: 3 frames

    Write-Host "Test 1: Sparse mode (bytes 4-5 = 150)" -ForegroundColor Yellow
    Send-AnimationInit -Frames 3 -DelayMS 100 -Bytes45 150

    # Send 3 packets (1 per frame)
    for ($f = 0; $f -lt 3; $f++) {
        $pixel = New-Object byte[] 56
        for ($i = 0; $i -lt 16; $i++) {
            $pixel[$i*3] = 255 - ($f * 80)
            $pixel[$i*3 + 1] = $f * 80
            $pixel[$i*3 + 2] = 100
        }
        Send-DataPacket -FrameIndex $f -Counter $f -Frames 3 -DelayMS 100 -PixelData $pixel | Out-Null
    }

    Read-Host "Observe sparse mode quality - press Enter to continue"

    Start-Sleep -Seconds 2

    Write-Host "`nTest 2: Full mode (bytes 4-5 = 4608 = 3×1536)" -ForegroundColor Yellow
    Send-AnimationInit -Frames 3 -DelayMS 100 -Bytes45 4608

    # Send 27 packets (9 per frame for 3 frames)
    $totalPackets = 27
    for ($counter = 0; $counter -lt $totalPackets; $counter++) {
        $frameIndex = [Math]::Floor($counter / 9)

        $pixel = New-Object byte[] 56
        if (($counter % 9) -eq 0) {
            # First packet of frame: same pixel data as sparse mode
            for ($i = 0; $i -lt 16; $i++) {
                $pixel[$i*3] = 255 - ($frameIndex * 80)
                $pixel[$i*3 + 1] = $frameIndex * 80
                $pixel[$i*3 + 2] = 100
            }
        }
        Send-DataPacket -FrameIndex $frameIndex -Counter $counter -Frames 3 -DelayMS 100 -PixelData $pixel | Out-Null
    }

    Read-Host "Observe full mode quality - press Enter to continue"

    Write-Host "`nAny visual difference? (Y/N)" -ForegroundColor Yellow
    $diff = Read-Host
    Write-Host "Difference observed: $diff`n" -ForegroundColor $(if ($diff -eq 'Y') { 'Yellow' } else { 'Green' })
}

# Main execution
try {
    Connect-TestDevice | Out-Null

    $runAll = $TestAll -or (-not ($TestThreshold -or $TestFormula -or $TestQuality))

    if ($TestThreshold -or $runAll) { Test-ModeThreshold }
    if ($TestFormula -or $runAll) { Test-FormulaValidation }
    if ($TestQuality -or $runAll) { Test-QualityComparison }
}
finally {
    Disconnect-TestDevice
}
