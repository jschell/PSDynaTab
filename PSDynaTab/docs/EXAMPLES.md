# PSDynaTab Examples

## Basic Usage

### Connect and Display Text

```powershell
Import-Module PSDynaTab

Connect-DynaTab
Set-DynaTabText "READY"
```

### Send an Image

```powershell
Send-DynaTabImage -Path "C:\Images\logo.png"
```

### Pipeline Support

```powershell
# Send all PNGs in current directory
Get-ChildItem *.png | Send-DynaTabImage

# With delay between images
Get-ChildItem *.png | ForEach-Object {
    Send-DynaTabImage -Path $_.FullName
    Start-Sleep -Seconds 2
}
```

## Advanced Usage

### Custom Image Creation

```powershell
# Create custom bitmap
$img = New-Object System.Drawing.Bitmap(60, 9)
$graphics = [System.Drawing.Graphics]::FromImage($img)

# Draw red rectangle
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red)
$graphics.FillRectangle($brush, 10, 2, 40, 5)

# Send to display
Send-DynaTabImage -Image $img

# Cleanup
$graphics.Dispose()
$brush.Dispose()
$img.Dispose()
```

### Monitoring Script

```powershell
# Display CPU usage every 5 seconds
while ($true) {
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time' |
           Select-Object -ExpandProperty CounterSamples |
           Select-Object -ExpandProperty CookedValue

    $cpuText = "CPU {0:N0}%" -f $cpu
    Set-DynaTabText $cpuText -Color Red

    Start-Sleep -Seconds 5
}
```

### Status Dashboard

```powershell
function Show-SystemStatus {
    param([switch]$Continuous)

    do {
        # Get system metrics
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        $mem = (Get-Counter '\Memory\% Committed Bytes In Use').CounterSamples.CookedValue

        # Choose color based on load
        $color = switch ($cpu) {
            {$_ -lt 50} { [System.Drawing.Color]::Green; break }
            {$_ -lt 80} { [System.Drawing.Color]::Yellow; break }
            default { [System.Drawing.Color]::Red }
        }

        $status = "CPU {0:N0}%" -f $cpu
        Set-DynaTabText $status -Color $color

        if ($Continuous) {
            Start-Sleep -Seconds 5
        }
    } while ($Continuous)
}

# Usage
Connect-DynaTab
Show-SystemStatus -Continuous
```

### Error Handling

```powershell
try {
    Connect-DynaTab -ErrorAction Stop

    if (Test-Path "logo.png") {
        Send-DynaTabImage -Path "logo.png"
    } else {
        Set-DynaTabText "NO LOGO"
    }

} catch {
    Write-Error "Failed to communicate with DynaTab: $_"
} finally {
    Disconnect-DynaTab
}
```

## Automation Examples

### Scheduled Task

```powershell
# Create scheduled task to show time every hour
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument @"
-NoProfile -Command "
    Import-Module PSDynaTab;
    Connect-DynaTab;
    Set-DynaTabText (Get-Date -Format 'HH:mm');
    Disconnect-DynaTab
"
"@

$trigger = New-ScheduledTaskTrigger -Once -At 12:00AM -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "DynaTab-Time" -Action $action -Trigger $trigger
```

### Profile Integration

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Auto-connect on profile load
if (Get-Module -ListAvailable PSDynaTab) {
    Import-Module PSDynaTab

    try {
        Connect-DynaTab -ErrorAction SilentlyContinue
        Set-DynaTabText "PS $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    } catch {
        # Silent fail
    }
}
```
