function Send-FeaturePacket {
    <#
    .SYNOPSIS
        Sends a feature report packet to the HID device
    .DESCRIPTION
        Wraps a 64-byte packet with report ID (0x00) and transmits via HID feature report.
        Includes timing delay for device processing.
    .PARAMETER Packet
        64-byte array to send
    .PARAMETER Stream
        Open HID stream object
    .NOTES
        Internal function - not exported
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [byte[]]$Packet,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Stream
    )

    if ($Packet.Length -ne 64) {
        throw "Packet must be exactly 64 bytes, received $($Packet.Length) bytes"
    }

    # Prepend report ID (0x00) to make 65-byte feature report
    $featureReport = New-Object byte[] 65
    $featureReport[0] = 0x00  # Report ID

    for ($i = 0; $i -lt 64; $i++) {
        $featureReport[$i + 1] = $Packet[$i]
    }

    try {
        $Stream.SetFeature($featureReport)
        Write-Verbose "Feature packet sent (65 bytes)"

        # Device processing delay (Python implementation uses 5ms)
        Start-Sleep -Milliseconds 5

    } catch {
        throw "Failed to send feature packet: $($_.Exception.Message)"
    }
}
