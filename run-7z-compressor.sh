#!/bin/bash

# Shell script to run the 7z-compressor PowerShell script on Unix-like systems

echo "Starting 7z File Compressor..."
echo

# Check if PowerShell is available
if ! command -v pwsh &> /dev/null && ! command -v powershell &> /dev/null; then
    echo "PowerShell is not available."
    echo "Please install PowerShell Core from:"
    echo "https://github.com/PowerShell/PowerShell"
    echo
    echo "macOS: brew install --cask powershell"
    echo "Ubuntu: sudo snap install powershell --classic"
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try PowerShell Core first, then fallback to PowerShell
if command -v pwsh &> /dev/null; then
    echo "Using PowerShell Core (pwsh)..."
    pwsh -File "$SCRIPT_DIR/7z-compressor.ps1" "$@"
elif command -v powershell &> /dev/null; then
    echo "Using PowerShell (powershell)..."
    powershell -File "$SCRIPT_DIR/7z-compressor.ps1" "$@"
fi

echo
echo "Script completed."
read -p "Press Enter to continue..."
