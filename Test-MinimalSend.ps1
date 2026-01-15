#Requires -Version 5.1

<#
.SYNOPSIS
    Minimal test - sends only initialization + one red packet
.DESCRIPTION
    Tests the absolute minimum communication to see if device responds
#>

Write-Host "`n=== Minimal Send Test ===" -ForegroundColor Cyan

Import-Module PSDynaTab -Force

try {
    # Connect
    Write-Host "Connecting..." -ForegroundColor Yellow
    Connect-DynaTab -Verbose

    # Wait a moment
    Start-Sleep -Milliseconds 500

    # Create a single packet with first 9 pixels (first column) red
    Write-Host "`nCreating test packet..." -ForegroundColor Yellow
    $testPacket = New-Object byte[] 64

    # Header
    $testPacket[0] = 0x29  # Fixed header
    $testPacket[1] = 0x00  # Frame index
    $testPacket[2] = 0x01  # Image mode
    $testPacket[3] = 0x00  # Fixed
    $testPacket[4] = 0x00  # Incrementing (LSB)
    $testPacket[5] = 0x00  # Incrementing (MSB)
    $testPacket[6] = 0x38  # Decrementing (MSB) = 0x389D
    $testPacket[7] = 0x9D  # Decrementing (LSB)

    # First column pixels (9 pixels, each RGB = FF 00 00 for red)
    for ($i = 0; $i -lt 9; $i++) {
        $testPacket[8 + ($i * 3)] = 0xFF      # R
        $testPacket[8 + ($i * 3) + 1] = 0x00  # G
        $testPacket[8 + ($i * 3) + 2] = 0x00  # B
    }

    # Remaining bytes are already 0x00

    # Display packet
    Write-Host "Packet bytes (first 35):" -ForegroundColor Gray
    for ($i = 0; $i -lt 35; $i++) {
        if ($i % 16 -eq 0) { Write-Host "" }
        Write-Host ("{0:X2} " -f $testPacket[$i]) -NoNewline -ForegroundColor $(if ($i -lt 8) { 'Cyan' } elseif ($testPacket[$i] -ne 0) { 'Green' } else { 'Gray' })
    }
    Write-Host "`n"

    # Wrap in feature report
    $featureReport = New-Object byte[] 65
    $featureReport[0] = 0x00  # Report ID
    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $testPacket[$i]
    }

    # Send using SetFeature
    Write-Host "Sending packet via SetFeature..." -ForegroundColor Yellow
    Write-Host ">>> WATCH THE DISPLAY - Should show one red column <<<" -ForegroundColor Magenta

    $script:HIDStream.SetFeature($featureReport)

    Write-Host "✓ Packet sent" -ForegroundColor Green

    # Wait
    Start-Sleep -Seconds 3

    Write-Host "`nDid you see a red column? (y/n): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host

    if ($response -eq 'y') {
        Write-Host "✓ Minimal send works! Issue is in multi-packet sequence" -ForegroundColor Green
    } else {
        Write-Host "✗ Even minimal send failed. Trying GetFeature to check device state..." -ForegroundColor Red

        # Try reading back from device
        try {
            Write-Host "`nAttempting to read feature report..." -ForegroundColor Yellow
            $readBuffer = New-Object byte[] 65
            $readBuffer[0] = 0x00  # Report ID

            $bytesRead = $script:HIDStream.GetFeature($readBuffer)

            Write-Host "Read $bytesRead bytes:" -ForegroundColor Gray
            for ($i = 0; $i -lt [Math]::Min(16, $bytesRead); $i++) {
                Write-Host ("{0:X2} " -f $readBuffer[$i]) -NoNewline -ForegroundColor Gray
            }
            Write-Host ""
        } catch {
            Write-Host "GetFeature failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

} finally {
    Write-Host "`nDisconnecting..." -ForegroundColor Gray
    Disconnect-DynaTab
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
