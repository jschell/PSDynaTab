function Get-DynaTabDevice {
    <#
    .SYNOPSIS
        Gets DynaTab 75X device information
    .DESCRIPTION
        Returns details about the connected DynaTab device, or available devices if not connected.
    .EXAMPLE
        Get-DynaTabDevice
        Shows current device info
    .EXAMPLE
        Get-DynaTabDevice | Format-List
        Detailed view
    .OUTPUTS
        PSCustomObject with device details
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if ($script:DeviceConnected -and $script:DynaTabDevice) {
        # Return connected device info
        return [PSCustomObject]@{
            PSTypeName = 'PSDynaTab.DeviceInfo'
            Connected = $true
            DevicePath = $script:DynaTabDevice.DevicePath
            VendorID = "0x$($script:VID.ToString('X4'))"
            ProductID = "0x$($script:PID.ToString('X4'))"
            ProductName = $script:DynaTabDevice.GetProductName()
            ManufacturerString = try { $script:DynaTabDevice.GetManufacturer() } catch { "N/A" }
            ScreenSize = "${script:SCREEN_WIDTH}x${script:SCREEN_HEIGHT}"
            PixelCount = $script:PIXEL_COUNT
            InterfaceNumber = "MI_02"
        }
    } else {
        # Search for available devices
        $devices = @([HidSharp.DeviceList]::Local.GetHidDevices($script:VID, $script:PID))

        if ($devices.Count -eq 0) {
            Write-Warning "No DynaTab 75X devices found"
            return $null
        }

        # Return info about available (but not connected) device
        $device = $devices[0]
        return [PSCustomObject]@{
            PSTypeName = 'PSDynaTab.DeviceInfo'
            Connected = $false
            DevicePath = $device.DevicePath
            VendorID = "0x$($script:VID.ToString('X4'))"
            ProductID = "0x$($script:PID.ToString('X4'))"
            ProductName = try { $device.GetProductName() } catch { "DynaTab 75X" }
            InterfacesFound = $devices.Count
            Message = "Use Connect-DynaTab to establish connection"
        }
    }
}
