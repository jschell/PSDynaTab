function Disconnect-DynaTab {
    <#
    .SYNOPSIS
        Disconnects from DynaTab 75X keyboard
    .DESCRIPTION
        Closes the HID connection and releases resources.
    .EXAMPLE
        Disconnect-DynaTab
        Disconnects from the keyboard
    .NOTES
        Safe to call even if not connected
    #>
    [CmdletBinding()]
    param()

    if (-not $script:DeviceConnected) {
        Write-Verbose "Not connected to any device"
        return
    }

    try {
        if ($script:HIDStream) {
            Write-Verbose "Closing HID stream..."
            $script:HIDStream.Close()
        }

        $script:HIDStream = $null
        $script:DynaTabDevice = $null
        $script:DeviceConnected = $false

        Write-Host "✓ Disconnected from DynaTab 75X" -ForegroundColor Green

    } catch {
        Write-Warning "Error during disconnect: $($_.Exception.Message)"

        # Force cleanup even on error
        $script:HIDStream = $null
        $script:DynaTabDevice = $null
        $script:DeviceConnected = $false
    }
}
