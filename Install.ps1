#Requires -Version 5.1

<#
.SYNOPSIS
    Installs PSDynaTab PowerShell module from GitHub
.DESCRIPTION
    Downloads the PSDynaTab module from GitHub, installs dependencies (HidSharp.dll),
    and copies the module to the user's PowerShell modules directory.
.PARAMETER Branch
    GitHub branch to install from (default: main)
.PARAMETER Scope
    Installation scope: CurrentUser (default) or AllUsers (requires admin)
.PARAMETER SkipTests
    Skip running Pester tests during installation
.EXAMPLE
    .\Install.ps1
    Installs the module for the current user from the main branch
.EXAMPLE
    .\Install.ps1 -Branch "claude/powershell-dynatab-module-a8B5h"
    Installs from a specific branch
.EXAMPLE
    .\Install.ps1 -Scope AllUsers
    Installs for all users (requires administrator privileges)
.NOTES
    Can be run directly from GitHub:
    irm https://raw.githubusercontent.com/jschell/PSDynaTab/main/Install.ps1 | iex
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Branch = 'main',

    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [Parameter()]
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Faster downloads

# Banner
Write-Host @"

╔═══════════════════════════════════════════════════════╗
║                                                       ║
║              PSDynaTab Module Installer               ║
║         Epomaker DynaTab 75X LED Controller           ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Configuration
$repo = "jschell/PSDynaTab"
$moduleName = "PSDynaTab"

# Determine installation path
if ($Scope -eq 'AllUsers') {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $modulesPath = "$env:ProgramFiles\PowerShell\Modules"
    } else {
        $modulesPath = "$env:ProgramFiles\WindowsPowerShell\Modules"
    }

    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "AllUsers scope requires administrator privileges. Please run PowerShell as Administrator or use -Scope CurrentUser"
    }
} else {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $modulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
    } else {
        $modulesPath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    }
}

$moduleInstallPath = Join-Path $modulesPath $moduleName
$tempDir = Join-Path $env:TEMP "PSDynaTab-install-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Installation Configuration:" -ForegroundColor Yellow
Write-Host "  Repository: $repo"
Write-Host "  Branch: $Branch"
Write-Host "  Scope: $Scope"
Write-Host "  Install Path: $moduleInstallPath"
Write-Host ""

try {
    # Create temp directory
    Write-Host "[1/5] Creating temporary directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    Write-Host "  ✓ Created: $tempDir" -ForegroundColor Green

    # Download repository
    Write-Host "`n[2/5] Downloading module from GitHub..." -ForegroundColor Cyan
    $zipUrl = "https://github.com/$repo/archive/refs/heads/$Branch.zip"
    $zipPath = Join-Path $tempDir "PSDynaTab.zip"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Write-Host "  ✓ Downloaded: $zipUrl" -ForegroundColor Green
    } catch {
        throw "Failed to download from GitHub. Please check the branch name and your internet connection. Error: $($_.Exception.Message)"
    }

    # Extract archive
    Write-Host "`n[3/5] Extracting archive..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    # Find extracted folder (name will be PSDynaTab-{branch})
    $extractedFolder = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "PSDynaTab-*" } | Select-Object -First 1
    if (-not $extractedFolder) {
        throw "Failed to find extracted module folder"
    }
    Write-Host "  ✓ Extracted to: $($extractedFolder.FullName)" -ForegroundColor Green

    # Download HidSharp.dll dependency
    Write-Host "`n[4/5] Downloading dependencies..." -ForegroundColor Cyan
    $buildScriptPath = Join-Path $extractedFolder.FullName "Build.ps1"

    if (Test-Path $buildScriptPath) {
        Push-Location $extractedFolder.FullName
        try {
            if ($SkipTests) {
                & $buildScriptPath -SkipTests -ErrorAction Stop
            } else {
                & $buildScriptPath -ErrorAction Stop
            }
            Write-Host "  ✓ Dependencies downloaded successfully" -ForegroundColor Green
        } catch {
            Write-Warning "Build script encountered an error, but continuing with installation..."
            Write-Warning $_.Exception.Message
        } finally {
            Pop-Location
        }
    } else {
        Write-Warning "Build.ps1 not found. HidSharp.dll may need to be downloaded manually."
    }

    # Install module
    Write-Host "`n[5/5] Installing module..." -ForegroundColor Cyan

    # Remove existing installation if present
    if (Test-Path $moduleInstallPath) {
        Write-Host "  Removing existing installation..." -ForegroundColor Yellow
        Remove-Item -Path $moduleInstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create modules directory if it doesn't exist
    $modulesDir = Split-Path $moduleInstallPath -Parent
    if (-not (Test-Path $modulesDir)) {
        New-Item -ItemType Directory -Force -Path $modulesDir | Out-Null
    }

    # Copy module files
    $sourceModulePath = Join-Path $extractedFolder.FullName "PSDynaTab"
    if (-not (Test-Path $sourceModulePath)) {
        throw "Module source directory not found at: $sourceModulePath"
    }

    Copy-Item -Path $sourceModulePath -Destination $moduleInstallPath -Recurse -Force
    Write-Host "  ✓ Installed to: $moduleInstallPath" -ForegroundColor Green

    # Verify installation
    Write-Host "`nVerifying installation..." -ForegroundColor Cyan
    $manifestPath = Join-Path $moduleInstallPath "PSDynaTab.psd1"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
            Write-Host "  ✓ Module manifest valid" -ForegroundColor Green
            Write-Host "  ✓ Version: $($manifest.Version)" -ForegroundColor Green
        } catch {
            Write-Warning "Module manifest validation failed: $($_.Exception.Message)"
        }
    }

    # Success message
    Write-Host @"

╔═══════════════════════════════════════════════════════╗
║                                                       ║
║           Installation Completed Successfully!        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

    Write-Host "To use the module, run:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Import-Module PSDynaTab" -ForegroundColor White
    Write-Host "  Connect-DynaTab" -ForegroundColor White
    Write-Host "  Set-DynaTabText 'HELLO'" -ForegroundColor White
    Write-Host ""
    Write-Host "For help, run:" -ForegroundColor Cyan
    Write-Host "  Get-Help Connect-DynaTab -Full" -ForegroundColor White
    Write-Host ""
    Write-Host "Documentation: https://github.com/$repo" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host "`n❌ Installation failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "For help, please visit: https://github.com/$repo/issues" -ForegroundColor Yellow
    throw
} finally {
    # Cleanup temporary files
    if (Test-Path $tempDir) {
        Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
