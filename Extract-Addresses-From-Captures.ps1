<#
.SYNOPSIS
    Extract memory addresses from all working captures

.DESCRIPTION
    Analyzes your working USB captures to extract the data packet
    addresses used for different image sizes.

    This will reveal the address pattern formula.
#>

$captureFiles = Get-ChildItem "usbPcap\*.json" | Where-Object { $_.Name -like "*picture*" }

Write-Host "=== Extracting Addresses from Working Captures ===" -ForegroundColor Cyan
Write-Host ""

$results = @()

foreach ($file in $captureFiles) {
    Write-Host "Analyzing: $($file.Name)" -ForegroundColor Yellow

    $content = Get-Content $file.FullPath -Raw
    $json = $content | ConvertFrom-Json

    $initPacket = $null
    $dataPacket = $null

    foreach ($packet in $json) {
        $layers = $packet.'_source'.layers

        if ($layers.'usbhid.data') {
            $hexData = $layers.'usbhid.data' -replace ':', ''

            # Init packet (0xa9)
            if ($hexData -match '^a9') {
                $initPacket = $hexData
            }

            # Data packet (0x29) - get first one
            if ($hexData -match '^29' -and -not $dataPacket) {
                $dataPacket = $hexData
            }

            if ($initPacket -and $dataPacket) {
                break
            }
        }
    }

    if ($initPacket -and $dataPacket) {
        # Parse init packet
        $frameCount = [Convert]::ToInt32($initPacket.Substring(4, 2), 16)
        $dataBytes = [Convert]::ToInt32($initPacket.Substring(10, 2) + $initPacket.Substring(8, 2), 16)
        $xStart = [Convert]::ToInt32($initPacket.Substring(16, 2), 16)
        $yStart = [Convert]::ToInt32($initPacket.Substring(18, 2), 16)
        $xEnd = [Convert]::ToInt32($initPacket.Substring(20, 2), 16)
        $yEnd = [Convert]::ToInt32($initPacket.Substring(22, 2), 16)

        $width = $xEnd - $xStart
        $height = $yEnd - $yStart
        $pixelCount = $width * $height

        # Parse data packet address (bytes 6-7, big-endian)
        $addrHigh = [Convert]::ToInt32($dataPacket.Substring(12, 2), 16)
        $addrLow = [Convert]::ToInt32($dataPacket.Substring(14, 2), 16)
        $address = ($addrHigh -shl 8) -bor $addrLow

        $result = [PSCustomObject]@{
            File = $file.Name
            Pixels = $pixelCount
            Width = $width
            Height = $height
            DataBytes = $dataBytes
            Address = "0x{0:X4}" -f $address
            AddressDecimal = $address
            XStart = $xStart
            YStart = $yStart
            XEnd = $xEnd
            YEnd = $yEnd
        }

        $results += $result

        Write-Host "  Pixels: $pixelCount ($width×$height)" -ForegroundColor White
        Write-Host "  Address: 0x$($address.ToString('X4')) ($address decimal)" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "  ✗ Could not extract packets" -ForegroundColor Red
        Write-Host ""
    }
}

if ($results.Count -gt 0) {
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $results | Sort-Object Pixels | Format-Table Pixels, Width, Height, Address, AddressDecimal -AutoSize

    Write-Host ""
    Write-Host "=== Pattern Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    # Try to find the formula
    foreach ($r in $results | Sort-Object Pixels) {
        $calc1 = 0x03D2 - $r.Pixels
        $calc2 = 0x03D2 + $r.Pixels
        $calc3 = 0x03D2 - ($r.Pixels * 3)
        $calc4 = 0x03D2 + ($r.Pixels * 3)

        Write-Host ("Pixels: {0,3} | Addr: {1} | 0x03D2-px={2:X4} | 0x03D2+px={3:X4} | 0x03D2-(px*3)={4:X4} | 0x03D2+(px*3)={5:X4}" -f `
            $r.Pixels, $r.Address, $calc1, $calc2, $calc3, $calc4)
    }

    Write-Host ""
    Write-Host "Look for a pattern in the calculations above!" -ForegroundColor Yellow
    Write-Host ""

    # Export to CSV
    $results | Export-Csv "Address-Analysis.csv" -NoTypeInformation
    Write-Host "✓ Exported to Address-Analysis.csv" -ForegroundColor Green
} else {
    Write-Host "No valid captures found!" -ForegroundColor Red
}
