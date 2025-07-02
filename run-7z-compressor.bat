@echo off
REM Windows batch file to run the 7z-compressor PowerShell script

echo Starting 7z File Compressor...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo PowerShell is not available or not in PATH.
    echo Please install PowerShell and try again.
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp07z-compressor.ps1" %*

REM Check if script ran successfully
if errorlevel 1 (
    echo.
    echo Script encountered an error.
    pause
)

echo.
echo Script completed.
pause
