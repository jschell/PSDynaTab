@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PSDynaTab.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '8f3c4d2e-9b5a-4f1e-a7c6-3d2e1f9b8a5c'

    # Author of this module
    Author = 'J Schell'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2026 J Schell. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for controlling Epomaker DynaTab 75X keyboard LED matrix display via USB HID. Send images, text, and custom graphics to the 60x9 pixel screen.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @('lib\HidSharp.dll')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Connect-DynaTab',
        'Disconnect-DynaTab',
        'Send-DynaTabImage',
        'Set-DynaTabText',
        'Clear-DynaTab',
        'Test-DynaTabConnection',
        'Get-DynaTabDevice',
        'Show-DynaTabSpinner'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Epomaker', 'DynaTab', 'DynaTab75X', 'HID', 'Keyboard', 'LED', 'Display', 'Matrix', 'USB', 'Hardware')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/yourusername/PSDynaTab/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/yourusername/PSDynaTab'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 1.0.0 (Initial Release)
- Connect to DynaTab 75X via USB HID
- Send images to 60x9 LED matrix display
- Display text with built-in VFD-style font
- Clear screen functionality
- Device detection and connection testing
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
