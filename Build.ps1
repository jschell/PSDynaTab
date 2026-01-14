#Requires -Version 5.1

<#
.SYNOPSIS
    Build script for PSDynaTab module
.DESCRIPTION
    Performs module build tasks:
    - Downloads HidSharp.dll
    - Runs Pester tests
    - Creates module package
    - Updates version
.PARAMETER Version
    New version number (x.y.z format)
.PARAMETER SkipTests
    Skip Pester tests
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter()]
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

# Paths
$ProjectRoot = $PSScriptRoot
$ModulePath = Join-Path $ProjectRoot 'PSDynaTab'
$ManifestPath = Join-Path $ModulePath 'PSDynaTab.psd1'
$LibPath = Join-Path $ModulePath 'lib'
$HidSharpDllPath = Join-Path $LibPath 'HidSharp.dll'

Write-Host "=== PSDynaTab Build Script ===" -ForegroundColor Cyan

# Step 1: Download HidSharp.dll if missing
if (-not (Test-Path $HidSharpDllPath)) {
    Write-Host "`nDownloading HidSharp.dll..." -ForegroundColor Yellow

    $tempPath = Join-Path $env:TEMP 'hidsharp'
    New-Item -ItemType Directory -Force -Path $tempPath | Out-Null

    # Download NuGet package
    $nugetUrl = "https://www.nuget.org/api/v2/package/HidSharp/2.1.0"
    $zipPath = Join-Path $tempPath 'hidsharp.zip'

    Invoke-WebRequest -Uri $nugetUrl -OutFile $zipPath

    # Extract
    Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force

    # Copy DLL
    New-Item -ItemType Directory -Force -Path $LibPath | Out-Null
    Copy-Item "$tempPath\lib\netstandard2.0\HidSharp.dll" -Destination $HidSharpDllPath

    Write-Host "✓ HidSharp.dll downloaded" -ForegroundColor Green
} else {
    Write-Host "`n✓ HidSharp.dll already present" -ForegroundColor Green
}

# Step 2: Run Pester tests
if (-not $SkipTests) {
    Write-Host "`nRunning Pester tests..." -ForegroundColor Yellow

    if (Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0.0') {
        $testResults = Invoke-Pester -Path "$ProjectRoot\PSDynaTab\Tests" -PassThru

        if ($testResults.FailedCount -gt 0) {
            throw "Tests failed: $($testResults.FailedCount) test(s)"
        }

        Write-Host "✓ All tests passed ($($testResults.PassedCount) tests)" -ForegroundColor Green
    } else {
        Write-Warning "Pester 5.0+ not found, skipping tests"
    }
} else {
    Write-Host "`n⊘ Tests skipped" -ForegroundColor Yellow
}

# Step 3: Update version if specified
if ($Version) {
    Write-Host "`nUpdating version to $Version..." -ForegroundColor Yellow

    $manifest = Import-PowerShellDataFile $ManifestPath
    Update-ModuleManifest -Path $ManifestPath -ModuleVersion $Version

    Write-Host "✓ Version updated" -ForegroundColor Green
}

# Step 4: Validate manifest
Write-Host "`nValidating module manifest..." -ForegroundColor Yellow
Test-ModuleManifest -Path $ManifestPath | Out-Null
Write-Host "✓ Manifest valid" -ForegroundColor Green

# Step 5: Summary
Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host "Module: PSDynaTab"
Write-Host "Location: $ModulePath"

$currentVersion = (Import-PowerShellDataFile $ManifestPath).ModuleVersion
Write-Host "Version: $currentVersion"

Write-Host "`nTo install locally:"
Write-Host "  Copy-Item -Recurse '$ModulePath' '$env:USERPROFILE\Documents\PowerShell\Modules\'" -ForegroundColor Cyan
