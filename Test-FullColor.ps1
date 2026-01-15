#Requires -Version 5.1

<#
.SYNOPSIS
    Tests full-color display with timing analysis
.DESCRIPTION
    Tests sending full red, green, and blue displays with different packet delays
#>

param(
    [Parameter()]
    [ValidateRange(5, 100)]
    [int]$PacketDelayMs = 5
)

Write-Host "`n=== Full Color Display Test ===" -ForegroundColor Cyan
Write-Host "Packet delay: ${PacketDelayMs}ms" -ForegroundColor Yellow

Import-Module PSDynaTab -Force

function Send-ImageWithDelay {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$DelayMs,
        [string]$Description
    )

    Write-Host "`n[Test] $Description" -ForegroundColor Cyan
    Write-Host ">>> WATCH DISPLAY <<<" -ForegroundColor Magenta

    # Convert to pixel data
    $pixelData = ConvertTo-PixelData -Image $Bitmap

    # Chunk into packets
    $packets = New-PacketChunk -PixelData $pixelData

    Write-Host "Sending $($packets.Count) packets with ${DelayMs}ms delay..." -ForegroundColor Gray

    # Send with custom delay
    $packetNumber = 0
    foreach ($packet in $packets) {
        $packetNumber++

        # Prepend report ID
        $featureReport = New-Object byte[] 65
        $featureReport[0] = 0x00
        for ($i = 0; $i -lt 64; $i++) {
            $featureReport[$i + 1] = $packet[$i]
        }

        $script:HIDStream.SetFeature($featureReport)

        # Custom delay
        Start-Sleep -Milliseconds $DelayMs

        if ($packetNumber % 10 -eq 0) {
            Write-Host "  Sent $packetNumber/$($packets.Count) packets" -ForegroundColor Gray
        }
    }

    Write-Host "✓ All packets sent" -ForegroundColor Green
}

try {
    Write-Host "Connecting..." -ForegroundColor Cyan
    Connect-DynaTab
    Start-Sleep -Seconds 1

    # Test 1: Full Red
    $red = New-Object System.Drawing.Bitmap(60, 9)
    $g = [System.Drawing.Graphics]::FromImage($red)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 0, 0))
    $g.Dispose()

    Send-ImageWithDelay -Bitmap $red -DelayMs $PacketDelayMs -Description "Full RED display"
    $red.Dispose()

    Start-Sleep -Seconds 3

    Write-Host "`nDid the display turn RED? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    if ($response1 -eq 'n') {
        Write-Host "`n⚠ RED failed. Trying with longer delay (20ms)..." -ForegroundColor Yellow
        $red2 = New-Object System.Drawing.Bitmap(60, 9)
        $g2 = [System.Drawing.Graphics]::FromImage($red2)
        $g2.Clear([System.Drawing.Color]::FromArgb(255, 0, 0))
        $g2.Dispose()

        Send-ImageWithDelay -Bitmap $red2 -DelayMs 20 -Description "Full RED with 20ms delay"
        $red2.Dispose()

        Start-Sleep -Seconds 3

        Write-Host "`nDid RED work with 20ms delay? (y/n): " -ForegroundColor Yellow -NoNewline
        $response1b = Read-Host

        if ($response1b -eq 'y') {
            Write-Host "✓ Timing issue confirmed - need longer delays" -ForegroundColor Green
        } else {
            Write-Host "✗ Not a timing issue - investigating further..." -ForegroundColor Red

            # Try single red column again to verify connection still works
            Write-Host "`nVerifying connection with single column test..." -ForegroundColor Cyan
            Clear-DynaTab
            Start-Sleep -Seconds 1

            $singleCol = New-Object System.Drawing.Bitmap(60, 9)
            $gSingle = [System.Drawing.Graphics]::FromImage($singleCol)
            $gSingle.Clear([System.Drawing.Color]::Black)
            for ($row = 0; $row -lt 9; $row++) {
                $singleCol.SetPixel(0, $row, [System.Drawing.Color]::Red)
            }
            $gSingle.Dispose()

            Send-DynaTabImage -Image $singleCol
            $singleCol.Dispose()

            Start-Sleep -Seconds 2
            Write-Host "Did single column work? (y/n): " -ForegroundColor Yellow -NoNewline
            $responseSingle = Read-Host

            if ($responseSingle -eq 'y') {
                Write-Host "✓ Single column works, full display doesn't" -ForegroundColor Yellow
                Write-Host "This suggests a data density or device limitation issue" -ForegroundColor Yellow
            } else {
                Write-Host "✗ Connection may have been lost" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "✓ Full RED works!" -ForegroundColor Green

        # Test 2: Full Green
        Clear-DynaTab
        Start-Sleep -Seconds 1

        $green = New-Object System.Drawing.Bitmap(60, 9)
        $g = [System.Drawing.Graphics]::FromImage($green)
        $g.Clear([System.Drawing.Color]::FromArgb(0, 255, 0))
        $g.Dispose()

        Send-ImageWithDelay -Bitmap $green -DelayMs $PacketDelayMs -Description "Full GREEN display"
        $green.Dispose()

        Start-Sleep -Seconds 3

        Write-Host "`nDid the display turn GREEN? (y/n): " -ForegroundColor Yellow -NoNewline
        $response2 = Read-Host

        if ($response2 -eq 'y') {
            Write-Host "✓ Full GREEN works!" -ForegroundColor Green
        }
    }

} finally {
    Write-Host "`nDisconnecting..." -ForegroundColor Gray
    Disconnect-DynaTab
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "`nResults Summary:" -ForegroundColor Yellow
Write-Host "  Full RED: $response1" -ForegroundColor Gray
if ($response1 -eq 'y') {
    Write-Host "  Full GREEN: $response2" -ForegroundColor Gray
}
