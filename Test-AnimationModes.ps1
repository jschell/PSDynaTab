<#
.SYNOPSIS
    Test animation sparse vs full frame modes

.DESCRIPTION
    Tests mode threshold and bytes 4-5 encoding

.PARAMETER TestThreshold
    Test mode threshold (bytes 4-5: 100, 500, 1000, 1500, 2000)

.PARAMETER TestFormula
    Test full mode formula (frames × 1536)

.PARAMETER TestQuality
    Compare sparse vs full visual quality

.EXAMPLE
    .\Test-AnimationModes.ps1 -TestThreshold
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

function Connect-TestDevice {
    $deviceList = [HidSharp.DeviceList]::Local
    $devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
    $targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

    if ($targetDevice) {
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

function Send-AnimationInit {
    param(
        [byte]$Frames,
        [byte]$DelayMS,
        [uint16]$Bytes45
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[2] = $Frames
    $packet[3] = $DelayMS
    $packet[4] = [byte](($Bytes45 -shr 8) -band 0xFF)
    $packet[5] = [byte]($Bytes45 -band 0xFF)
    $packet[10] = 0x3c
    $packet[11] = 0x09

    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 120
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
    $packet[2] = $Frames
    $packet[3] = $DelayMS
    $packet[4] = $Counter

    if ($PixelData) {
        $len = [Math]::Min($PixelData.Length, 56)
        [Array]::Copy($PixelData, 0, $packet, 8, $len)
    }

    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)
    Start-Sleep -Milliseconds 5
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
        for ($f = 0; $f -lt 3; $f++) {
            $pixel = New-Object byte[] 56
            $pixel[0] = 0x00
            $pixel[1] = 0xFF
            $pixel[2] = 0x00
            Send-DataPacket -FrameIndex $f -Counter 0 -Frames 3 -DelayMS 100 -PixelData $pixel
        }

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

        # Send full frame data (29 packets per frame)
        for ($f = 0; $f -lt $test.Frames; $f++) {
            for ($p = 0; $p -lt 29; $p++) {
                $pixel = New-Object byte[] 56
                # Fill with green gradient
                for ($i = 0; $i -lt 18; $i++) {
                    $pixel[$i*3 + 1] = 255 - ($f * 10)
                }
                Send-DataPacket -FrameIndex $f -Counter $p -Frames $test.Frames -DelayMS 100 -PixelData $pixel
            }
        }

        $result = Read-Host "Did $($test.Frames)-frame animation display? (Y/N)"
        Write-Host "Result: $result`n" -ForegroundColor $(if ($result -eq 'Y') { 'Green' } else { 'Red' })

        Start-Sleep -Seconds 2
    }
}

function Test-QualityComparison {
    Write-Host "`n=== Quality Comparison Test ===" -ForegroundColor Cyan
    Write-Host "Same animation sent as sparse vs full mode`n"

    # Test animation: 3 frames, 50 pixels per frame

    Write-Host "Test 1: Sparse mode (bytes 4-5 = 150)" -ForegroundColor Yellow
    Send-AnimationInit -Frames 3 -DelayMS 100 -Bytes45 150

    # Send 1 packet per frame (50 pixels = ~28 bytes)
    for ($f = 0; $f -lt 3; $f++) {
        $pixel = New-Object byte[] 56
        for ($i = 0; $i -lt 16; $i++) {
            $pixel[$i*3] = 255 - ($f * 80)
            $pixel[$i*3 + 1] = $f * 80
            $pixel[$i*3 + 2] = 100
        }
        Send-DataPacket -FrameIndex $f -Counter 0 -Frames 3 -DelayMS 100 -PixelData $pixel
    }

    Read-Host "Observe sparse mode quality - press Enter to continue"

    Start-Sleep -Seconds 2

    Write-Host "`nTest 2: Full mode (bytes 4-5 = 4608 = 3×1536)" -ForegroundColor Yellow
    Send-AnimationInit -Frames 3 -DelayMS 100 -Bytes45 4608

    # Send 29 packets per frame
    for ($f = 0; $f -lt 3; $f++) {
        for ($p = 0; $p -lt 29; $p++) {
            $pixel = New-Object byte[] 56
            if ($p -eq 0) {
                # Same pixel data as sparse mode
                for ($i = 0; $i -lt 16; $i++) {
                    $pixel[$i*3] = 255 - ($f * 80)
                    $pixel[$i*3 + 1] = $f * 80
                    $pixel[$i*3 + 2] = 100
                }
            }
            Send-DataPacket -FrameIndex $f -Counter $p -Frames 3 -DelayMS 100 -PixelData $pixel
        }
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
