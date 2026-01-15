#Requires -Version 5.1

<#
.SYNOPSIS
    Compare packet structure between proof of work and our implementation
#>

Write-Host "`n=== Packet Structure Comparison ===" -ForegroundColor Cyan

# Proof of Work packet structure (WORKS)
Write-Host "`n[Proof of Work - Single Red Column]" -ForegroundColor Yellow
$pixelDataPOW = New-Object byte[] (60 * 9 * 3)
# Make first column red
for ($i = 0; $i -lt 9; $i++) {
    $pixelDataPOW[$i * 3] = 0xFF      # R
    $pixelDataPOW[$i * 3 + 1] = 0x00  # G
    $pixelDataPOW[$i * 3 + 2] = 0x00  # B
}

# Create first packet like proof of work
$base_address = 0x389D
$incrementing = 0
$decrementing = $base_address
$offset = 0
$chunkSize = 56

$packetPOW = New-Object byte[] 65
$packetPOW[0] = 0x00   # Report ID
$packetPOW[1] = 0x29   # Fixed header byte
$packetPOW[2] = 0x00   # Frame index
$packetPOW[3] = 0x01   # Image mode
$packetPOW[4] = 0x00   # Fixed

# Incrementing (little endian)
$packetPOW[5] = $incrementing -band 0xFF
$packetPOW[6] = ($incrementing -shr 8) -band 0xFF

# Decrementing (big endian)
$packetPOW[7] = ($decrementing -shr 8) -band 0xFF
$packetPOW[8] = $decrementing -band 0xFF

# Copy pixel data
for ($i = 0; $i -lt $chunkSize; $i++) {
    $packetPOW[9 + $i] = $pixelDataPOW[$offset + $i]
}

Write-Host "First 65 bytes (full packet):"
for ($i = 0; $i -lt 65; $i++) {
    if ($i % 16 -eq 0) { Write-Host "" }
    Write-Host ("{0:X2} " -f $packetPOW[$i]) -NoNewline -ForegroundColor $(if ($i -lt 9) { 'Cyan' } elseif ($packetPOW[$i] -ne 0) { 'Green' } else { 'Gray' })
}
Write-Host "`n"

# Our implementation
Write-Host "`n[Our Implementation - Single Red Column]" -ForegroundColor Yellow

Import-Module PSDynaTab -Force

# Create same pixel data
$img = New-Object System.Drawing.Bitmap(60, 9)
for ($row = 0; $row -lt 9; $row++) {
    $img.SetPixel(0, $row, [System.Drawing.Color]::Red)
}

# Convert using our function
$pixelDataOurs = New-Object byte[] 1620
$index = 0
for ($col = 0; $col -lt 60; $col++) {
    for ($row = 0; $row -lt 9; $row++) {
        $pixel = $img.GetPixel($col, $row)
        $pixelDataOurs[$index++] = $pixel.R
        $pixelDataOurs[$index++] = $pixel.G
        $pixelDataOurs[$index++] = $pixel.B
    }
}

# Create packet using our New-PacketChunk logic
$packetOurs = New-Object byte[] 64
$packetOurs[0] = 0x29
$packetOurs[1] = 0x00
$packetOurs[2] = 0x01
$packetOurs[3] = 0x00
$packetOurs[4] = 0
$packetOurs[5] = 0
$packetOurs[6] = 0x38
$packetOurs[7] = 0x9D

for ($i = 0; $i -lt 56; $i++) {
    $packetOurs[8 + $i] = $pixelDataOurs[$i]
}

# Simulate Send-FeaturePacket wrapping
$featureReportOurs = New-Object byte[] 65
$featureReportOurs[0] = 0x00
for ($i = 0; $i -lt 64; $i++) {
    $featureReportOurs[$i + 1] = $packetOurs[$i]
}

Write-Host "First 65 bytes (after Send-FeaturePacket wrapping):"
for ($i = 0; $i -lt 65; $i++) {
    if ($i % 16 -eq 0) { Write-Host "" }
    Write-Host ("{0:X2} " -f $featureReportOurs[$i]) -NoNewline -ForegroundColor $(if ($i -lt 9) { 'Cyan' } elseif ($featureReportOurs[$i] -ne 0) { 'Green' } else { 'Gray' })
}
Write-Host "`n"

# Compare
Write-Host "`n[Comparison]" -ForegroundColor Yellow
$differences = 0
for ($i = 0; $i -lt 65; $i++) {
    if ($packetPOW[$i] -ne $featureReportOurs[$i]) {
        Write-Host "  Byte $i : POW=0x$($packetPOW[$i].ToString('X2')) vs Ours=0x$($featureReportOurs[$i].ToString('X2'))" -ForegroundColor Red
        $differences++
    }
}

if ($differences -eq 0) {
    Write-Host "  ✓ Packets are IDENTICAL!" -ForegroundColor Green
    Write-Host "  The packet structure is correct. Issue must be elsewhere." -ForegroundColor Yellow
} else {
    Write-Host "  ✗ Found $differences differences" -ForegroundColor Red
}

# Check pixel data specifically
Write-Host "`n[Pixel Data Comparison]" -ForegroundColor Yellow
Write-Host "First 30 bytes of pixel data:"
Write-Host "  POW: " -NoNewline
for ($i = 0; $i -lt 30; $i++) {
    Write-Host ("{0:X2} " -f $pixelDataPOW[$i]) -NoNewline -ForegroundColor Gray
}
Write-Host "`n  Ours: " -NoNewline
for ($i = 0; $i -lt 30; $i++) {
    Write-Host ("{0:X2} " -f $pixelDataOurs[$i]) -NoNewline -ForegroundColor Gray
}
Write-Host "`n"

$img.Dispose()

Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan
