# PSDynaTab

PowerShell module for controlling the Epomaker DynaTab 75X keyboard's 60×9 LED matrix display.

## Features

- 🖼️ Send images to the LED display
- 📝 Display text with built-in rendering
- 🎨 Full RGB color support
- 🔌 USB HID communication (no drivers needed)
- 📦 Pure PowerShell implementation
- 🧪 Full Pester test coverage

## Quick Start

```powershell
# Import module
Import-Module .\PSDynaTab\PSDynaTab.psd1

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

## Requirements

- **PowerShell**: 5.1+ (Windows) or 7.0+ (Cross-platform)
- **Hardware**: Epomaker DynaTab 75X keyboard connected via USB
- **Dependencies**: HidSharp.dll (downloaded automatically by Build.ps1)

## Installation

### Quick Install from GitHub (Recommended)

**One-line installer** (downloads and installs automatically):

```powershell
irm https://raw.githubusercontent.com/jschell/PSDynaTab/main/Install.ps1 | iex
```

Or download and run the installer:

```powershell
# Download installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jschell/PSDynaTab/main/Install.ps1" -OutFile "Install.ps1"

# Run installer
.\Install.ps1
```

**Installation Options:**

```powershell
# Install from specific branch
.\Install.ps1 -Branch "claude/powershell-dynatab-module-a8B5h"

# Install for all users (requires admin)
.\Install.ps1 -Scope AllUsers

# Skip tests during installation
.\Install.ps1 -SkipTests
```

### Manual Installation from Source

1. Clone the repository:
   ```powershell
   git clone https://github.com/jschell/PSDynaTab.git
   cd PSDynaTab
   ```

2. Run the build script to download dependencies:
   ```powershell
   .\Build.ps1
   ```

3. Copy module to PowerShell modules directory:
   ```powershell
   Copy-Item -Recurse .\PSDynaTab "$env:USERPROFILE\Documents\PowerShell\Modules\"
   ```

4. Import the module:
   ```powershell
   Import-Module PSDynaTab
   ```

## Available Commands

| Command | Description |
|---------|-------------|
| `Connect-DynaTab` | Connect to DynaTab keyboard |
| `Disconnect-DynaTab` | Disconnect from keyboard |
| `Send-DynaTabImage` | Send image to display |
| `Set-DynaTabText` | Display text on screen |
| `Clear-DynaTab` | Clear the display |
| `Test-DynaTabConnection` | Test connection status |
| `Get-DynaTabDevice` | Get device information |

## Documentation

- [Full Documentation](PSDynaTab/docs/README.md)
- [Usage Examples](PSDynaTab/docs/EXAMPLES.md)
- [Troubleshooting Guide](PSDynaTab/docs/TROUBLESHOOTING.md)

## Building

Run the build script to download dependencies and run tests:

```powershell
.\Build.ps1
```

To update the version:

```powershell
.\Build.ps1 -Version "1.1.0"
```

## Testing

The module includes Pester tests. To run them:

```powershell
# Install Pester 5.0+ if needed
Install-Module Pester -MinimumVersion 5.0.0 -Force

# Run all tests
Invoke-Pester .\PSDynaTab\Tests

# Run specific tests
Invoke-Pester .\PSDynaTab\Tests -Tag 'Integration'
```

## Project Structure

```
PSDynaTab/
├── PSDynaTab/
│   ├── PSDynaTab.psd1              # Module manifest
│   ├── PSDynaTab.psm1              # Main module file
│   ├── lib/
│   │   └── HidSharp.dll            # HID library (downloaded by Build.ps1)
│   ├── Private/                    # Internal functions
│   │   ├── Initialize-HIDDevice.ps1
│   │   ├── Send-FeaturePacket.ps1
│   │   ├── ConvertTo-PixelData.ps1
│   │   └── New-PacketChunk.ps1
│   ├── Public/                     # Exported functions
│   │   ├── Connect-DynaTab.ps1
│   │   ├── Disconnect-DynaTab.ps1
│   │   ├── Send-DynaTabImage.ps1
│   │   ├── Set-DynaTabText.ps1
│   │   ├── Clear-DynaTab.ps1
│   │   ├── Test-DynaTabConnection.ps1
│   │   └── Get-DynaTabDevice.ps1
│   ├── Tests/                      # Pester tests
│   │   ├── PSDynaTab.Tests.ps1
│   │   └── TestImages/
│   └── docs/                       # Documentation
│       ├── README.md
│       ├── EXAMPLES.md
│       └── TROUBLESHOOTING.md
├── Build.ps1                       # Build script
├── Install.ps1                     # Installation script
├── LICENSE                         # MIT License
└── README.md                       # This file
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Based on the [aceamarco/dynatab75x-controller](https://github.com/aceamarco/dynatab75x-controller) Python implementation.

## Disclaimer

This is an unofficial, community-developed module. It is not affiliated with or endorsed by Epomaker.
