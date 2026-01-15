# Test-ReinitTiming.ps1
# Tests different delays after reinit to see when display shows

Import-Module ./PSDynaTab/PSDynaTab.psd1 -Force
Connect-DynaTab

# Create red pixel data
$pixelData = New-Object byte[] 1620
for ($i = 0; $i -lt 1620; $i += 3) {
    $pixelData[$i] = 255    # R
    $pixelData[$i+1] = 0    # G
    $pixelData[$i+2] = 0    # B
}

Write-Host "`nTesting different delays AFTER reinit (before image packets)..."
Write-Host "=========================================================`n"

# Test different delays after reinit
foreach ($delayMs in @(0, 50, 100, 150, 200)) {
    Write-Host "Testing ${delayMs}ms delay after reinit..."

    # Send reinit
    $script:HIDStream.SetFeature($script:FIRST_PACKET)

    # Wait specified time
    if ($delayMs -gt 0) {
        Start-Sleep -Milliseconds $delayMs
    }

    # Send image packets
    $packets = New-PacketChunk -PixelData $pixelData
    foreach ($packet in $packets) {
        Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
    }

    Start-Sleep -Seconds 2
    $response = Read-Host "Did display show red? (y/n)"

    if ($response -eq 'y') {
        Write-Host "SUCCESS at ${delayMs}ms" -ForegroundColor Green
    } else {
        Write-Host "FAILED at ${delayMs}ms" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "`nNow testing delays AFTER sending packets (for render time)..."
Write-Host "=========================================================`n"

foreach ($delayMs in @(0, 50, 100, 150, 200)) {
    Write-Host "Testing ${delayMs}ms delay AFTER packets sent..."

    # Send reinit
    $script:HIDStream.SetFeature($script:FIRST_PACKET)
    Start-Sleep -Milliseconds 10

    # Send image packets
    $packets = New-PacketChunk -PixelData $pixelData
    foreach ($packet in $packets) {
        Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
    }

    # Wait AFTER sending all packets
    if ($delayMs -gt 0) {
        Start-Sleep -Milliseconds $delayMs
    }

    # Immediately send reinit (simulates next spinner frame)
    $script:HIDStream.SetFeature($script:FIRST_PACKET)

    Start-Sleep -Seconds 1
    $response = Read-Host "Did display show red (even briefly)? (y/n)"

    if ($response -eq 'y') {
        Write-Host "SUCCESS at ${delayMs}ms post-render delay" -ForegroundColor Green
    } else {
        Write-Host "FAILED at ${delayMs}ms post-render delay" -ForegroundColor Red
    }
    Write-Host ""
}

Disconnect-DynaTab
