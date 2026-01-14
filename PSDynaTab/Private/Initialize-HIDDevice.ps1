function Initialize-HIDDevice {
    <#
    .SYNOPSIS
        Initializes connection to DynaTab 75X HID interface
    .DESCRIPTION
        Enumerates USB HID devices, finds the DynaTab 75X screen control interface (MI_02),
        and returns the device object for communication.
    .OUTPUTS
        HidSharp.HidDevice object
    .NOTES
        Internal function - not exported
    #>
    [CmdletBinding()]
    [OutputType([HidSharp.HidDevice])]
    param()

    Write-Verbose "Searching for DynaTab 75X devices (VID: 0x$($script:VID.ToString('X4')), PID: 0x$($script:PID.ToString('X4')))"

    # Enumerate all HID devices matching VID/PID
    $devices = @([HidSharp.DeviceList]::Local.GetHidDevices($script:VID, $script:PID))

    if ($devices.Count -eq 0) {
        throw "No DynaTab 75X keyboard found. Please ensure it is connected via USB (not Bluetooth/2.4GHz)."
    }

    Write-Verbose "Found $($devices.Count) HID interfaces for DynaTab 75X"

    # Find the screen control interface (MI_02, Usage Page 65535)
    # This is interface 3 in the array (index starts at 0)
    $screenDevice = $null

    foreach ($dev in $devices) {
        $path = $dev.DevicePath.ToLower()

        # Looking for MI_02 interface (vendor-specific usage page 0xFFFF / 65535)
        if ($path -like "*mi_02*") {
            $featureReportSize = $dev.GetMaxFeatureReportLength()

            if ($featureReportSize -eq 65) {
                $screenDevice = $dev
                Write-Verbose "Found screen control interface: $($dev.DevicePath)"
                Write-Verbose "Feature report size: $featureReportSize bytes"
                break
            }
        }
    }

    if ($null -eq $screenDevice) {
        throw "Could not find DynaTab 75X screen control interface (MI_02). Found $($devices.Count) interfaces but none match expected configuration."
    }

    return $screenDevice
}
