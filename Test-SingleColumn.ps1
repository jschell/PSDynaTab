#Requires -Version 5.1

<#
.SYNOPSIS
    Tests single column changes on DynaTab display
.DESCRIPTION
    Sends minimal packets to change individual columns, mimicking proof-of-work approach
#>

param(
    [Parameter()]
    [ValidateRange(0, 59)]
    [int]$Column = 0,

    [Parameter()]
    [ValidateSet('Red', 'Green', 'Blue', 'White', 'Off')]
    [string]$Color = 'Red',

    [Parameter()]
    [switch]$UseModule
)

Write-Host "`n=== Single Column Test ===" -ForegroundColor Cyan
Write-Host "Column: $Column, Color: $Color" -ForegroundColor Yellow
Write-Host "Method: $(if ($UseModule) { 'PSDynaTab Module' } else { 'Direct HID (like proof-of-work)' })" -ForegroundColor Yellow

# Color mapping
$colorBytes = @{
    'Red'   = @(0xFF, 0x00, 0x00)
    'Green' = @(0x00, 0xFF, 0x00)
    'Blue'  = @(0x00, 0x00, 0xFF)
    'White' = @(0xFF, 0xFF, 0xFF)
    'Off'   = @(0x00, 0x00, 0x00)
}

if ($UseModule) {
    # Use PSDynaTab module
    Import-Module PSDynaTab -Force

    Write-Host "`nConnecting via module..." -ForegroundColor Cyan
    Connect-DynaTab -Verbose

    # Create bitmap with single column colored
    Write-Host "Creating image with column $Column colored $Color..." -ForegroundColor Cyan
    $bitmap = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Black)

    # Set the specified column
    $drawColor = switch ($Color) {
        'Red'   { [System.Drawing.Color]::Red }
        'Green' { [System.Drawing.Color]::FromArgb(0, 255, 0) }
        'Blue'  { [System.Drawing.Color]::Blue }
        'White' { [System.Drawing.Color]::White }
        'Off'   { [System.Drawing.Color]::Black }
    }

    for ($row = 0; $row -lt 9; $row++) {
        $bitmap.SetPixel($Column, $row, $drawColor)
    }

    $graphics.Dispose()

    Write-Host ">>> WATCH THE DISPLAY - Column $Column should turn $Color <<<" -ForegroundColor Magenta
    Send-DynaTabImage -Image $bitmap -Verbose

    $bitmap.Dispose()

    Write-Host "`nDisconnecting..." -ForegroundColor Gray
    Disconnect-DynaTab

} else {
    # Direct HID approach (like proof-of-work)
    Write-Host "`nLoading HidSharp..." -ForegroundColor Cyan
    $hidSharpPath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
    if (-not (Test-Path $hidSharpPath)) {
        # Try OneDrive path
        $documentsPath = [Environment]::GetFolderPath('MyDocuments')
        $hidSharpPath = "$documentsPath\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
    }

    Add-Type -Path $hidSharpPath
    Write-Host "✓ HidSharp loaded" -ForegroundColor Green

    # Find device
    Write-Host "Finding device..." -ForegroundColor Cyan
    $devices = @([HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015))

    # Find MI_02 interface with 65-byte feature reports
    $screenDevice = $null
    foreach ($dev in $devices) {
        $path = $dev.DevicePath
        if ($path -like "*mi_02*") {
            $featureReportSize = $dev.GetMaxFeatureReportLength()
            if ($featureReportSize -eq 65) {
                $screenDevice = $dev
                break
            }
        }
    }

    if (-not $screenDevice) {
        throw "Screen interface not found!"
    }

    Write-Host "✓ Screen interface found" -ForegroundColor Green

    # Init packet
    $FIRST_PACKET = [byte[]]@(
        0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
        0x00, 0x00, 0x3c, 0x09, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )

    try {
        $stream = $screenDevice.Open()
        Write-Host "✓ Device opened" -ForegroundColor Green

        # Send init packet
        Write-Host "`nSending initialization packet..." -ForegroundColor Cyan
        $initPacket = New-Object byte[] 65
        $initPacket[0] = 0x00  # Report ID
        for ($i = 0; $i -lt $FIRST_PACKET.Length; $i++) {
            $initPacket[$i + 1] = $FIRST_PACKET[$i]
        }

        $stream.SetFeature($initPacket)
        Write-Host "  ✓ Init packet sent" -ForegroundColor Green
        Start-Sleep -Milliseconds 10

        # Create pixel data - all black except specified column
        Write-Host "`nCreating pixel data..." -ForegroundColor Cyan
        $pixelData = New-Object byte[] (60 * 9 * 3)  # 1620 bytes

        # Column-major order: for each column, set 9 rows
        $rgb = $colorBytes[$Color]
        for ($row = 0; $row -lt 9; $row++) {
            $index = ($Column * 9 * 3) + ($row * 3)
            $pixelData[$index] = $rgb[0]      # R
            $pixelData[$index + 1] = $rgb[1]  # G
            $pixelData[$index + 2] = $rgb[2]  # B
        }

        Write-Host "  Column $Column pixels:" -ForegroundColor Gray
        for ($row = 0; $row -lt 9; $row++) {
            $index = ($Column * 9 * 3) + ($row * 3)
            Write-Host "    Row $row : R=$($pixelData[$index].ToString('X2')) G=$($pixelData[$index+1].ToString('X2')) B=$($pixelData[$index+2].ToString('X2'))" -ForegroundColor Gray
        }

        # Send packets
        Write-Host "`n>>> WATCH THE DISPLAY - Column $Column should turn $Color <<<" -ForegroundColor Magenta
        Write-Host "Sending packets..." -ForegroundColor Cyan

        $base_address = 0x0000389D
        $incrementing = 0
        $decrementing = $base_address
        $packetCount = 0

        for ($offset = 0; $offset -lt $pixelData.Length; $offset += 56) {
            $chunkSize = [Math]::Min(56, $pixelData.Length - $offset)

            $packet = New-Object byte[] 65
            $packet[0] = 0x00   # Report ID
            $packet[1] = 0x29   # Fixed header byte
            $packet[2] = 0x00   # Frame index
            $packet[3] = 0x01   # Image mode
            $packet[4] = 0x00   # Fixed

            # Incrementing (little endian)
            $packet[5] = $incrementing -band 0xFF
            $packet[6] = ($incrementing -shr 8) -band 0xFF

            # Decrementing (big endian)
            $packet[7] = ($decrementing -shr 8) -band 0xFF
            $packet[8] = $decrementing -band 0xFF

            # Copy pixel data
            for ($i = 0; $i -lt $chunkSize; $i++) {
                $packet[9 + $i] = $pixelData[$offset + $i]
            }

            $stream.SetFeature($packet)
            $packetCount++

            # Show packet if it contains our colored column data
            $packetStartPixel = $offset / 3
            $packetEndPixel = ($offset + $chunkSize) / 3
            $targetStartPixel = $Column * 9
            $targetEndPixel = ($Column + 1) * 9

            if ($packetStartPixel -le $targetEndPixel -and $packetEndPixel -ge $targetStartPixel) {
                Write-Host "  → Packet $packetCount (contains column $Column data)" -ForegroundColor Yellow
            } else {
                Write-Host "  → Packet $packetCount" -ForegroundColor Gray
            }

            $incrementing++
            $decrementing--

            Start-Sleep -Milliseconds 5
        }

        $stream.Close()
        Write-Host "`n✓ Sent $packetCount packets" -ForegroundColor Green

    } catch {
        Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($stream) { $stream.Close() }
        throw
    }
}

Write-Host "`nDid column $Column turn $Color? (y/n): " -ForegroundColor Yellow -NoNewline
$response = Read-Host

if ($response -eq 'y') {
    Write-Host "✓ SUCCESS!" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Try direct HID method: -UseModule:$false" -ForegroundColor White
    Write-Host "  2. Try column 0 (leftmost): -Column 0" -ForegroundColor White
    Write-Host "  3. Check if display is in correct mode (not showing battery/etc)" -ForegroundColor White
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
