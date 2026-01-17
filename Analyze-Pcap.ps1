<#
.SYNOPSIS
    Analyze new pcap files for animation and keyboard light protocols

.DESCRIPTION
    Extracts and analyzes:
    - 5-frame animation (150ms delay)
    - Keyboard light control packets
#>

param(
    [Parameter(Mandatory)]
    [string]$FilePath
)

$json = Get-Content $FilePath -Raw | ConvertFrom-Json

Write-Host "`n=== Analyzing: $(Split-Path $FilePath -Leaf) ===" -ForegroundColor Cyan
Write-Host "Total packets: $($json.Count)" -ForegroundColor Gray

# Find HID Feature Report Set packets (0x09 = SET_REPORT)
$hidPackets = @()

foreach ($packet in $json) {
    $usb = $packet._source.layers.usb
    $setup = $packet._source.layers."Setup Data"
    $frame = $packet._source.layers.frame

    # Look for Set_Report (bRequest = 0x09)
    if ($setup -and $setup."usb.setup.bRequest" -eq "9") {
        $frameNum = $frame."frame.number"
        $time = $frame."frame.time_relative"
        $dataLen = $usb."usb.data_len"

        # Try to find the data in the next packet (response)
        $nextPacket = $json | Where-Object { $_._source.layers.frame."frame.number" -eq ($frameNum + 1).ToString() } | Select-Object -First 1

        if ($nextPacket -and $nextPacket._source.layers."usb.capdata") {
            $data = $nextPacket._source.layers."usb.capdata"."usb.capdata_raw"

            if ($data -and $data.Length -ge 128) {
                # Convert hex string to bytes
                $bytes = @()
                for ($i = 0; $i -lt $data.Length; $i += 3) {
                    $bytes += [Convert]::ToByte($data.Substring($i, 2), 16)
                }

                # Check if this is an init packet (starts with 0xa9)
                if ($bytes.Count -ge 12 -and $bytes[1] -eq 0xa9) {
                    $hidPackets += [PSCustomObject]@{
                        Frame = $frameNum
                        Time = $time
                        DataLen = $dataLen
                        Type = "INIT"
                        Mode = "0x{0:X2}" -f $bytes[3]
                        Delay = "0x{0:X2} ({1}ms)" -f $bytes[4], $bytes[4]
                        Byte8 = "0x{0:X2}" -f $bytes[9]
                        Byte9 = "0x{0:X2}" -f $bytes[10]
                        RawData = ($bytes[1..20] | ForEach-Object { "{0:X2}" -f $_ }) -join ":"
                    }
                }
                elseif ($bytes.Count -ge 12 -and $bytes[1] -eq 0x29) {
                    $counter = $bytes[5]
                    $addr = ($bytes[7] -shl 8) -bor $bytes[8]

                    $hidPackets += [PSCustomObject]@{
                        Frame = $frameNum
                        Time = $time
                        DataLen = $dataLen
                        Type = "DATA"
                        Counter = "0x{0:X2}" -f $counter
                        Address = "0x{0:X4}" -f $addr
                        RawHeader = ($bytes[1..8] | ForEach-Object { "{0:X2}" -f $_ }) -join ":"
                    }
                }
                else {
                    # Unknown packet type
                    $hidPackets += [PSCustomObject]@{
                        Frame = $frameNum
                        Time = $time
                        DataLen = $dataLen
                        Type = "UNKNOWN"
                        FirstByte = "0x{0:X2}" -f $bytes[1]
                        RawStart = ($bytes[1..16] | ForEach-Object { "{0:X2}" -f $_ }) -join ":"
                    }
                }
            }
        }
    }
}

Write-Host "`nFound $($hidPackets.Count) HID packets" -ForegroundColor Yellow

# Show init packets
$initPackets = $hidPackets | Where-Object { $_.Type -eq "INIT" }
if ($initPackets) {
    Write-Host "`n--- INIT PACKETS ---" -ForegroundColor Green
    $initPackets | Format-Table -AutoSize
}

# Show first and last data packets
$dataPackets = $hidPackets | Where-Object { $_.Type -eq "DATA" }
if ($dataPackets) {
    Write-Host "`n--- DATA PACKETS (First 10 & Last 5) ---" -ForegroundColor Green
    $dataPackets | Select-Object -First 10 | Format-Table -AutoSize
    Write-Host "..." -ForegroundColor Gray
    $dataPackets | Select-Object -Last 5 | Format-Table -AutoSize

    Write-Host "`nTotal data packets: $($dataPackets.Count)" -ForegroundColor Yellow

    # Analyze address pattern
    $firstAddr = [Convert]::ToInt32($dataPackets[0].Address, 16)
    $lastAddr = [Convert]::ToInt32($dataPackets[-1].Address, 16)
    Write-Host "Address range: $($dataPackets[0].Address) → $($dataPackets[-1].Address)" -ForegroundColor Cyan
    Write-Host "Address span: $($firstAddr - $lastAddr) addresses" -ForegroundColor Cyan
}

# Show unknown packets
$unknownPackets = $hidPackets | Where-Object { $_.Type -eq "UNKNOWN" }
if ($unknownPackets) {
    Write-Host "`n--- UNKNOWN PACKETS ---" -ForegroundColor Yellow
    $unknownPackets | Select-Object -First 10 | Format-Table -AutoSize
}

Write-Host ""
