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

    $tempPath = Join-Path $env:TEMP "hidsharp-$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Force -Path $tempPath | Out-Null

    try {
        # Download NuGet package
        $nugetUrl = "https://www.nuget.org/api/v2/package/HidSharp/2.1.0"
        $zipPath = Join-Path $tempPath 'hidsharp.zip'

        Write-Verbose "Downloading from: $nugetUrl"
        Invoke-WebRequest -Uri $nugetUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 30

        # Extract
        Write-Verbose "Extracting to: $tempPath"
        Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force

        # Wait for filesystem to settle (prevents access denied errors)
        Start-Sleep -Milliseconds 500

        # Copy DLL with retry logic
        New-Item -ItemType Directory -Force -Path $LibPath | Out-Null

        $sourceDll = Join-Path $tempPath "lib\netstandard2.0\HidSharp.dll"
        $retryCount = 0
        $maxRetries = 3
        $copySuccess = $false

        while ($retryCount -lt $maxRetries -and -not $copySuccess) {
            try {
                if (-not (Test-Path $sourceDll)) {
                    throw "Source DLL not found at: $sourceDll"
                }

                Write-Verbose "Copy attempt $($retryCount + 1) of $maxRetries"
                Copy-Item -Path $sourceDll -Destination $HidSharpDllPath -Force
                $copySuccess = $true

            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Verbose "Copy failed, retrying in 500ms... ($($_.Exception.Message))"
                    Start-Sleep -Milliseconds 500
                } else {
                    throw "Failed to copy HidSharp.dll after $maxRetries attempts: $($_.Exception.Message)"
                }
            }
        }

        # Verify DLL was copied and has reasonable size
        if (Test-Path $HidSharpDllPath) {
            $dllSize = (Get-Item $HidSharpDllPath).Length
            if ($dllSize -lt 100KB) {
                throw "HidSharp.dll size ($dllSize bytes) is too small - download may be corrupt"
            }
            Write-Host "✓ HidSharp.dll downloaded ($('{0:N2}' -f ($dllSize / 1KB)) KB)" -ForegroundColor Green
        } else {
            throw "HidSharp.dll was not found after copy operation"
        }

    } catch {
        Write-Error "Failed to download HidSharp.dll: $($_.Exception.Message)"
        throw
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
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
