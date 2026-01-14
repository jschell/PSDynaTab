function ConvertTo-PixelData {
    <#
    .SYNOPSIS
        Converts an image to DynaTab pixel data
    .DESCRIPTION
        Loads an image (from file or object), resizes to 60x9, and converts to
        column-major RGB byte array (1620 bytes total).
    .PARAMETER Path
        Path to image file (PNG, JPG, BMP, GIF)
    .PARAMETER Image
        System.Drawing.Image object
    .OUTPUTS
        byte[] - 1620 bytes (60 cols × 9 rows × 3 RGB)
    .NOTES
        Internal function - not exported
        Pixel order: Column-major (col 0-59, each containing rows 0-8, each containing RGB)
    #>
    [CmdletBinding(DefaultParameterSetName='Path')]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory, ParameterSetName='Path')]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName='Image')]
        [ValidateNotNull()]
        [System.Drawing.Image]$Image
    )

    try {
        # Load image
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Write-Verbose "Loading image from: $Path"
            $img = [System.Drawing.Image]::FromFile($Path)
        } else {
            $img = $Image
        }

        Write-Verbose "Original image: $($img.Width)x$($img.Height), Format: $($img.PixelFormat)"

        # Convert to RGB (remove alpha channel)
        $bitmap = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.DrawImage($img, 0, 0, $img.Width, $img.Height)
        $graphics.Dispose()

        # Resize to 60x9 if needed
        if ($bitmap.Width -ne $script:SCREEN_WIDTH -or $bitmap.Height -ne $script:SCREEN_HEIGHT) {
            Write-Verbose "Resizing image from $($bitmap.Width)x$($bitmap.Height) to ${script:SCREEN_WIDTH}x${script:SCREEN_HEIGHT}"

            $resized = New-Object System.Drawing.Bitmap($script:SCREEN_WIDTH, $script:SCREEN_HEIGHT)
            $graphics = [System.Drawing.Graphics]::FromImage($resized)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($bitmap, 0, 0, $script:SCREEN_WIDTH, $script:SCREEN_HEIGHT)
            $graphics.Dispose()

            $bitmap.Dispose()
            $bitmap = $resized
        }

        # Convert to byte array in column-major order
        $pixelData = New-Object byte[] $script:PIXEL_BYTES
        $index = 0

        for ($col = 0; $col -lt $script:SCREEN_WIDTH; $col++) {
            for ($row = 0; $row -lt $script:SCREEN_HEIGHT; $row++) {
                $pixel = $bitmap.GetPixel($col, $row)

                $pixelData[$index++] = $pixel.R
                $pixelData[$index++] = $pixel.G
                $pixelData[$index++] = $pixel.B
            }
        }

        $bitmap.Dispose()
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $img.Dispose()
        }

        Write-Verbose "Converted image to $($pixelData.Length) bytes of pixel data"
        return $pixelData

    } catch {
        throw "Failed to convert image to pixel data: $($_.Exception.Message)"
    }
}
