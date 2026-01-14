#Requires -Version 5.1

<#
.SYNOPSIS
    Diagnostic script for PSDynaTab module
.DESCRIPTION
    Tests each component of the module to identify what's working and what's not
#>

Write-Host "`n=== PSDynaTab Diagnostic Test ===" -ForegroundColor Cyan
Write-Host "This script will test each component step-by-step`n" -ForegroundColor Yellow

# Test 1: Module Import
Write-Host "[Test 1] Module Import" -ForegroundColor Cyan
Write-Host "-" * 60
try {
    Import-Module PSDynaTab -Force
    $commands = Get-Command -Module PSDynaTab
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    Write-Host "  Commands found: $($commands.Count)" -ForegroundColor Gray
    foreach ($cmd in $commands | Sort-Object Name) {
        Write-Host "    - $($cmd.Name)" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: HidSharp.dll
Write-Host "`n[Test 2] HidSharp.dll" -ForegroundColor Cyan
Write-Host "-" * 60
$dllPath = "C:\Users\JSchell\OneDrive - NWSchell\Documents\PowerShell\Modules\PSDynaTab\lib\HidSharp.dll"
if (Test-Path $dllPath) {
    $dllSize = [math]::Round((Get-Item $dllPath).Length / 1KB, 2)
    Write-Host "✓ HidSharp.dll found (${dllSize} KB)" -ForegroundColor Green
    Write-Host "  Path: $dllPath" -ForegroundColor Gray
} else {
    Write-Host "✗ HidSharp.dll not found!" -ForegroundColor Red
    exit 1
}

# Test 3: Device Detection (before connection)
Write-Host "`n[Test 3] Device Detection" -ForegroundColor Cyan
Write-Host "-" * 60
try {
    $allDevices = [HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015)
    Write-Host "  Total HID interfaces found: $($allDevices.Count)" -ForegroundColor Yellow

    $index = 0
    foreach ($dev in $allDevices) {
        Write-Host "`n  Interface $index :" -ForegroundColor Gray
        Write-Host "    Path: $($dev.DevicePath)" -ForegroundColor Gray
        Write-Host "    MaxFeatureReportLength: $($dev.GetMaxFeatureReportLength())" -ForegroundColor Gray
        Write-Host "    MaxOutputReportLength: $($dev.GetMaxOutputReportLength())" -ForegroundColor Gray
        Write-Host "    MaxInputReportLength: $($dev.GetMaxInputReportLength())" -ForegroundColor Gray

        if ($dev.DevicePath.ToLower() -like "*mi_02*" -and $dev.GetMaxFeatureReportLength() -eq 65) {
            Write-Host "    >>> THIS IS THE SCREEN INTERFACE <<<" -ForegroundColor Green
        }
        $index++
    }

    if ($allDevices.Count -eq 0) {
        Write-Host "✗ No DynaTab devices found!" -ForegroundColor Red
        Write-Host "  Make sure keyboard is connected via USB (not Bluetooth/2.4GHz)" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "`n✓ DynaTab device(s) found" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Device detection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Connection
Write-Host "`n[Test 4] Connection" -ForegroundColor Cyan
Write-Host "-" * 60
try {
    $connectionInfo = Connect-DynaTab -Verbose
    Write-Host "✓ Connected successfully" -ForegroundColor Green
    $connectionInfo | Format-List
} catch {
    Write-Host "✗ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 5: Connection Test
Write-Host "`n[Test 5] Connection Test" -ForegroundColor Cyan
Write-Host "-" * 60
$isConnected = Test-DynaTabConnection -Verbose
if ($isConnected) {
    Write-Host "✓ Device is connected and responsive" -ForegroundColor Green
} else {
    Write-Host "✗ Device not responsive" -ForegroundColor Red
}

# Test 6: Device Info
Write-Host "`n[Test 6] Device Info" -ForegroundColor Cyan
Write-Host "-" * 60
try {
    $deviceInfo = Get-DynaTabDevice
    $deviceInfo | Format-List
    Write-Host "✓ Device info retrieved" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to get device info: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Clear Display (All Black - simplest test)
Write-Host "`n[Test 7] Clear Display (All Black)" -ForegroundColor Cyan
Write-Host "-" * 60
Write-Host "Sending all-black image..." -ForegroundColor Yellow
Write-Host ">>> WATCH THE KEYBOARD DISPLAY - Should turn completely dark <<<" -ForegroundColor Magenta
Start-Sleep -Seconds 2

try {
    Clear-DynaTab -Verbose
    Write-Host "✓ Clear command sent" -ForegroundColor Green
    Write-Host "`nDid the display turn black? (y/n): " -ForegroundColor Yellow -NoNewline
    $response1 = Read-Host

    if ($response1 -eq 'y') {
        Write-Host "✓ Clear display works!" -ForegroundColor Green
    } else {
        Write-Host "✗ Display did not change" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Clear failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 8: Solid Red
Write-Host "`n[Test 8] Solid Red Display" -ForegroundColor Cyan
Write-Host "-" * 60
Write-Host "Creating red test image..." -ForegroundColor Yellow
Write-Host ">>> WATCH THE KEYBOARD DISPLAY - Should turn red <<<" -ForegroundColor Magenta
Start-Sleep -Seconds 2

try {
    $img = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($img)
    $graphics.Clear([System.Drawing.Color]::Red)
    $graphics.Dispose()

    Send-DynaTabImage -Image $img -Verbose
    $img.Dispose()

    Write-Host "✓ Red image sent" -ForegroundColor Green
    Write-Host "`nDid the display turn red? (y/n): " -ForegroundColor Yellow -NoNewline
    $response2 = Read-Host

    if ($response2 -eq 'y') {
        Write-Host "✓ Image display works!" -ForegroundColor Green
    } else {
        Write-Host "✗ Display did not change" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Red image failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 9: Solid Green
Write-Host "`n[Test 9] Solid Green Display" -ForegroundColor Cyan
Write-Host "-" * 60
Write-Host ">>> WATCH THE KEYBOARD DISPLAY - Should turn green <<<" -ForegroundColor Magenta
Start-Sleep -Seconds 1

try {
    $img = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($img)
    $graphics.Clear([System.Drawing.Color]::Green)
    $graphics.Dispose()

    Send-DynaTabImage -Image $img -Verbose
    $img.Dispose()

    Write-Host "✓ Green image sent" -ForegroundColor Green
} catch {
    Write-Host "✗ Green image failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 10: Text Rendering (analyze what's created)
Write-Host "`n[Test 10] Text Rendering Analysis" -ForegroundColor Cyan
Write-Host "-" * 60
Write-Host "Creating text 'TEST' and analyzing pixel data..." -ForegroundColor Yellow

try {
    # Create the same image Set-DynaTabText creates
    $bitmap = New-Object System.Drawing.Bitmap(60, 9)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Black)

    $font = New-Object System.Drawing.Font("Consolas", 6, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Green)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, 60, 9)
    $graphics.DrawString("TEST", $font, $brush, $rect, $format)

    # Count non-black pixels
    $nonBlackPixels = 0
    for ($x = 0; $x -lt 60; $x++) {
        for ($y = 0; $y -lt 9; $y++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) {
                $nonBlackPixels++
            }
        }
    }

    Write-Host "  Total pixels: 540 (60x9)" -ForegroundColor Gray
    Write-Host "  Non-black pixels: $nonBlackPixels" -ForegroundColor $(if ($nonBlackPixels -gt 0) { 'Green' } else { 'Red' })

    if ($nonBlackPixels -eq 0) {
        Write-Host "✗ Text rendering produces blank image!" -ForegroundColor Red
        Write-Host "  Font 'Consolas' size 6 might be too small for 60x9 display" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Text rendering creates visible pixels" -ForegroundColor Green

        # Save test image to file for inspection
        $testImagePath = Join-Path $env:TEMP "dynatab_text_test.png"
        $bitmap.Save($testImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "  Test image saved to: $testImagePath" -ForegroundColor Gray
        Write-Host "  You can open this image to see what's being sent" -ForegroundColor Gray
    }

    # Cleanup
    $graphics.Dispose()
    $font.Dispose()
    $brush.Dispose()
    $format.Dispose()
    $bitmap.Dispose()

} catch {
    Write-Host "✗ Text analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 11: Send Text to Display
Write-Host "`n[Test 11] Send Text to Display" -ForegroundColor Cyan
Write-Host "-" * 60
Write-Host ">>> WATCH THE KEYBOARD DISPLAY <<<" -ForegroundColor Magenta
Start-Sleep -Seconds 1

try {
    Set-DynaTabText "TEST" -Color Green -Verbose
    Write-Host "✓ Text command sent" -ForegroundColor Green
    Write-Host "`nDid you see any text on the display? (y/n): " -ForegroundColor Yellow -NoNewline
    $response3 = Read-Host

    if ($response3 -eq 'y') {
        Write-Host "✓ Text display works!" -ForegroundColor Green
    } else {
        Write-Host "✗ No text visible (likely font too small or rendering issue)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Text command failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n`n=== Diagnostic Summary ===" -ForegroundColor Cyan
Write-Host "-" * 60

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. If Clear/Red/Green worked: HID communication is working!" -ForegroundColor White
Write-Host "2. If text didn't show: Font is too small for 60x9 display" -ForegroundColor White
Write-Host "3. If nothing changed: Check HID interface or packet format" -ForegroundColor White
Write-Host "`nCheck the saved test image at:" -ForegroundColor Yellow
Write-Host "  $env:TEMP\dynatab_text_test.png" -ForegroundColor White

# Disconnect
Write-Host "`nDisconnecting..." -ForegroundColor Gray
Disconnect-DynaTab

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
