#Requires -Version 5.1

<#
.SYNOPSIS
    Test script to verify 7-Zip installation and functionality
.DESCRIPTION
    This script checks if 7-Zip is properly installed and accessible on the system
.EXAMPLE
    .\test-7z.ps1
#>

Write-Host "7-Zip Installation Test" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

# Function to detect 7z executable path (same as main script)
function Get-7zPath {
    $possiblePaths = @()
    
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        # Windows paths
        $possiblePaths += @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
            "7z.exe"
        )
    } else {
        # Unix-like systems (macOS, Linux)
        $possiblePaths += @(
            "/usr/local/bin/7z",
            "/usr/bin/7z",
            "/opt/homebrew/bin/7z",
            "7z"
        )
    }
    
    foreach ($path in $possiblePaths) {
        if (Get-Command $path -ErrorAction SilentlyContinue) {
            return $path
        }
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Test system information
Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  OS: $($PSVersionTable.Platform)" -ForegroundColor White
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "  Host: $($Host.Name)" -ForegroundColor White
Write-Host ""

# Test 7z installation
Write-Host "Testing 7-Zip Installation..." -ForegroundColor Yellow

$7zPath = Get-7zPath
if ($7zPath) {
    Write-Host "✓ 7-Zip found at: $7zPath" -ForegroundColor Green
    
    # Test 7z version
    try {
        Write-Host "  Getting version information..." -ForegroundColor Gray
        $versionOutput = & $7zPath 2>&1
        if ($versionOutput -match "7-Zip.*(\d+\.\d+)") {
            Write-Host "✓ 7-Zip version detected" -ForegroundColor Green
        } else {
            Write-Host "? Version information unclear" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "! Error getting version: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test basic functionality with example files
    if (Test-Path "./examples") {
        Write-Host "  Testing compression with example files..." -ForegroundColor Gray
        
        $testFiles = Get-ChildItem "./examples" -File | Select-Object -First 2
        if ($testFiles.Count -gt 0) {
            $testOutput = "./test-archive.7z"
            
            try {
                $arguments = @(
                    "a",
                    "-t7z",
                    "-mx1",  # Fast compression for testing
                    $testOutput
                )
                
                foreach ($file in $testFiles) {
                    $arguments += $file.FullName
                }
                
                $process = Start-Process -FilePath $7zPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput "nul" -RedirectStandardError "nul"
                
                if ($process.ExitCode -eq 0 -and (Test-Path $testOutput)) {
                    $archiveSize = (Get-Item $testOutput).Length
                    Write-Host "✓ Test compression successful (Size: $archiveSize bytes)" -ForegroundColor Green
                    
                    # Clean up test file
                    Remove-Item $testOutput -Force
                    Write-Host "  Test archive cleaned up" -ForegroundColor Gray
                } else {
                    Write-Host "! Test compression failed (Exit code: $($process.ExitCode))" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "! Error during test compression: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  No example files found for testing" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No examples folder found, skipping compression test" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "✗ 7-Zip not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation Instructions:" -ForegroundColor Yellow
    Write-Host "  Windows: Download from https://www.7-zip.org/" -ForegroundColor White
    Write-Host "  macOS:   brew install p7zip" -ForegroundColor White
    Write-Host "  Linux:   sudo apt-get install p7zip-full" -ForegroundColor White
}

Write-Host ""

# Test Windows Forms support
Write-Host "Testing Windows Forms Support..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Host "✓ Windows Forms assemblies loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Windows Forms not available: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  GUI functionality may not work on this system" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test Complete!" -ForegroundColor Cyan

if ($7zPath) {
    Write-Host "You can now run the main script: .\7z-compressor.ps1" -ForegroundColor Green
} else {
    Write-Host "Please install 7-Zip before running the main script." -ForegroundColor Red
}
