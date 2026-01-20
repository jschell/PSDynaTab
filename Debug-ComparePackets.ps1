<#
.SYNOPSIS
    Diagnostic - Compare generated packets vs expected

.DESCRIPTION
    Shows exactly what packets our test scripts would generate
    compared to known working packets.

.EXAMPLE
    .\Debug-ComparePackets.ps1
#>

function Calculate-Checksum {
    param([byte[]]$Packet)
    $sum = 0
    for ($i = 0; $i -lt 7; $i++) {
        $sum += $Packet[$i]
    }
    return [byte]((0xFF - ($sum -band 0xFF)) -band 0xFF)
}

function Show-PacketComparison {
    param(
        [string]$TestName,
        [byte[]]$Generated,
        [byte[]]$Expected,
        [int]$BytesToShow = 16
    )

    Write-Host ""
    Write-Host "=== $TestName ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Generated: " -NoNewline
    Write-Host ($Generated[0..($BytesToShow-1)] | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ') -ForegroundColor Yellow
    Write-Host "Expected:  " -NoNewline
    Write-Host ($Expected[0..($BytesToShow-1)] | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ') -ForegroundColor Green

    # Show differences
    Write-Host "Diff:      " -NoNewline
    for ($i = 0; $i -lt $BytesToShow; $i++) {
        if ($Generated[$i] -ne $Expected[$i]) {
            Write-Host "^^" -NoNewline -ForegroundColor Red
        } else {
            Write-Host "  " -NoNewline
        }
        Write-Host " " -NoNewline
    }
    Write-Host ""

    # Count differences
    $diffCount = 0
    for ($i = 0; $i -lt 64; $i++) {
        if ($Generated[$i] -ne $Expected[$i]) {
            $diffCount++
        }
    }

    if ($diffCount -eq 0) {
        Write-Host "✓ MATCH!" -ForegroundColor Green
    } else {
        Write-Host "✗ $diffCount differences found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Byte-by-byte differences:" -ForegroundColor Yellow
        for ($i = 0; $i -lt 64; $i++) {
            if ($Generated[$i] -ne $Expected[$i]) {
                Write-Host ("  Byte {0,2}: Generated=0x{1:X2} ({1,3}) | Expected=0x{2:X2} ({2,3})" -f $i, $Generated[$i], $Expected[$i]) -ForegroundColor Red
            }
        }
    }
}

Write-Host "=== Packet Comparison Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Init packet for 1 green pixel
Write-Host "Test 1: Init packet (1 pixel at top-left)" -ForegroundColor Yellow

$generatedInit = New-Object byte[] 64
$generatedInit[0] = 0xa9
$generatedInit[1] = 0x00
$generatedInit[2] = 0x01
$generatedInit[3] = 0x00
$generatedInit[4] = 0x03  # 1 pixel = 3 bytes
$generatedInit[5] = 0x00
$generatedInit[6] = 0x00
$generatedInit[7] = Calculate-Checksum $generatedInit
$generatedInit[8] = 0x00   # X-start
$generatedInit[9] = 0x00   # Y-start
$generatedInit[10] = 0x01  # X-end
$generatedInit[11] = 0x01  # Y-end

$expectedInit = @(
    0xa9, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x52,
    0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

Show-PacketComparison -TestName "Init Packet" -Generated $generatedInit -Expected $expectedInit -BytesToShow 12

# Test 2: Data packet for 1 green pixel (WITH last packet override)
Write-Host ""
Write-Host "Test 2: Data packet (1 green pixel, with override)" -ForegroundColor Yellow

$generatedData = New-Object byte[] 64
$generatedData[0] = 0x29
$generatedData[1] = 0x00  # Frame index
$generatedData[2] = 0x01  # Frame count
$generatedData[3] = 0x00  # Delay
$generatedData[4] = 0x00  # Incrementing counter
$generatedData[5] = 0x00
$generatedData[6] = 0x34  # Last packet override
$generatedData[7] = 0x85
$generatedData[8] = 0x00  # Green pixel: R
$generatedData[9] = 0xFF  # Green pixel: G
$generatedData[10] = 0x00 # Green pixel: B

$expectedData = @(
    0x29, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0xd2,
    0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

Show-PacketComparison -TestName "Data Packet (with override)" -Generated $generatedData -Expected $expectedData -BytesToShow 16

# Test 3: Data packet WITHOUT last packet override (for comparison)
Write-Host ""
Write-Host "Test 3: Data packet (WITHOUT override - what was wrong before)" -ForegroundColor Yellow

$generatedDataNoOverride = New-Object byte[] 64
$generatedDataNoOverride[0] = 0x29
$generatedDataNoOverride[1] = 0x00
$generatedDataNoOverride[2] = 0x01
$generatedDataNoOverride[3] = 0x00
$generatedDataNoOverride[4] = 0x00
$generatedDataNoOverride[5] = 0x00
$generatedDataNoOverride[6] = 0x38  # Natural address high byte
$generatedDataNoOverride[7] = 0x9D  # Natural address low byte (0x389D)
$generatedDataNoOverride[8] = 0x00
$generatedDataNoOverride[9] = 0xFF
$generatedDataNoOverride[10] = 0x00

Show-PacketComparison -TestName "Data Packet (NO override)" -Generated $generatedDataNoOverride -Expected $expectedData -BytesToShow 16

Write-Host ""
Write-Host "=== Analysis ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "The working capture uses bytes 6-7 = 0x03d2 in the data packet." -ForegroundColor Yellow
Write-Host "This is NOT 0x389D (base address) and NOT 0x3485 (our override)." -ForegroundColor Red
Write-Host ""
Write-Host "  Working:     0x03d2 = 978 decimal" -ForegroundColor Green
Write-Host "  Base address: 0x389d = 14493 decimal" -ForegroundColor White
Write-Host "  Our override: 0x3485 = 13445 decimal" -ForegroundColor White
Write-Host ""
Write-Host "CRITICAL FINDING: The memory address in working captures is DIFFERENT!" -ForegroundColor Red
Write-Host ""

