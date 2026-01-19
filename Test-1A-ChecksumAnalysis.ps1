<#
.SYNOPSIS
    Phase 1, Test 1A: Checksum Algorithm Reverse Engineering

.DESCRIPTION
    Systematically varies init packet bytes to discover checksum calculation for byte 7.

    Tests performed:
    - 1A-1: Delay variation (byte 3)
    - 1A-2: Frame count variation (byte 2)
    - 1A-3: Bytes 4-5 variation
    - 1A-4: Bytes 8-9 variation

.PARAMETER TestAll
    Run all test variations

.PARAMETER Test1
    Run delay variation test only

.PARAMETER Test2
    Run frame count variation test only

.PARAMETER Test3
    Run bytes 4-5 variation test only

.PARAMETER Test4
    Run bytes 8-9 variation test only

.EXAMPLE
    .\Test-1A-ChecksumAnalysis.ps1 -TestAll
    Run all checksum analysis tests

.NOTES
    Requirements:
    - DynaTab 75X connected
    - HidSharp.dll in PSDynaTab\lib\
    - USB capture tool running (optional but recommended)

    Output:
    - Test-1A-Results.csv: All test results
    - Console: Real-time test progress
#>

param(
    [switch]$TestAll,
    [switch]$Test1,
    [switch]$Test2,
    [switch]$Test3,
    [switch]$Test4
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
$script:Results = @()

# Output file
$ResultsFile = Join-Path $PSScriptRoot "Test-1A-Results.csv"

function Connect-TestDevice {
    $deviceList = [HidSharp.DeviceList]::Local
    $devices = $deviceList.GetHidDevices($DEVICE_VID, $DEVICE_PID)
    $targetDevice = $devices | Where-Object { $_.DevicePath -match "mi_0*$($INTERFACE_INDEX - 1)" } | Select-Object -First 1

    if ($targetDevice) {
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

function Send-TestPacket {
    param(
        [byte[]]$PacketData,
        [string]$TestName,
        [string]$Description
    )

    try {
        # Prepare feature report (65 bytes: 1 byte report ID + 64 bytes data)
        $featureReport = New-Object byte[] 65
        [Array]::Copy($PacketData, 0, $featureReport, 1, 64)

        # Send packet
        $script:TestHIDStream.SetFeature($featureReport)
        Start-Sleep -Milliseconds 120

        # Get response (optional, for debugging)
        $response = New-Object byte[] 65
        try {
            $script:TestHIDStream.GetFeature($response)
        } catch {
            # Get_Report may fail, not critical for this test
        }

        # Log result
        $result = [PSCustomObject]@{
            TestName = $TestName
            Description = $Description
            Byte0 = "0x{0:X2}" -f $PacketData[0]
            Byte1 = "0x{0:X2}" -f $PacketData[1]
            Byte2 = "0x{0:X2}" -f $PacketData[2]
            Byte3 = "0x{0:X2}" -f $PacketData[3]
            Byte4 = "0x{0:X2}" -f $PacketData[4]
            Byte5 = "0x{0:X2}" -f $PacketData[5]
            Byte6 = "0x{0:X2}" -f $PacketData[6]
            Byte7 = "0x{0:X2}" -f $PacketData[7]
            Byte8 = "0x{0:X2}" -f $PacketData[8]
            Byte9 = "0x{0:X2}" -f $PacketData[9]
            Byte10 = "0x{0:X2}" -f $PacketData[10]
            Byte11 = "0x{0:X2}" -f $PacketData[11]
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }

        $script:Results += $result
        Write-Host "  $Description : Byte7 = 0x$($PacketData[7].ToString('X2'))" -ForegroundColor Cyan

        return $true
    }
    catch {
        Write-Warning "Failed to send packet: $_"
        return $false
    }
}

function Test-1A-1-DelayVariation {
    Write-Host "`n=== Test 1A-1: Delay Variation (Byte 3) ===" -ForegroundColor Yellow
    Write-Host "Objective: Observe byte 7 pattern when delay varies"
    Write-Host ""

    # Base packet from working capture (Variant B, 3 frames, 100ms)
    $baseInit = New-Object byte[] 64
    $baseInit[0] = 0xa9   # Init packet
    $baseInit[1] = 0x00   # Reserved
    $baseInit[2] = 0x03   # 3 frames
    $baseInit[3] = 0x64   # 100ms delay (will vary)
    $baseInit[4] = 0x44   # Bytes 4-5 from Variant B
    $baseInit[5] = 0x01
    $baseInit[6] = 0x00   # Will observe byte 7
    $baseInit[7] = 0xAB   # Known working value for 100ms
    $baseInit[8] = 0x01   # Variant B flags
    $baseInit[9] = 0x00
    $baseInit[10] = 0x0d  # Start address
    $baseInit[11] = 0x09

    # Test delays: 0, 50, 75, 100, 150, 200, 250, 255 ms
    $delays = @(0x00, 0x32, 0x4B, 0x64, 0x96, 0xC8, 0xFA, 0xFF)

    foreach ($delay in $delays) {
        $testInit = $baseInit.Clone()
        $testInit[3] = $delay
        # Keep byte 7 at 0x00 to see if device accepts, or use calculated value later
        $testInit[7] = 0x00

        $delayMs = [int]$delay
        Send-TestPacket -PacketData $testInit -TestName "1A-1" -Description "Delay=${delayMs}ms"
        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nTest 1A-1 complete. Check results for byte 7 pattern." -ForegroundColor Green
}

function Test-1A-2-FrameCountVariation {
    Write-Host "`n=== Test 1A-2: Frame Count Variation (Byte 2) ===" -ForegroundColor Yellow
    Write-Host "Objective: Observe byte 7 pattern when frame count varies"
    Write-Host ""

    # Base packet
    $baseInit = New-Object byte[] 64
    $baseInit[0] = 0xa9
    $baseInit[1] = 0x00
    $baseInit[2] = 0x03   # Will vary
    $baseInit[3] = 0x64   # 100ms delay
    $baseInit[4] = 0x44
    $baseInit[5] = 0x01
    $baseInit[6] = 0x00
    $baseInit[7] = 0x00
    $baseInit[8] = 0x01
    $baseInit[9] = 0x00
    $baseInit[10] = 0x0d
    $baseInit[11] = 0x09

    # Test frame counts: 1, 2, 3, 4, 5
    $frameCounts = @(0x01, 0x02, 0x03, 0x04, 0x05)

    foreach ($frames in $frameCounts) {
        $testInit = $baseInit.Clone()
        $testInit[2] = $frames

        Send-TestPacket -PacketData $testInit -TestName "1A-2" -Description "Frames=$frames"
        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nTest 1A-2 complete. Check results for byte 7 pattern." -ForegroundColor Green
}

function Test-1A-3-Bytes45Variation {
    Write-Host "`n=== Test 1A-3: Bytes 4-5 Variation ===" -ForegroundColor Yellow
    Write-Host "Objective: Observe byte 7 pattern when bytes 4-5 vary"
    Write-Host ""

    # Base packet
    $baseInit = New-Object byte[] 64
    $baseInit[0] = 0xa9
    $baseInit[1] = 0x00
    $baseInit[2] = 0x03
    $baseInit[3] = 0x64
    $baseInit[4] = 0x44   # Will vary
    $baseInit[5] = 0x01   # Will vary
    $baseInit[6] = 0x00
    $baseInit[7] = 0x00
    $baseInit[8] = 0x01
    $baseInit[9] = 0x00
    $baseInit[10] = 0x0d
    $baseInit[11] = 0x09

    # Test values from known variants
    $bytes45Values = @(
        @{Value = 0x0000; Name = "Zero"},
        @{Value = 0x0036; Name = "Variant C (54)"},
        @{Value = 0x0144; Name = "Variant B (324)"},
        @{Value = 0x0654; Name = "Variant D (1620)"},
        @{Value = 0xFFFF; Name = "Max"}
    )

    foreach ($test in $bytes45Values) {
        $testInit = $baseInit.Clone()
        $testInit[4] = [byte]($test.Value -band 0xFF)
        $testInit[5] = [byte](($test.Value -shr 8) -band 0xFF)

        Send-TestPacket -PacketData $testInit -TestName "1A-3" -Description "Bytes4-5=$($test.Name)"
        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nTest 1A-3 complete. Check results for byte 7 pattern." -ForegroundColor Green
}

function Test-1A-4-Bytes89Variation {
    Write-Host "`n=== Test 1A-4: Bytes 8-9 Variation ===" -ForegroundColor Yellow
    Write-Host "Objective: Observe byte 7 pattern when bytes 8-9 vary"
    Write-Host ""

    # Base packet
    $baseInit = New-Object byte[] 64
    $baseInit[0] = 0xa9
    $baseInit[1] = 0x00
    $baseInit[2] = 0x03
    $baseInit[3] = 0x64
    $baseInit[4] = 0x44
    $baseInit[5] = 0x01
    $baseInit[6] = 0x00
    $baseInit[7] = 0x00
    $baseInit[8] = 0x01   # Will vary
    $baseInit[9] = 0x00   # Will vary
    $baseInit[10] = 0x0d
    $baseInit[11] = 0x09

    # Test variant flags
    $bytes89Values = @(
        @{Value = 0x0000; Name = "Variant C/D"},
        @{Value = 0x0100; Name = "Variant B"},
        @{Value = 0x0200; Name = "Variant A"}
    )

    foreach ($test in $bytes89Values) {
        $testInit = $baseInit.Clone()
        $testInit[8] = [byte]($test.Value -band 0xFF)
        $testInit[9] = [byte](($test.Value -shr 8) -band 0xFF)

        Send-TestPacket -PacketData $testInit -TestName "1A-4" -Description "Bytes8-9=$($test.Name)"
        Start-Sleep -Milliseconds 500
    }

    Write-Host "`nTest 1A-4 complete. Check results for byte 7 pattern." -ForegroundColor Green
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
    Write-Host "1. Open Test-1A-Results.csv in Excel or similar"
    Write-Host "2. Look for patterns in Byte7 column:"
    Write-Host "   - Does it change with Byte3 (delay)?"
    Write-Host "   - Does it change with Byte2 (frames)?"
    Write-Host "   - Does it change with Bytes4-5?"
    Write-Host "   - Does it change with Bytes8-9?"
    Write-Host ""
    Write-Host "3. Test hypotheses:"
    Write-Host "   - XOR of all bytes 0-6?"
    Write-Host "   - Sum with wraparound?"
    Write-Host "   - Complement of specific byte?"
    Write-Host "   - CRC-8 calculation?"
    Write-Host ""
    Write-Host "4. Once pattern identified, validate:"
    Write-Host "   - Calculate byte 7 using formula"
    Write-Host "   - Send new packet with calculated checksum"
    Write-Host "   - Verify animation displays correctly"
    Write-Host ""
}

# Main execution
try {
    Write-Host "=== Phase 1, Test 1A: Checksum Algorithm Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Connect-TestDevice)) {
        exit 1
    }

    $runAll = $TestAll -or (-not ($Test1 -or $Test2 -or $Test3 -or $Test4))

    if ($Test1 -or $runAll) { Test-1A-1-DelayVariation }
    if ($Test2 -or $runAll) { Test-1A-2-FrameCountVariation }
    if ($Test3 -or $runAll) { Test-1A-3-Bytes45Variation }
    if ($Test4 -or $runAll) { Test-1A-4-Bytes89Variation }

    Export-Results
    Show-AnalysisGuidance
}
finally {
    Disconnect-TestDevice
}
