function Set-DynaTabText {
    <#
    .SYNOPSIS
        Displays text on the DynaTab 75X display
    .DESCRIPTION
        Renders text using a built-in 5x7 bitmap font and displays it on the LED matrix.
        Supports color customization and alignment. Max 10 characters.
    .PARAMETER Text
        Text to display (max 10 characters for 5x7 font)
    .PARAMETER Alignment
        Text alignment: Left, Center (default), or Right
    .PARAMETER Color
        Text color (default: Green)
    .PARAMETER Font
        Font definition hashtable (default: CP437-5x7 bitmap font)
    .EXAMPLE
        Set-DynaTabText "HELLO"
        Displays "HELLO" in center (green) using bitmap font
    .EXAMPLE
        Set-DynaTabText "CPU 45%" -Color Red -Alignment Left
        Displays red text aligned left
    .EXAMPLE
        "READY" | Set-DynaTabText
        Pipeline support
    .NOTES
        Requires active connection (use Connect-DynaTab first)
        Uses pixel-perfect 5x7 CP437 bitmap font for crisp display
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
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(0, 255, 0), # Green

        [Parameter()]
        [hashtable]$Font = $script:DEFAULT_FONT
    )

    process {
        if ($PSCmdlet.ShouldProcess($Text, "Display text on DynaTab")) {

            try {
                # Verify connection
                if (-not $script:DeviceConnected) {
                    throw "Not connected to DynaTab. Use Connect-DynaTab first."
                }

                # Check if bitmap font is available
                if ($null -eq $Font) {
                    throw "Bitmap font not loaded. Module may be corrupted."
                }

                Write-Verbose "Rendering text using bitmap font: '$Text' (Alignment: $Alignment, Color: $($Color.Name))"

                # Convert text to pixel data using bitmap font
                $pixelData = ConvertTo-BitmapText -Text $Text -Font $Font -Color $Color -Alignment $Alignment

                # CRITICAL: Device requires reinitialization before each send
                Write-Verbose "Reinitializing device for text send..."
                Send-FeaturePacket -Packet $script:FIRST_PACKET -Stream $script:HIDStream
                Start-Sleep -Milliseconds 10

                # Chunk into packets
                $packets = New-PacketChunk -PixelData $pixelData

                Write-Verbose "Sending $($packets.Count) packets to device..."

                # Send all packets
                foreach ($packet in $packets) {
                    Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
                }

                Write-Verbose "Text sent successfully ($($packets.Count) packets)"

            } catch {
                throw "Failed to display text: $($_.Exception.Message)"
            }
        }
    }
}
