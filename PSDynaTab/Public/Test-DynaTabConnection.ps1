function Test-DynaTabConnection {
    <#
    .SYNOPSIS
        Tests DynaTab 75X connection
    .DESCRIPTION
        Checks if the DynaTab is connected and responsive.
    .EXAMPLE
        Test-DynaTabConnection
        Returns $true if connected
    .EXAMPLE
        if (Test-DynaTabConnection) { Send-DynaTabImage "logo.png" }
        Conditional execution
    .OUTPUTS
        Boolean
    .NOTES
        Does not attempt to connect, only checks current status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not $script:DeviceConnected) {
        Write-Verbose "Not connected to device"
        return $false
    }

    try {
        # Try to get product string as connection test
        $productName = $script:DynaTabDevice.GetProductName()
        Write-Verbose "Device responsive: $productName"
        return $true

    } catch {
        Write-Warning "Device appears connected but is not responsive: $($_.Exception.Message)"
        return $false
    }
}
