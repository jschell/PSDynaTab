#Requires -Version 5.1

<#
.SYNOPSIS
    PSDynaTab - PowerShell module for Epomaker DynaTab 75X control
.DESCRIPTION
    Provides functions to control the Epomaker DynaTab 75X keyboard's 60x9 LED matrix display.
    Supports sending images, text, and custom graphics via USB HID interface.
.NOTES
    Author: J Schell
    Version: 1.0.0
    Requires: HidSharp.dll (included in module)
#>

# Module-scoped variables (persistent across function calls)
$script:DynaTabDevice = $null
$script:HIDStream = $null
$script:DeviceConnected = $false

# Hardware constants
$script:VID = 0x3151
$script:PID = 0x4015
$script:INTERFACE_INDEX = 3        # MI_02 (Usage Page 65535)
$script:SCREEN_WIDTH = 60
$script:SCREEN_HEIGHT = 9
$script:PIXEL_COUNT = 540          # 60 * 9
$script:PIXEL_BYTES = 1620         # 60 * 9 * 3 (RGB)

# HID protocol constants
$script:FEATURE_REPORT_SIZE = 65   # 1 byte report ID + 64 byte payload
$script:PACKET_SIZE = 64
$script:HEADER_SIZE = 8
$script:PAYLOAD_SIZE = 56          # 64 - 8
$script:BASE_ADDRESS = 0x389D

# First packet (initialization)
$script:FIRST_PACKET = [byte[]]@(
    0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
    0x00, 0x00, 0x3c, 0x09, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
)

# Load HidSharp assembly
$hidSharpPath = Join-Path $PSScriptRoot 'lib\HidSharp.dll'
if (-not (Test-Path $hidSharpPath)) {
    throw "Required dependency HidSharp.dll not found at: $hidSharpPath`nPlease ensure the module is installed correctly."
}

try {
    Add-Type -Path $hidSharpPath -ErrorAction Stop
    Write-Verbose "HidSharp.dll loaded successfully from: $hidSharpPath"
} catch {
    throw "Failed to load HidSharp.dll: $($_.Exception.Message)"
}

# Import private functions (helpers, not exported)
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.Name)"
    } catch {
        throw "Failed to load private function $($function.Name): $($_.Exception.Message)"
    }
}

# Import public functions (exported to users)
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.Name)"
    } catch {
        throw "Failed to load public function $($function.Name): $($_.Exception.Message)"
    }
}

# Module cleanup handler (runs when module is removed)
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Verbose "PSDynaTab module being removed, cleaning up..."

    # Close HID stream if open
    if ($script:HIDStream) {
        try {
            $script:HIDStream.Close()
            Write-Verbose "HID stream closed"
        } catch {
            Write-Warning "Error closing HID stream: $($_.Exception.Message)"
        }
    }

    # Clear module variables
    $script:DynaTabDevice = $null
    $script:HIDStream = $null
    $script:DeviceConnected = $false

    Write-Verbose "PSDynaTab cleanup complete"
}

# Export module members (functions listed in manifest)
Export-ModuleMember -Function @(
    'Connect-DynaTab',
    'Disconnect-DynaTab',
    'Send-DynaTabImage',
    'Set-DynaTabText',
    'Clear-DynaTab',
    'Test-DynaTabConnection',
    'Get-DynaTabDevice'
)
