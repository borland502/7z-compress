# 7z-Compressor Project Structure

This project contains the following files:

## Main Files
- **7z-compressor.ps1** - Main PowerShell script with GUI
- **7z-compressor.psd1** - PowerShell module manifest
- **README.md** - Documentation and usage instructions
- **test-7z.ps1** - Test script to verify 7z installation

## Launcher Scripts
- **run-7z-compressor.bat** - Windows batch file launcher
- **run-7z-compressor.sh** - Unix shell script launcher (executable)

## Example Files
- **examples/sample1.txt** - Sample text file for testing
- **examples/sample2.md** - Sample markdown file for testing  
- **examples/data.json** - Sample JSON file for testing

## Quick Start

### Windows
Double-click `run-7z-compressor.bat` or `7z-compressor.ps1`

### macOS/Linux
```bash
./run-7z-compressor.sh
```

### PowerShell (all platforms)
```powershell
.\7z-compressor.ps1
```

## Prerequisites Check
Run the test script first to verify your system:
```powershell
.\test-7z.ps1
```

This will check:
- PowerShell version compatibility
- 7-Zip installation
- Windows Forms support
- Basic compression functionality
