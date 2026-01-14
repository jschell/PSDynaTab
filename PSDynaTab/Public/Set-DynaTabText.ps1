function Set-DynaTabText {
    <#
    .SYNOPSIS
        Displays text on the DynaTab 75X display
    .DESCRIPTION
        Renders text using a built-in VFD-style font and displays it on the LED matrix.
        Supports color customization and alignment.
    .PARAMETER Text
        Text to display (1-10 characters recommended)
    .PARAMETER Alignment
        Text alignment: Left, Center (default), or Right
    .PARAMETER Color
        Text color (default: Green)
    .EXAMPLE
        Set-DynaTabText "HELLO"
        Displays "HELLO" in center (green)
    .EXAMPLE
        Set-DynaTabText "CPU 45%" -Color Red -Alignment Left
        Displays red text aligned left
    .EXAMPLE
        "READY" | Set-DynaTabText
        Pipeline support
    .NOTES
        Requires active connection (use Connect-DynaTab first)
        Uses built-in 5x7 pixel VFD-style font
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [ValidateLength(1, 10)]
        [string]$Text,

        [Parameter()]
        [ValidateSet('Left', 'Center', 'Right')]
        [string]$Alignment = 'Center',

        [Parameter()]
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(0, 255, 0) # Green
    )

    process {
        if ($PSCmdlet.ShouldProcess($Text, "Display text on DynaTab")) {

            try {
                Write-Verbose "Rendering text: '$Text' (Alignment: $Alignment, Color: $($Color.Name))"

                # Create blank image
                $bitmap = New-Object System.Drawing.Bitmap($script:SCREEN_WIDTH, $script:SCREEN_HEIGHT)
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.Clear([System.Drawing.Color]::Black)

                # Simple VFD-style font rendering (5x7 per character, 1px spacing)
                # TODO: Implement full font rendering
                # For now, use System.Drawing.Font as fallback

                $font = New-Object System.Drawing.Font("Consolas", 6, [System.Drawing.FontStyle]::Bold)
                $brush = New-Object System.Drawing.SolidBrush($Color)
                $format = New-Object System.Drawing.StringFormat

                switch ($Alignment) {
                    'Left' { $format.Alignment = [System.Drawing.StringAlignment]::Near }
                    'Center' { $format.Alignment = [System.Drawing.StringAlignment]::Center }
                    'Right' { $format.Alignment = [System.Drawing.StringAlignment]::Far }
                }

                $format.LineAlignment = [System.Drawing.StringAlignment]::Center

                $rect = New-Object System.Drawing.RectangleF(0, 0, $script:SCREEN_WIDTH, $script:SCREEN_HEIGHT)
                $graphics.DrawString($Text, $font, $brush, $rect, $format)

                # Cleanup
                $graphics.Dispose()
                $font.Dispose()
                $brush.Dispose()
                $format.Dispose()

                # Send to display
                Send-DynaTabImage -Image $bitmap

                $bitmap.Dispose()

            } catch {
                throw "Failed to display text: $($_.Exception.Message)"
            }
        }
    }
}
