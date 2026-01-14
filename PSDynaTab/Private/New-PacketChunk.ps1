function New-PacketChunk {
    <#
    .SYNOPSIS
        Chunks pixel data into HID packets
    .DESCRIPTION
        Splits 1620-byte pixel data into 56-byte payloads with 8-byte headers,
        creating properly formatted 64-byte HID packets.
    .PARAMETER PixelData
        1620-byte RGB pixel array
    .PARAMETER BaseAddress
        Starting address for decrementing counter (default: 0x389D)
    .OUTPUTS
        byte[][] - Array of 64-byte packets
    .NOTES
        Internal function - not exported
        Packet structure:
        [0] = 0x29 (fixed)
        [1] = frame index (0 for static image)
        [2] = 0x01 (image mode)
        [3] = 0x00 (fixed)
        [4-5] = incrementing counter (little-endian)
        [6-7] = decrementing address (big-endian)
        [8-63] = pixel data (56 bytes max)
    #>
    [CmdletBinding()]
    [OutputType([byte[][]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [byte[]]$PixelData,

        [Parameter()]
        [int]$BaseAddress = 0x389D
    )

    if ($PixelData.Length -ne $script:PIXEL_BYTES) {
        throw "PixelData must be exactly $($script:PIXEL_BYTES) bytes, received $($PixelData.Length) bytes"
    }

    $packets = [System.Collections.Generic.List[byte[]]]::new()
    $incrementing = 0
    $decrementing = $BaseAddress

    for ($offset = 0; $offset -lt $PixelData.Length; $offset += $script:PAYLOAD_SIZE) {
        $chunkSize = [Math]::Min($script:PAYLOAD_SIZE, $PixelData.Length - $offset)

        $packet = New-Object byte[] 64

        # Header (8 bytes)
        $packet[0] = 0x29                                    # Fixed header byte
        $packet[1] = 0x00                                    # Frame index (0 for static image)
        $packet[2] = 0x01                                    # Image mode
        $packet[3] = 0x00                                    # Fixed

        # Incrementing counter (little-endian, 2 bytes)
        $packet[4] = $incrementing -band 0xFF
        $packet[5] = ($incrementing -shr 8) -band 0xFF

        # Decrementing address (big-endian, 2 bytes)
        $packet[6] = ($decrementing -shr 8) -band 0xFF
        $packet[7] = $decrementing -band 0xFF

        # Pixel payload (56 bytes max)
        for ($i = 0; $i -lt $chunkSize; $i++) {
            $packet[8 + $i] = $PixelData[$offset + $i]
        }

        # Remaining bytes are already 0x00 (New-Object initializes to zero)

        $packets.Add($packet)

        $incrementing++
        $decrementing--
    }

    Write-Verbose "Generated $($packets.Count) packets from pixel data"
    return $packets.ToArray()
}
