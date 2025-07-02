# 7z File Compressor

A cross-platform PowerShell script with Windows Forms GUI for creating 7z archives from selected files.

## Features

- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Dual Interface**: 
  - **GUI Mode**: Windows Forms interface (Windows only)
  - **Command-Line Mode**: Interactive CLI (all platforms)
- **Smart Fallback**: Automatically switches to CLI mode when GUI is unavailable
- **Multi-File Selection**: Select multiple files at once
- **Compression Levels**: Adjustable compression levels (0-9)
- **Encryption Support**: AES-256 encryption with password protection
- **Header Encryption**: Hides file names and structure
- **Pre-shared Keys**: Support for command-line password parameters
- **Auto-Naming**: Automatically suggests output filenames
- **File Validation**: Checks for missing files before compression
- **Progress Feedback**: Visual feedback during compression process

## Requirements

### PowerShell
- **Windows**: PowerShell 5.1+ (built-in) or PowerShell 7+
- **macOS/Linux**: PowerShell 7+ (install from [PowerShell GitHub](https://github.com/PowerShell/PowerShell))

### 7-Zip Installation

#### Windows
Download and install from [7-Zip Official Website](https://www.7-zip.org/)

#### macOS
Install using Homebrew:
```bash
brew install p7zip
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install p7zip-full
```

#### Linux (CentOS/RHEL/Fedora)
```bash
# Fedora
sudo dnf install p7zip p7zip-plugins

# CentOS/RHEL (with EPEL)
sudo yum install epel-release
sudo yum install p7zip p7zip-plugins
```

## Usage

### Running the Script

1. **Double-click** the `7z-compressor.ps1` file (Windows)
2. **Right-click** → "Run with PowerShell" (Windows)
3. **Terminal/Command Line**:
   ```powershell
   # Windows PowerShell
   .\7z-compressor.ps1
   
   # PowerShell 7 (all platforms)
   pwsh ./7z-compressor.ps1
   ```

### Command Line Parameters

```powershell
.\7z-compressor.ps1 [-OutputPath <string>] [-CompressionLevel <int>]
```

**Parameters:**
- `-OutputPath`: Pre-set the output file path
- `-CompressionLevel`: Set compression level (0-9, default: 5)
- `-EnableEncryption`: Enable encryption mode
- `-EncryptionKey`: Pre-shared password for encryption

**Examples:**
```powershell
# Start with default settings
.\7z-compressor.ps1

# Pre-set output path
.\7z-compressor.ps1 -OutputPath "C:\backup\myfiles.7z"

# Set high compression
.\7z-compressor.ps1 -CompressionLevel 9

# Enable encryption with pre-shared key
.\7z-compressor.ps1 -EnableEncryption -EncryptionKey "MySecretPassword123"

# Combine all options
.\7z-compressor.ps1 -OutputPath "secure-backup.7z" -CompressionLevel 9 -EnableEncryption -EncryptionKey "SuperSecureKey456"
```

### GUI Usage (Windows)

1. **Add Files**: Click "Add Files" to select files for compression
2. **Remove Files**: Select files in the list and click "Remove Selected"
3. **Clear All**: Remove all files from the list
4. **Set Output**: Specify where to save the 7z file (or use "Browse...")
5. **Compression Level**: Adjust compression level (0 = fastest, 9 = best compression)
6. **Enable Encryption**: Check the encryption checkbox to enable password protection
7. **Set Password**: Enter a secure password (shown/hidden with "Show" button)
8. **Create Archive**: Click "Create 7z Archive" to start compression

### Command-Line Usage (All Platforms)

The script automatically falls back to command-line mode on macOS/Linux or when GUI is unavailable:

1. **Add Files**: Enter file paths one by one
2. **Set Output**: Specify the output 7z file path
3. **Adjust Compression**: Choose compression level (0-9)
4. **Toggle Encryption**: Enable/disable password protection
5. **Set Password**: Enter encryption password (hidden input)
6. **Create Archive**: Process the files into a 7z archive

**Command-Line Menu Options:**
- `1` - Add file(s) to the archive
- `2` - Remove a file from the list
- `3` - Set output path for the 7z file
- `4` - Set compression level (0-9)
- `5` - Toggle encryption on/off
- `6` - Set encryption password (when encryption enabled) OR Create archive (when encryption disabled)
- `7` - Create archive (when encryption enabled) OR Exit (when encryption disabled)
- `8` - Exit (when encryption enabled)

## Compression Levels

| Level | Speed | Compression | Description |
|-------|-------|-------------|-------------|
| 0     | Fastest | Store only | No compression, just archiving |
| 1     | Fast | Low | Minimal compression |
| 5     | Normal | Balanced | Default, good balance |
| 9     | Slowest | Maximum | Best compression ratio |

## Encryption Features

The script supports AES-256 encryption with the following security features:

### **Encryption Modes**
- **File Content Encryption**: Encrypts the actual file data
- **Header Encryption**: Hides file names, sizes, and archive structure
- **Password Protection**: Requires password to access any archive content

### **Security Benefits**
- **AES-256 Encryption**: Industry-standard encryption algorithm
- **Complete Privacy**: File names and structure are hidden from unauthorized users
- **Secure Key Derivation**: Uses 7-Zip's built-in key derivation function
- **No Metadata Leakage**: Archive appears completely opaque without password

### **Usage Scenarios**
- **Confidential Documents**: Protect sensitive business files
- **Personal Backups**: Secure personal data and photos
- **Secure File Transfer**: Send encrypted files safely
- **Compliance**: Meet data protection requirements

### **Password Best Practices**
- Use strong passwords (12+ characters, mixed case, numbers, symbols)
- Avoid dictionary words or personal information
- Consider using a password manager
- Store passwords securely and separately from archives

**Example Strong Passwords:**
- `MyS3cure#Archive2025!`
- `B@ckup$Files*Today123`
- `Encrypt&Protect#Data456`

## Troubleshooting

### Common Issues

#### "7-Zip is not installed or not found"
- **Solution**: Install 7-Zip for your platform (see Requirements section)
- **Check**: Verify 7z is in your system PATH

#### "Execution Policy" Error (Windows)
```powershell
# Run this command in PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### GUI Not Appearing
- **Windows**: GUI should work with Windows Forms
- **macOS/Linux**: GUI not supported - automatically switches to command-line mode
- **Alternative**: Use the interactive command-line interface

#### Permission Denied
```bash
# Make script executable (macOS/Linux)
chmod +x 7z-compressor.ps1
```

### Testing 7-Zip Installation

```powershell
# Test if 7z is accessible
Get-Command 7z

# Or check version
7z
```

## Platform-Specific Notes

### Windows
- Uses Windows Forms GUI natively
- Supports both PowerShell 5.1 and 7+
- Can open output folder in Explorer

### macOS
- Requires PowerShell 7+
- Uses command-line interface (GUI not supported)
- Can reveal files in Finder

### Linux
- Requires PowerShell 7+
- Uses command-line interface (GUI not supported)
- Opens file manager to show output

## File Structure

```
7z-compress/
├── 7z-compressor.ps1    # Main script
├── README.md            # This file
└── examples/            # Example files (optional)
```

## License

This script is provided as-is for educational and practical use. Feel free to modify and distribute.

## Contributing

To contribute improvements:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

For issues and questions:
- Check the Troubleshooting section
- Verify 7-Zip installation
- Ensure PowerShell requirements are met
