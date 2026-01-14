# PSDynaTab

PowerShell module for controlling the Epomaker DynaTab 75X keyboard's 60×9 LED matrix display.

## Features

- 🖼️ Send images to the LED display
- 📝 Display text with built-in VFD-style font
- 🎨 Full RGB color support
- 🔌 USB HID communication (no drivers needed)
- 📦 Pure PowerShell implementation
- 🧪 Full Pester test coverage

## Requirements

- **PowerShell**: 5.1+ (Windows) or 7.0+ (Cross-platform)
- **Hardware**: Epomaker DynaTab 75X keyboard connected via USB
- **Dependencies**: HidSharp.dll (included in module)

## Installation

### From Source

```powershell
# Clone repository
git clone https://github.com/yourusername/PSDynaTab.git

# Copy to PowerShell module path
$dest = "$env:USERPROFILE\Documents\PowerShell\Modules\PSDynaTab"
Copy-Item -Recurse .\PSDynaTab $dest

# Import module
Import-Module PSDynaTab
```

### From PowerShell Gallery (Future)

```powershell
Install-Module PSDynaTab
Import-Module PSDynaTab
```

## Quick Start

```powershell
# Import module
Import-Module PSDynaTab

# Connect to keyboard
Connect-DynaTab

# Display text
Set-DynaTabText "HELLO"

# Send an image
Send-DynaTabImage -Path "logo.png"

# Clear display
Clear-DynaTab

# Disconnect
Disconnect-DynaTab
```

## Commands

| Command | Description |
|---------|-------------|
| `Connect-DynaTab` | Connect to DynaTab keyboard |
| `Disconnect-DynaTab` | Disconnect from keyboard |
| `Send-DynaTabImage` | Send image to display |
| `Set-DynaTabText` | Display text on screen |
| `Clear-DynaTab` | Clear the display |
| `Test-DynaTabConnection` | Test connection status |
| `Get-DynaTabDevice` | Get device information |

## Examples

See [EXAMPLES.md](EXAMPLES.md) for detailed usage examples.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Contributing

Contributions welcome! Please read CONTRIBUTING.md first.

## License

MIT License - see LICENSE file for details.

## Credits

Based on the [aceamarco/dynatab75x-controller](https://github.com/aceamarco/dynatab75x-controller) Python implementation.
