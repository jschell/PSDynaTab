function Clear-DynaTab {
    <#
    .SYNOPSIS
        Clears the DynaTab 75X display
    .DESCRIPTION
        Sends an all-black image to clear the LED matrix display.
    .EXAMPLE
        Clear-DynaTab
        Clears the display
    .NOTES
        Requires active connection (use Connect-DynaTab first)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("DynaTab display", "Clear screen")) {
        try {
            Write-Verbose "Clearing display..."

            # Create all-black image
            $bitmap = New-Object System.Drawing.Bitmap($script:SCREEN_WIDTH, $script:SCREEN_HEIGHT)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.Clear([System.Drawing.Color]::Black)
            $graphics.Dispose()

            # Send to display
            Send-DynaTabImage -Image $bitmap

            $bitmap.Dispose()

            Write-Verbose "Display cleared"

        } catch {
            throw "Failed to clear display: $($_.Exception.Message)"
        }
    }
}
