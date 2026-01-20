<#
.SYNOPSIS
    Phase 1, Test 1B: Variant Selection Rules Discovery

.DESCRIPTION
    Tests how bytes 4-5 and 8-9 determine animation variant (packet count per frame).

    Known variants:
    - Variant A: 9 packets/frame (Epomaker official)
    - Variant B: 6 packets/frame (33% faster)
    - Variant C: 1 packet/frame (9× faster)
    - Variant D: 29 packets/frame (full frame)

.PARAMETER TestAll
    Run all variant selection tests

.EXAMPLE
    .\Test-1B-VariantSelection.ps1 -TestAll
    Test all byte combinations to determine variant selection

.NOTES
    Requirements:
    - DynaTab 75X connected
    - HidSharp.dll in PSDynaTab\lib\
    - Visual observation required to count packets needed

    Output:
    - Test-1B-Results.csv: Test configurations and observations
    - Console: Real-time test progress and packet count prompts
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
$script:CurrentAddress = 0x3836

# Output file
$ResultsFile = Join-Path $PSScriptRoot "Test-1B-Results.csv"

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

function Send-InitPacket {
    param(
        [uint16]$Bytes45,
        [uint16]$Bytes89,
        [byte]$FrameCount = 3,
        [byte]$Delay = 100
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x00
    $packet[2] = $FrameCount
    $packet[3] = $Delay
    $packet[4] = [byte]($Bytes45 -band 0xFF)
    $packet[5] = [byte](($Bytes45 -shr 8) -band 0xFF)
    $packet[6] = 0x00  # Checksum (unknown)
    $packet[7] = 0x00  # Checksum (unknown)
    $packet[8] = [byte]($Bytes89 -band 0xFF)
    $packet[9] = [byte](($Bytes89 -shr 8) -band 0xFF)
    $packet[10] = 0x0d  # Start address (little-endian)
    $packet[11] = 0x09

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

    # Reset address for data packets
    $script:CurrentAddress = 0x3836
}

function Send-DataPacket {
    param(
        [byte]$FrameIndex,
        [byte]$PacketCounter,
        [byte]$FrameCount,
        [byte]$Delay
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0x29
    $packet[1] = $FrameIndex
    $packet[2] = $FrameCount
    $packet[3] = $Delay
    $packet[4] = $PacketCounter
    $packet[5] = 0x00

    # Memory address (big-endian, decrements)
    $packet[6] = [byte](($script:CurrentAddress -shr 8) -band 0xFF)
    $packet[7] = [byte]($script:CurrentAddress -band 0xFF)
    $script:CurrentAddress--

    # Fill with test pixel data (single green pixel)
    $packet[8] = 0x00  # R
    $packet[9] = 0xFF  # G
    $packet[10] = 0x00 # B

    # Send data packet
    $featureReport = New-Object byte[] 65
    [Array]::Copy($packet, 0, $featureReport, 1, 64)
    $script:TestHIDStream.SetFeature($featureReport)

    Start-Sleep -Milliseconds 2
}

function Test-VariantConfiguration {
    param(
        [uint16]$Bytes45,
        [uint16]$Bytes89,
        [string]$TestName,
        [string]$ExpectedVariant,
        [int]$ExpectedPacketsPerFrame
    )

    Write-Host "`n--- $TestName ---" -ForegroundColor Cyan
    Write-Host "  Bytes 4-5: 0x$($Bytes45.ToString('X4'))" -ForegroundColor White
    Write-Host "  Bytes 8-9: 0x$($Bytes89.ToString('X4'))" -ForegroundColor White
    Write-Host "  Expected: $ExpectedVariant ($ExpectedPacketsPerFrame pkt/frame)" -ForegroundColor Yellow
    Write-Host ""

    # Send init packet
    Send-InitPacket -Bytes45 $Bytes45 -Bytes89 $Bytes89 -FrameCount 3 -Delay 100

    # Send minimal data packets to test
    # Try sending expected packet count for 3 frames
    $totalPackets = $ExpectedPacketsPerFrame * 3
    $packetCounter = 0

    for ($frame = 0; $frame -lt 3; $frame++) {
        for ($pkt = 0; $pkt -lt $ExpectedPacketsPerFrame; $pkt++) {
            Send-DataPacket -FrameIndex $frame -PacketCounter $packetCounter -FrameCount 3 -Delay 100
            $packetCounter++
        }
    }

    Write-Host "  Sent $totalPackets packets total ($ExpectedPacketsPerFrame × 3 frames)" -ForegroundColor Green
    Write-Host ""
    $worked = Read-Host "  Did animation display correctly? (Y/N)"

    # If it didn't work, ask for actual packet count needed
    $actualPackets = $ExpectedPacketsPerFrame
    if ($worked -ne 'Y') {
        Write-Host "  Animation did not work as expected." -ForegroundColor Yellow
        $actualInput = Read-Host "  How many packets per frame would work? (guess or test)"
        if ($actualInput) {
            $actualPackets = [int]$actualInput
        }
    }

    # Log result
    $result = [PSCustomObject]@{
        TestName = $TestName
        Bytes45 = "0x{0:X4}" -f $Bytes45
        Bytes89 = "0x{0:X4}" -f $Bytes89
        ExpectedVariant = $ExpectedVariant
        ExpectedPacketsPerFrame = $ExpectedPacketsPerFrame
        Worked = $worked
        ActualPacketsPerFrame = $actualPackets
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $script:Results += $result

    Start-Sleep -Seconds 2
}

function Run-AllTests {
    Write-Host "`n=== Test 1B: Variant Selection Rules ===" -ForegroundColor Yellow
    Write-Host "Objective: Determine how bytes 4-5 and 8-9 select animation variant"
    Write-Host ""

    # Test known working configurations
    Test-VariantConfiguration -Bytes45 0x0144 -Bytes89 0x0100 -TestName "1B-1_VariantB" -ExpectedVariant "Variant B" -ExpectedPacketsPerFrame 6

    Test-VariantConfiguration -Bytes45 0x0036 -Bytes89 0x0000 -TestName "1B-2_VariantC" -ExpectedVariant "Variant C" -ExpectedPacketsPerFrame 1

    Test-VariantConfiguration -Bytes45 0x0654 -Bytes89 0x0000 -TestName "1B-3_VariantD" -ExpectedVariant "Variant D" -ExpectedPacketsPerFrame 29

    # Test unknowns - what happens if we mix?
    Test-VariantConfiguration -Bytes45 0x0144 -Bytes89 0x0000 -TestName "1B-4_Mixed" -ExpectedVariant "Unknown" -ExpectedPacketsPerFrame 6

    Test-VariantConfiguration -Bytes45 0x0036 -Bytes89 0x0100 -TestName "1B-5_Mixed" -ExpectedVariant "Unknown" -ExpectedPacketsPerFrame 1

    # Test zeros
    Test-VariantConfiguration -Bytes45 0x0000 -Bytes89 0x0000 -TestName "1B-6_AllZero" -ExpectedVariant "Unknown" -ExpectedPacketsPerFrame 29

    # Test max values
    Test-VariantConfiguration -Bytes45 0xFFFF -Bytes89 0x0000 -TestName "1B-7_MaxBytes45" -ExpectedVariant "Unknown" -ExpectedPacketsPerFrame 29

    Test-VariantConfiguration -Bytes45 0x0000 -Bytes89 0x0200 -TestName "1B-8_VariantA_Bytes89" -ExpectedVariant "Variant A?" -ExpectedPacketsPerFrame 9
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
    Write-Host "1. Open Test-1B-Results.csv"
    Write-Host "2. Look for pattern:"
    Write-Host "   - Which byte controls variant? Bytes 4-5 or 8-9?"
    Write-Host "   - Is it a lookup table or calculation?"
    Write-Host "   - Can variants be mixed?"
    Write-Host ""
    Write-Host "3. Decision tree to document:"
    Write-Host "   - If bytes X-Y = value, then variant = ?"
    Write-Host "   - What's the relationship to packet count?"
    Write-Host ""
    Write-Host "4. Next steps:"
    Write-Host "   - Document variant selection rules"
    Write-Host "   - Create function to calculate correct bytes 4-5, 8-9"
    Write-Host "   - Update DYNATAB_PROTOCOL_SPECIFICATION.md"
    Write-Host ""
}

# Main execution
try {
    Write-Host "=== Phase 1, Test 1B: Variant Selection Analysis ===" -ForegroundColor Cyan
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
