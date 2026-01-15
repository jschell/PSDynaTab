function ConvertTo-BitmapText {
    <#
    .SYNOPSIS
        Converts text to pixel data using bitmap font
    .DESCRIPTION
        Renders text using 5x7 bitmap font directly to pixel data array.
        Bypasses System.Drawing for crisp, pixel-perfect rendering.
    .PARAMETER Text
        Text string to render
    .PARAMETER Font
        Font definition hashtable (from CP437-5x7.ps1)
    .PARAMETER Color
        RGB color as System.Drawing.Color
    .PARAMETER Alignment
        Text alignment: Left, Center, Right
    .OUTPUTS
        byte[] - 1620 bytes (60 cols × 9 rows × 3 RGB) in column-major order
    .NOTES
        Internal function - not exported
        Direct pixel manipulation for LED display
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [hashtable]$Font,

        [Parameter()]
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(0, 255, 0),

        [Parameter()]
        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Alignment = 'Center'
    )

    $charWidth = $Font.CharWidth
    $charHeight = $Font.CharHeight
    $charSpacing = $Font.CharSpacing
    $fontData = $Font.Data

    # Calculate text width in pixels
    $textChars = $Text.ToCharArray()
    $textWidthPixels = ($textChars.Count * $charWidth) + (($textChars.Count - 1) * $charSpacing)

    # Check if text fits
    if ($textWidthPixels -gt $script:SCREEN_WIDTH) {
        Write-Warning "Text '$Text' ($textWidthPixels px) exceeds display width ($($script:SCREEN_WIDTH) px). Truncating."
        # Calculate how many characters fit
        $maxChars = [Math]::Floor(($script:SCREEN_WIDTH + $charSpacing) / ($charWidth + $charSpacing))
        $Text = $Text.Substring(0, $maxChars)
        $textChars = $Text.ToCharArray()
        $textWidthPixels = ($textChars.Count * $charWidth) + (($textChars.Count - 1) * $charSpacing)
    }

    # Calculate starting X position based on alignment
    $startX = switch ($Alignment) {
        'Left' { 0 }
        'Center' { [Math]::Floor(($script:SCREEN_WIDTH - $textWidthPixels) / 2) }
        'Right' { $script:SCREEN_WIDTH - $textWidthPixels }
    }

    # Vertical centering (7 pixel tall font in 9 pixel display)
    $startY = [Math]::Floor(($script:SCREEN_HEIGHT - $charHeight) / 2)

    # Initialize pixel data array (all black)
    $pixelData = New-Object byte[] $script:PIXEL_BYTES

    # Current X position
    $currentX = $startX

    # Render each character
    foreach ($char in $textChars) {
        $asciiCode = [int]$char

        # Look up character in font
        if (-not $fontData.ContainsKey($asciiCode)) {
            Write-Verbose "Character '$char' (ASCII $asciiCode) not in font, using space"
            $asciiCode = 32  # Use space as fallback
        }

        $charBitmap = $fontData[$asciiCode]

        # Render character column by column
        for ($col = 0; $col -lt $charWidth; $col++) {
            $columnX = $currentX + $col

            # Skip if out of bounds
            if ($columnX -lt 0 -or $columnX -ge $script:SCREEN_WIDTH) {
                continue
            }

            $columnBits = $charBitmap[$col]

            # Render each row in this column
            for ($row = 0; $row -lt $charHeight; $row++) {
                # Check if this pixel is set (bit is 1)
                $bitSet = ($columnBits -band (1 -shl $row)) -ne 0

                if ($bitSet) {
                    $pixelY = $startY + $row

                    # Skip if out of bounds vertically
                    if ($pixelY -lt 0 -or $pixelY -ge $script:SCREEN_HEIGHT) {
                        continue
                    }

                    # Calculate pixel index in column-major order
                    # Column-major: col0(row0-8), col1(row0-8), col2(row0-8), ...
                    # Each pixel = 3 bytes (RGB)
                    $pixelIndex = ($columnX * $script:SCREEN_HEIGHT * 3) + ($pixelY * 3)

                    # Set RGB values
                    $pixelData[$pixelIndex] = $Color.R
                    $pixelData[$pixelIndex + 1] = $Color.G
                    $pixelData[$pixelIndex + 2] = $Color.B
                }
            }
        }

        # Move to next character position
        $currentX += $charWidth + $charSpacing
    }

    Write-Verbose "Rendered '$Text' as bitmap: ${textWidthPixels}px wide, starting at X=$startX"
    return $pixelData
}
