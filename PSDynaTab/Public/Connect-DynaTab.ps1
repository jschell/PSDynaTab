function Connect-DynaTab {
    <#
    .SYNOPSIS
        Connects to DynaTab 75X keyboard
    .DESCRIPTION
        Establishes USB HID connection to the DynaTab 75X keyboard's LED display interface.
        Must be called before using other display functions.
    .EXAMPLE
        Connect-DynaTab
        Connects to the keyboard
    .EXAMPLE
        Connect-DynaTab -Verbose
        Connects with detailed progress information
    .OUTPUTS
        PSCustomObject with connection details
    .NOTES
        Requires DynaTab 75X to be connected via USB (not Bluetooth/2.4GHz)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Check if already connected
    if ($script:DeviceConnected) {
        Write-Warning "Already connected to DynaTab device. Use Disconnect-DynaTab first to reconnect."
        return Get-DynaTabDevice
    }

    try {
        Write-Verbose "Initializing HID device connection..."

        # Find device
        $script:DynaTabDevice = Initialize-HIDDevice

        # Open HID stream
        Write-Verbose "Opening HID stream..."
        $script:HIDStream = $script:DynaTabDevice.Open()

        if ($null -eq $script:HIDStream) {
            throw "Failed to open HID stream"
        }

        Write-Verbose "HID stream opened successfully"

        # Send initialization packet
        Write-Verbose "Sending initialization packet..."
        Send-FeaturePacket -Packet $script:FIRST_PACKET -Stream $script:HIDStream

        $script:DeviceConnected = $true

        Write-Host "✓ Connected to DynaTab 75X" -ForegroundColor Green

        # Return connection info
        return [PSCustomObject]@{
            Connected = $true
            DevicePath = $script:DynaTabDevice.DevicePath
            VendorID = "0x$($script:VID.ToString('X4'))"
            ProductID = "0x$($script:PID.ToString('X4'))"
            ScreenSize = "${script:SCREEN_WIDTH}x${script:SCREEN_HEIGHT}"
            ProductName = $script:DynaTabDevice.GetProductName()
        }

    } catch {
        $script:DeviceConnected = $false
        $script:DynaTabDevice = $null
        $script:HIDStream = $null

        throw "Failed to connect to DynaTab: $($_.Exception.Message)"
    }
}
