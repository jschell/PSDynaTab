#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import module
    $modulePath = Split-Path $PSScriptRoot -Parent
    Import-Module "$modulePath\PSDynaTab.psd1" -Force
}

Describe 'PSDynaTab Module' {

    Context 'Module Loading' {
        It 'Imports without errors' {
            { Get-Module PSDynaTab } | Should -Not -Throw
        }

        It 'Exports expected functions' {
            $commands = (Get-Command -Module PSDynaTab).Name
            $commands | Should -Contain 'Connect-DynaTab'
            $commands | Should -Contain 'Send-DynaTabImage'
            $commands | Should -Contain 'Set-DynaTabText'
            $commands | Should -Contain 'Clear-DynaTab'
        }

        It 'Loads HidSharp assembly' {
            [HidSharp.DeviceList] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Device Detection' -Tag 'Integration' {
        It 'Finds DynaTab device' {
            $devices = [HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015)
            $devices.Count | Should -BeGreaterThan 0
        }

        It 'Identifies MI_02 interface' {
            $devices = [HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015)
            $screenDevice = $devices | Where-Object {
                $_.DevicePath.ToLower() -like "*mi_02*" -and
                $_.GetMaxFeatureReportLength() -eq 65
            }
            $screenDevice | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Connection Management' -Tag 'Integration' {
        It 'Connects successfully' {
            { Connect-DynaTab } | Should -Not -Throw
            Test-DynaTabConnection | Should -Be $true
        }

        It 'Gets device info' {
            $info = Get-DynaTabDevice
            $info.Connected | Should -Be $true
            $info.VendorID | Should -Be '0x3151'
        }

        It 'Disconnects cleanly' {
            { Disconnect-DynaTab } | Should -Not -Throw
            Test-DynaTabConnection | Should -Be $false
        }
    }

    Context 'Image Operations' -Tag 'Integration' {
        BeforeAll {
            Connect-DynaTab
        }

        AfterAll {
            Disconnect-DynaTab
        }

        It 'Sends test image' {
            $testImage = "$PSScriptRoot\TestImages\test_red.png"
            { Send-DynaTabImage -Path $testImage } | Should -Not -Throw
        }

        It 'Clears display' {
            { Clear-DynaTab } | Should -Not -Throw
        }

        It 'Displays text' {
            { Set-DynaTabText "TEST" } | Should -Not -Throw
        }
    }
}
