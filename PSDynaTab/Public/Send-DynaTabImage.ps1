function Send-DynaTabImage {
    <#
    .SYNOPSIS
        Sends an image to the DynaTab 75X display
    .DESCRIPTION
        Converts and sends an image to the keyboard's 60x9 LED matrix display.
        Automatically resizes images to fit the display.
    .PARAMETER Path
        Path to image file (PNG, JPG, BMP, GIF)
    .PARAMETER Image
        System.Drawing.Image object
    .PARAMETER PassThru
        Returns the image object after sending
    .EXAMPLE
        Send-DynaTabImage -Path "logo.png"
        Sends logo.png to the display
    .EXAMPLE
        Get-ChildItem *.png | Send-DynaTabImage
        Sends all PNG files in current directory (pipeline)
    .EXAMPLE
        $img = New-Object System.Drawing.Bitmap(60, 9)
        # ... draw on image ...
        Send-DynaTabImage -Image $img
        Sends a programmatically created image
    .NOTES
        Requires active connection (use Connect-DynaTab first)
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Path')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName='Path', Position=0)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName='Image')]
        [ValidateNotNull()]
        [System.Drawing.Image]$Image,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        # Verify connection
        if (-not $script:DeviceConnected) {
            throw "Not connected to DynaTab. Use Connect-DynaTab first."
        }
    }

    process {
        try {
            $imageName = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Split-Path $Path -Leaf
            } else {
                "Image object"
            }

            if ($PSCmdlet.ShouldProcess($imageName, "Send image to DynaTab display")) {

                Write-Verbose "Processing image: $imageName"

                # Convert image to pixel data
                $pixelData = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    ConvertTo-PixelData -Path $Path
                } else {
                    ConvertTo-PixelData -Image $Image
                }

                # CRITICAL: Device requires reinitialization before each send
                # Send init packet to prepare device for new image data
                Write-Verbose "Reinitializing device for image send..."
                Send-FeaturePacket -Packet $script:FIRST_PACKET -Stream $script:HIDStream
                Start-Sleep -Milliseconds 10

                # Chunk into packets
                $packets = New-PacketChunk -PixelData $pixelData

                Write-Verbose "Sending $($packets.Count) packets to device..."

                # Send all packets with progress bar
                $packetNumber = 0
                foreach ($packet in $packets) {
                    $packetNumber++

                    # Show progress for multi-packet sends
                    if ($packets.Count -gt 5) {
                        $percentComplete = [int](($packetNumber / $packets.Count) * 100)
                        Write-Progress -Activity "Sending image to DynaTab" `
                                     -Status "Packet $packetNumber of $($packets.Count)" `
                                     -PercentComplete $percentComplete
                    }

                    Send-FeaturePacket -Packet $packet -Stream $script:HIDStream
                }

                # Clear progress bar
                if ($packets.Count -gt 5) {
                    Write-Progress -Activity "Sending image to DynaTab" -Completed
                }

                Write-Verbose "Image sent successfully ($($packets.Count) packets)"

                if ($PassThru -and $PSCmdlet.ParameterSetName -eq 'Image') {
                    return $Image
                }
            }

        } catch {
            throw "Failed to send image: $($_.Exception.Message)"
        }
    }
}
