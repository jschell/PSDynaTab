# PSDynaTab Troubleshooting

## Common Issues

### Device Not Found

**Error**: `No DynaTab 75X keyboard found`

**Solutions**:
1. Ensure keyboard is connected via **USB** (not Bluetooth/2.4GHz)
2. Try different USB port
3. Unplug and replug the keyboard
4. Check Device Manager for "HID-compliant device" entries

**Verify Detection**:
```powershell
# Check if Windows sees the device
Get-PnPDevice | Where-Object { $_.InstanceId -like "*VID_3151*" }
```

### Permission Denied

**Error**: `Access denied` or `Unable to open HID device`

**Solutions**:
1. Run PowerShell as Administrator
2. Close Epomaker official software (exclusive access conflict)
3. Restart PowerShell session

### HidSharp.dll Not Found

**Error**: `HidSharp.dll not found at: ...`

**Solutions**:
1. Verify module installation:
   ```powershell
   Get-Module PSDynaTab -ListAvailable
   ```
2. Reinstall module
3. Check that `lib\HidSharp.dll` exists in module directory

### Image Not Displaying

**Symptoms**: Commands succeed but screen doesn't change

**Solutions**:
1. Verify connection:
   ```powershell
   Test-DynaTabConnection  # Should return $true
   ```
2. Try clearing first:
   ```powershell
   Clear-DynaTab
   Start-Sleep -Seconds 1
   Send-DynaTabImage -Path "test.png"
   ```
3. Check image format (use PNG, JPG, BMP)
4. Verify image file exists and is readable

### Keyboard Becomes Unresponsive

**Symptoms**: Keyboard stops responding during operation

**Solutions**:
1. Unplug and replug keyboard (recovers immediately)
2. Always use proper disconnect:
   ```powershell
   Disconnect-DynaTab
   ```
3. Avoid interrupting operations with Ctrl+C

### Module Won't Import

**Error**: Various import errors

**Solutions**:
1. Check PowerShell version:
   ```powershell
   $PSVersionTable.PSVersion  # Should be 5.1 or higher
   ```
2. Verify .NET Framework (Windows PowerShell needs 4.5+)
3. Check module path:
   ```powershell
   $env:PSModulePath -split ';'
   ```
4. Try explicit import:
   ```powershell
   Import-Module "C:\Full\Path\To\PSDynaTab\PSDynaTab.psd1" -Force
   ```

## Diagnostic Commands

### Check Module Status

```powershell
# Module loaded?
Get-Module PSDynaTab

# Functions available?
Get-Command -Module PSDynaTab

# Module location
(Get-Module PSDynaTab).Path
```

### Test Hardware

```powershell
# Find all HID devices for DynaTab
[HidSharp.DeviceList]::Local.GetHidDevices(0x3151, 0x4015) |
    Format-Table @{L='Interface';E={$_.DevicePath}},
                 @{L='MaxOut';E={$_.GetMaxOutputReportLength()}},
                 @{L='MaxFeature';E={$_.GetMaxFeatureReportLength()}}
```

### Verbose Output

```powershell
# Enable verbose logging
$VerbosePreference = 'Continue'
Connect-DynaTab -Verbose
Send-DynaTabImage -Path "test.png" -Verbose
```

## Getting Help

### Built-in Help

```powershell
# Function help
Get-Help Connect-DynaTab -Full
Get-Help Send-DynaTabImage -Examples

# List all functions
Get-Command -Module PSDynaTab | Get-Help -Name {$_.Name} -Parameter *
```

### Report Issues

When reporting issues, include:

1. PowerShell version: `$PSVersionTable`
2. Module version: `(Get-Module PSDynaTab).Version`
3. OS version: `[System.Environment]::OSVersion`
4. Error message (full text)
5. Steps to reproduce

Create issue at: https://github.com/yourusername/PSDynaTab/issues
