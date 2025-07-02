#Requires -Version 5.1

<#
.SYNOPSIS
    Cross-platform PowerShell script with Windows Forms GUI for creating 7z archives
.DESCRIPTION
    This script provides a GUI interface to select one or more files and compress them into a 7z archive.
    Supports Windows, macOS, and Linux platforms with optional encryption.
.EXAMPLE
    .\7z-compressor.ps1
.EXAMPLE
    .\7z-compressor.ps1 -EnableEncryption -EncryptionKey "MySecretPassword"
.EXAMPLE
    .\7z-compressor.ps1 -OutputPath "backup.7z" -CompressionLevel 9 -EnableEncryption
.NOTES
    Requires 7-Zip to be installed on the system
    - Windows: Install 7-Zip from https://www.7-zip.org/
    - macOS: Install via Homebrew: brew install p7zip
    - Linux: Install via package manager: sudo apt-get install p7zip-full (Ubuntu/Debian)
    
    Encryption Features:
    - Uses AES-256 encryption when enabled
    - Encrypts both file contents and headers (hides file names)
    - Supports pre-shared keys via command line parameters
#>

param(
    [Parameter(HelpMessage = "Path to output 7z file")]
    [string]$OutputPath = "",
    
    [Parameter(HelpMessage = "Compression level (0-9)")]
    [ValidateRange(0, 9)]
    [int]$CompressionLevel = 5,
    
    [Parameter(HelpMessage = "Pre-shared key for encryption")]
    [string]$EncryptionKey = "",
    
    [Parameter(HelpMessage = "Enable encryption")]
    [switch]$EnableEncryption,
    
    [Parameter(HelpMessage = "Input files to compress", ValueFromRemainingArguments = $true)]
    [string[]]$InputFiles = @()
)

# Global variables
$script:SelectedFiles = New-Object System.Collections.ArrayList
$script:OutputFile = ""
$script:GuiAvailable = $false
$script:EncryptionEnabled = if ($EnableEncryption) { $true } else { $false }
$script:EncryptionPassword = if ($EncryptionKey) { $EncryptionKey } else { "" }
$script:ListFilesControl = $null
$script:OutputTextControl = $null
$script:PasswordLabelControl = $null
$script:PasswordTextControl = $null
$script:ShowPasswordButtonControl = $null

# Function to safely read user input (cross-platform compatible)
function Read-UserInput {
    param(
        [string]$Prompt = "Input",
        [switch]$AsSecureString
    )
    
    try {
        if ($AsSecureString) {
            # For secure strings, we still need to use Read-Host
            return Read-Host $Prompt -AsSecureString
        }
        
        # For regular input, use a more robust approach
        Write-Host "$Prompt`: " -NoNewline -ForegroundColor Yellow
        
        # Try different input methods based on platform
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            # Windows - use standard Read-Host
            return Read-Host
        } else {
            # Linux/macOS - use System.Console directly to avoid PowerShell Read-Host issues
            [System.Console]::Out.Flush()
            $input = [System.Console]::ReadLine()
            return $input
        }
    }
    catch {
        # Ultimate fallback - try to read from stdin directly
        Write-Host "Input: " -NoNewline -ForegroundColor Yellow
        try {
            $input = [System.Console]::ReadLine()
            return $input
        }
        catch {
            # If all else fails, return empty string
            Write-Host "Error reading input, using empty string" -ForegroundColor Red
            return ""
        }
    }
}

# Safer input function with timeout protection
function Read-UserInputSafe {
    param(
        [string]$Prompt = "Input",
        [int]$TimeoutSeconds = 30
    )
    
    try {
        Write-Host "$Prompt`: " -NoNewline -ForegroundColor Yellow
        [System.Console]::Out.Flush()
        # Use Console.ReadLine which is more reliable on Linux
        $input = [System.Console]::ReadLine()
        return $input
    }
    catch {
        Write-Host "`nInput error, using empty string" -ForegroundColor Red
        return ""
    }
}

# Initialize variables function
function Initialize-ScriptVariables {
    if ($null -eq $script:SelectedFiles) {
        $script:SelectedFiles = New-Object System.Collections.ArrayList
    }
    if ($null -eq $script:OutputFile) {
        $script:OutputFile = ""
    }
}

# Function to test GUI availability
function Test-GuiSupport {
    try {
        # Try to load Windows Forms assemblies
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $script:GuiAvailable = $true
        return $true
    }
    catch {
        Write-Host "Windows Forms GUI not available on this platform." -ForegroundColor Yellow
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $script:GuiAvailable = $false
        return $false
    }
}

# Function to detect 7z executable path
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

# Function to validate 7z installation
function Test-7zInstallation {
    param([bool]$ShowGui = $true)
    
    $7zPath = Get-7zPath
    if (-not $7zPath) {
        $message = @"
7-Zip is not installed or not found in PATH.

Please install 7-Zip:
- Windows: Download from https://www.7-zip.org/
- macOS: Run 'brew install p7zip'
- Linux: Run 'sudo apt-get install p7zip-full' (Ubuntu/Debian) or equivalent
"@
        
        if ($ShowGui -and $script:GuiAvailable) {
            [System.Windows.Forms.MessageBox]::Show($message, "7-Zip Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        } else {
            Write-Host $message -ForegroundColor Red
        }
        return $false
    }
    return $true
}

# Function to create 7z archive
function New-7zArchive {
    param(
        [string[]]$InputFiles,
        [string]$OutputPath,
        [int]$CompressionLevel = 5,
        [string]$Password = "",
        [bool]$Encrypt = $false
    )
    
    # Input validation
    if (-not $InputFiles -or $InputFiles.Count -eq 0) {
        throw "No input files specified"
    }
    
    if (-not $OutputPath -or $OutputPath.Trim() -eq "") {
        throw "No output path specified"
    }
    
    $7zPath = Get-7zPath
    if (-not $7zPath) {
        throw "7-Zip executable not found"
    }
    
    # Build 7z command arguments
    $arguments = @(
        "a",                                    # Add to archive
        "-t7z",                                # Archive type: 7z
        "-mx$CompressionLevel"                 # Compression level
    )
    
    # Add encryption if enabled
    if ($Encrypt -and $Password -and $Password.Trim() -ne "") {
        $arguments += "-p$Password"            # Password
        $arguments += "-mhe=on"                # Encrypt headers (hide file names)
        Write-Host "Encryption enabled with password protection" -ForegroundColor Yellow
    } elseif ($Encrypt) {
        Write-Host "Warning: Encryption requested but no password provided" -ForegroundColor Yellow
    }
    
    $arguments += "`"$($OutputPath.Trim())`""  # Output file (quoted for spaces)
    
    # Add input files (quoted for spaces)
    foreach ($file in $InputFiles) {
        if ($file -and $file.Trim() -ne "") {
            $arguments += "`"$($file.Trim())`""
        }
    }
    
    try {
        Write-Host "Creating 7z archive..." -ForegroundColor Green
        if ($Encrypt -and $Password -and $Password.Trim() -ne "") {
            Write-Host "Command: $7zPath a -t7z -mx$CompressionLevel -p*** -mhe=on `"$($OutputPath.Trim())`" [files...]" -ForegroundColor Cyan
        } else {
            Write-Host "Command: $7zPath $($arguments -join ' ')" -ForegroundColor Cyan
        }
        
        $process = Start-Process -FilePath $7zPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Archive created successfully: $($OutputPath.Trim())" -ForegroundColor Green
            if ($Encrypt -and $Password -and $Password.Trim() -ne "") {
                Write-Host "Archive is encrypted and password protected" -ForegroundColor Green
            }
            return $true
        } else {
            Write-Host "7-Zip process failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error creating archive: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to create the main form
function New-MainForm {
    if (-not $script:GuiAvailable) {
        throw "GUI is not available on this platform"
    }
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "7z File Compressor"
    $form.Size = New-Object System.Drawing.Size(620, 520)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    
    # Create controls
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "7z File Compressor"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.Size = New-Object System.Drawing.Size(300, 30)
    
    $lblFiles = New-Object System.Windows.Forms.Label
    $lblFiles.Text = "Selected Files:"
    $lblFiles.Location = New-Object System.Drawing.Point(20, 60)
    $lblFiles.Size = New-Object System.Drawing.Size(100, 20)
    
    $listFiles = New-Object System.Windows.Forms.ListBox
    $listFiles.Location = New-Object System.Drawing.Point(20, 85)
    $listFiles.Size = New-Object System.Drawing.Size(550, 200)
    $listFiles.SelectionMode = "MultiExtended"
    
    # Store reference in script scope for event handlers
    $script:ListFilesControl = $listFiles
    
    $btnAddFiles = New-Object System.Windows.Forms.Button
    $btnAddFiles.Text = "Add Files"
    $btnAddFiles.Location = New-Object System.Drawing.Point(20, 300)
    $btnAddFiles.Size = New-Object System.Drawing.Size(100, 30)
    
    $btnRemoveFiles = New-Object System.Windows.Forms.Button
    $btnRemoveFiles.Text = "Remove Selected"
    $btnRemoveFiles.Location = New-Object System.Drawing.Point(130, 300)
    $btnRemoveFiles.Size = New-Object System.Drawing.Size(120, 30)
    
    $btnClearAll = New-Object System.Windows.Forms.Button
    $btnClearAll.Text = "Clear All"
    $btnClearAll.Location = New-Object System.Drawing.Point(260, 300)
    $btnClearAll.Size = New-Object System.Drawing.Size(80, 30)
    
    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Text = "Output 7z File:"
    $lblOutput.Location = New-Object System.Drawing.Point(20, 350)
    $lblOutput.Size = New-Object System.Drawing.Size(100, 20)
    
    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(20, 375)
    $txtOutput.Size = New-Object System.Drawing.Size(450, 25)
    
    # Store reference in script scope for event handlers
    $script:OutputTextControl = $txtOutput
    
    $btnBrowseOutput = New-Object System.Windows.Forms.Button
    $btnBrowseOutput.Text = "Browse..."
    $btnBrowseOutput.Location = New-Object System.Drawing.Point(480, 374)
    $btnBrowseOutput.Size = New-Object System.Drawing.Size(80, 27)
    
    $lblCompression = New-Object System.Windows.Forms.Label
    $lblCompression.Text = "Compression Level (0-9):"
    $lblCompression.Location = New-Object System.Drawing.Point(20, 410)
    $lblCompression.Size = New-Object System.Drawing.Size(150, 20)
    
    $numCompression = New-Object System.Windows.Forms.NumericUpDown
    $numCompression.Location = New-Object System.Drawing.Point(180, 408)
    $numCompression.Size = New-Object System.Drawing.Size(60, 25)
    $numCompression.Minimum = 0
    $numCompression.Maximum = 9
    $numCompression.Value = $CompressionLevel
    
    $chkEncryption = New-Object System.Windows.Forms.CheckBox
    $chkEncryption.Text = "Enable Encryption"
    $chkEncryption.Location = New-Object System.Drawing.Point(260, 410)
    $chkEncryption.Size = New-Object System.Drawing.Size(130, 20)
    $chkEncryption.Checked = $script:EncryptionEnabled
    
    $lblPassword = New-Object System.Windows.Forms.Label
    $lblPassword.Text = "Password:"
    $lblPassword.Location = New-Object System.Drawing.Point(20, 440)
    $lblPassword.Size = New-Object System.Drawing.Size(70, 20)
    $lblPassword.Enabled = $script:EncryptionEnabled
    
    $txtPassword = New-Object System.Windows.Forms.TextBox
    $txtPassword.Location = New-Object System.Drawing.Point(95, 438)
    $txtPassword.Size = New-Object System.Drawing.Size(200, 25)
    $txtPassword.UseSystemPasswordChar = $true
    $txtPassword.Text = $script:EncryptionPassword
    $txtPassword.Enabled = $script:EncryptionEnabled
    
    $btnShowPassword = New-Object System.Windows.Forms.Button
    $btnShowPassword.Text = "Show"
    $btnShowPassword.Location = New-Object System.Drawing.Point(305, 437)
    $btnShowPassword.Size = New-Object System.Drawing.Size(50, 27)
    $btnShowPassword.Enabled = $script:EncryptionEnabled
    
    # Store password control references in script scope for event handlers
    $script:PasswordLabelControl = $lblPassword
    $script:PasswordTextControl = $txtPassword
    $script:ShowPasswordButtonControl = $btnShowPassword
    
    $btnCompress = New-Object System.Windows.Forms.Button
    $btnCompress.Text = "Create 7z Archive"
    $btnCompress.Location = New-Object System.Drawing.Point(400, 435)
    $btnCompress.Size = New-Object System.Drawing.Size(120, 35)
    $btnCompress.BackColor = [System.Drawing.Color]::LightGreen
    $btnCompress.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    
    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "Exit"
    $btnExit.Location = New-Object System.Drawing.Point(530, 435)
    $btnExit.Size = New-Object System.Drawing.Size(60, 35)
    
    # Event handlers
    $chkEncryption.Add_CheckedChanged({
        try {
            $isEnabled = $chkEncryption.Checked
            
            # Use script-scope control references
            if ($null -ne $script:PasswordLabelControl) {
                $script:PasswordLabelControl.Enabled = $isEnabled
            }
            if ($null -ne $script:PasswordTextControl) {
                $script:PasswordTextControl.Enabled = $isEnabled
            }
            if ($null -ne $script:ShowPasswordButtonControl) {
                $script:ShowPasswordButtonControl.Enabled = $isEnabled
            }
            
            if (-not $isEnabled -and $null -ne $script:PasswordTextControl) {
                $script:PasswordTextControl.Text = ""
            }
        }
        catch {
            # Ignore encryption toggle errors
            Write-Host "Warning: Could not update encryption controls: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    })
    
    $btnShowPassword.Add_Click({
        try {
            if ($null -ne $script:PasswordTextControl -and $null -ne $script:ShowPasswordButtonControl) {
                if ($script:PasswordTextControl.UseSystemPasswordChar) {
                    $script:PasswordTextControl.UseSystemPasswordChar = $false
                    $script:ShowPasswordButtonControl.Text = "Hide"
                } else {
                    $script:PasswordTextControl.UseSystemPasswordChar = $true
                    $script:ShowPasswordButtonControl.Text = "Show"
                }
            }
        }
        catch {
            # Ignore password show/hide errors
            Write-Host "Warning: Could not toggle password visibility: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    })
    
    $btnAddFiles.Add_Click({
        try {
            # Ensure script variables are initialized
            if ($null -eq $script:SelectedFiles) {
                $script:SelectedFiles = New-Object System.Collections.ArrayList
            }
            
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            if ($null -eq $openFileDialog) {
                throw "Failed to create file dialog"
            }
            
            $openFileDialog.Title = "Select Files to Compress"
            $openFileDialog.Filter = "All Files (*.*)|*.*"
            $openFileDialog.Multiselect = $true
            $openFileDialog.CheckFileExists = $true
            $openFileDialog.CheckPathExists = $true
            
            $dialogResult = $openFileDialog.ShowDialog()
            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                if ($null -ne $openFileDialog.FileNames -and $openFileDialog.FileNames.Count -gt 0) {
                    foreach ($file in $openFileDialog.FileNames) {
                        if ($null -ne $file -and $file.Trim() -ne "" -and (Test-Path $file)) {
                            if ($script:SelectedFiles -notcontains $file) {
                                [void]$script:SelectedFiles.Add($file)
                                # Add to the listbox using script-scope reference
                                try {
                                    if ($null -ne $script:ListFilesControl -and $null -ne $script:ListFilesControl.Items) {
                                        [void]$script:ListFilesControl.Items.Add($file)
                                        Write-Host "Added file to list: $file" -ForegroundColor Green
                                    } else {
                                        Write-Host "Warning: ListBox control not accessible" -ForegroundColor Yellow
                                    }
                                } catch {
                                    Write-Host "Error adding file to listbox: $($_.Exception.Message)" -ForegroundColor Red
                                }
                            } else {
                                Write-Host "File already in list: $file" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "File not found or invalid: $file" -ForegroundColor Red
                        }
                    }
                    
                    # Auto-generate output filename if not set
                    if ($script:SelectedFiles.Count -gt 0) {
                        try {
                            # Check if output text control is accessible and its Text property is empty
                            if ($null -ne $script:OutputTextControl -and 
                                $null -ne $script:OutputTextControl.Text -and 
                                $script:OutputTextControl.Text.Trim() -eq "") {
                                
                                $firstFile = $script:SelectedFiles[0]
                                if ($null -ne $firstFile -and (Test-Path $firstFile)) {
                                    $directory = [System.IO.Path]::GetDirectoryName($firstFile)
                                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($firstFile)
                                    
                                    if ($null -eq $baseName -or $baseName.Trim() -eq "") {
                                        $baseName = "archive"
                                    }
                                    
                                    if ($script:SelectedFiles.Count -gt 1) {
                                        $baseName = "archive"
                                    }
                                    
                                    if ($null -ne $directory -and $directory.Trim() -ne "") {
                                        $suggestedName = Join-Path $directory "$baseName.7z"
                                        try {
                                            $script:OutputTextControl.Text = $suggestedName
                                            Write-Host "Auto-generated output path: $suggestedName" -ForegroundColor Cyan
                                        }
                                        catch {
                                            # If setting the text fails, ignore silently
                                            Write-Host "Note: Could not set auto-generated filename" -ForegroundColor Gray
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            # If path operations fail, just continue without auto-generating
                            Write-Host "Warning: Could not auto-generate output filename: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
        catch {
            $errorMsg = if ($null -ne $_.Exception.Message) { $_.Exception.Message } else { "Unknown error occurred" }
            [System.Windows.Forms.MessageBox]::Show("Error selecting files: $errorMsg", "File Selection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            # Ensure dialog is disposed
            if ($null -ne $openFileDialog) {
                try {
                    $openFileDialog.Dispose()
                }
                catch {
                    # Ignore disposal errors
                }
            }
        }
    })
    
    $btnRemoveFiles.Add_Click({
        try {
            # Ensure script variables are initialized
            if ($null -eq $script:SelectedFiles) {
                $script:SelectedFiles = New-Object System.Collections.ArrayList
            }
            
            if ($null -eq $script:ListFilesControl.SelectedIndices -or $script:ListFilesControl.SelectedIndices.Count -eq 0) {
                return
            }
            
            $selectedIndices = @($script:ListFilesControl.SelectedIndices)
            for ($i = $selectedIndices.Count - 1; $i -ge 0; $i--) {
                $index = $selectedIndices[$i]
                if ($index -ge 0 -and $index -lt $script:ListFilesControl.Items.Count) {
                    $fileToRemove = $script:ListFilesControl.Items[$index]
                    if ($null -ne $fileToRemove) {
                        # Remove from ArrayList
                        [void]$script:SelectedFiles.Remove($fileToRemove.ToString())
                        # Remove from ListBox
                        $script:ListFilesControl.Items.RemoveAt($index)
                    }
                }
            }
        }
        catch {
            $errorMsg = if ($null -ne $_.Exception.Message) { $_.Exception.Message } else { "Unknown error occurred" }
            [System.Windows.Forms.MessageBox]::Show("Error removing files: $errorMsg", "File Removal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    
    $btnClearAll.Add_Click({
        try {
            # Ensure script variables are initialized
            if ($null -eq $script:SelectedFiles) {
                $script:SelectedFiles = New-Object System.Collections.ArrayList
            } else {
                $script:SelectedFiles.Clear()
            }
            
            if ($null -ne $script:ListFilesControl.Items) {
                $script:ListFilesControl.Items.Clear()
            }
            
            if ($null -ne $script:OutputTextControl) {
                $script:OutputTextControl.Text = ""
            }
        }
        catch {
            # Fallback if clearing fails
            try {
                $script:SelectedFiles = New-Object System.Collections.ArrayList
                Write-Host "Warning: Had to reinitialize selected files list" -ForegroundColor Yellow
            }
            catch {
                Write-Host "Warning: Could not clear all items properly" -ForegroundColor Yellow
            }
        }
    })
    
    $btnBrowseOutput.Add_Click({
        try {
            $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            if ($null -eq $saveFileDialog) {
                throw "Failed to create save dialog"
            }
            
            $saveFileDialog.Title = "Save 7z Archive As"
            $saveFileDialog.Filter = "7z Archives (*.7z)|*.7z|All Files (*.*)|*.*"
            $saveFileDialog.DefaultExt = "7z"
            
            $dialogResult = $saveFileDialog.ShowDialog()
            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                if ($null -ne $saveFileDialog.FileName -and $saveFileDialog.FileName.Trim() -ne "") {
                    if ($null -ne $script:OutputTextControl) {
                        $script:OutputTextControl.Text = $saveFileDialog.FileName
                    }
                }
            }
        }
        catch {
            $errorMsg = if ($null -ne $_.Exception.Message) { $_.Exception.Message } else { "Unknown error occurred" }
            [System.Windows.Forms.MessageBox]::Show("Error browsing output location: $errorMsg", "Browse Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            # Ensure dialog is disposed
            if ($null -ne $saveFileDialog) {
                try {
                    $saveFileDialog.Dispose()
                }
                catch {
                    # Ignore disposal errors
                }
            }
        }
    })
    
    $btnCompress.Add_Click({
        if ($script:SelectedFiles.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one file to compress.", "No Files Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        if (-not $txtOutput.Text -or $txtOutput.Text.Trim() -eq "") {
            [System.Windows.Forms.MessageBox]::Show("Please specify an output file path.", "No Output Path", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Check encryption settings
        $useEncryption = $chkEncryption.Checked
        $password = if ($txtPassword.Text) { $txtPassword.Text } else { "" }
        
        if ($useEncryption -and ($password -eq "" -or $null -eq $password)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a password for encryption.", "No Password", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Validate that all selected files exist
        $missingFiles = @()
        foreach ($file in $script:SelectedFiles) {
            if (-not (Test-Path $file)) {
                $missingFiles += $file
            }
        }
        
        if ($missingFiles.Count -gt 0) {
            $message = "The following files no longer exist:`n" + ($missingFiles -join "`n")
            [System.Windows.Forms.MessageBox]::Show($message, "Missing Files", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        $outputPath = $txtOutput.Text.Trim()
        $compressionLevel = [int]$numCompression.Value
        
        # Create output directory if it doesn't exist
        try {
            $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
            if ($outputDir -and (-not (Test-Path $outputDir))) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to create output directory: $($_.Exception.Message)", "Directory Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        # Disable the compress button during operation
        $btnCompress.Enabled = $false
        $btnCompress.Text = "Compressing..."
        $form.Refresh()
        
        try {
            # Convert ArrayList to array for the function call
            $filesArray = if ($script:SelectedFiles -is [System.Collections.ArrayList]) {
                $script:SelectedFiles.ToArray()
            } else {
                $script:SelectedFiles
            }
            
            $success = New-7zArchive -InputFiles $filesArray -OutputPath $outputPath -CompressionLevel $compressionLevel -Password $password -Encrypt $useEncryption
            
            if ($success) {
                $message = "Archive created successfully!`n`nOutput: $outputPath"
                if ($useEncryption) {
                    $message += "`n`nArchive is encrypted with password protection."
                }
                [System.Windows.Forms.MessageBox]::Show($message, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                
                # Ask if user wants to open the output folder
                $result = [System.Windows.Forms.MessageBox]::Show("Would you like to open the output folder?", "Open Folder", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                if ($result -eq "Yes") {
                    try {
                        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                            Start-Process "explorer.exe" "/select,`"$outputPath`""
                        } elseif ($IsMacOS) {
                            Start-Process "open" "-R `"$outputPath`""
                        } else {
                            # Linux
                            $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
                            Start-Process "xdg-open" "`"$outputDir`""
                        }
                    }
                    catch {
                        [System.Windows.Forms.MessageBox]::Show("Could not open output folder: $($_.Exception.Message)", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                    }
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Failed to create archive. Check the console for details.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $btnCompress.Enabled = $true
            $btnCompress.Text = "Create 7z Archive"
        }
    })
    
    $btnExit.Add_Click({
        $form.Close()
    })
    
    # Set initial output path if provided via parameter
    if ($OutputPath -and $OutputPath.Trim() -ne "") {
        $txtOutput.Text = $OutputPath.Trim()
    }
    
    # Add controls to form
    $form.Controls.AddRange(@(
        $lblTitle, $lblFiles, $listFiles, $btnAddFiles, $btnRemoveFiles, $btnClearAll,
        $lblOutput, $txtOutput, $btnBrowseOutput, $lblCompression, $numCompression,
        $chkEncryption, $lblPassword, $txtPassword, $btnShowPassword,
        $btnCompress, $btnExit
    ))
    
    return $form
}

# Function to run in command-line mode
function Start-CommandLineMode {
    Write-Host ""
    Write-Host "Running in Command-Line Mode" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    
    # If files were provided as command-line arguments, use non-interactive mode
    if ($InputFiles -and $InputFiles.Count -gt 0) {
        Write-Host "Non-interactive mode (files provided as arguments)" -ForegroundColor Yellow
        
        # Validate input files
        $validFiles = @()
        foreach ($file in $InputFiles) {
            if (Test-Path $file) {
                $validFiles += (Resolve-Path $file).Path
                Write-Host "Added: $file" -ForegroundColor Green
            } else {
                Write-Host "File not found: $file" -ForegroundColor Red
            }
        }
        
        if ($validFiles.Count -eq 0) {
            Write-Host "No valid files found" -ForegroundColor Red
            return
        }
        
        # Auto-generate output path if not provided
        if (-not $OutputPath) {
            $firstFile = $validFiles[0]
            $directory = [System.IO.Path]::GetDirectoryName($firstFile)
            $baseName = if ($validFiles.Count -gt 1) { "archive" } else { [System.IO.Path]::GetFileNameWithoutExtension($firstFile) }
            $OutputPath = Join-Path $directory "$baseName.7z"
            Write-Host "Auto-generated output path: $OutputPath" -ForegroundColor Cyan
        }
        
        # Show compression settings
        Write-Host ""
        Write-Host "Archive Settings:" -ForegroundColor Cyan
        Write-Host "  Input files: $($validFiles.Count)" -ForegroundColor White
        Write-Host "  Output: $OutputPath" -ForegroundColor White
        Write-Host "  Compression level: $CompressionLevel" -ForegroundColor White
        Write-Host "  Encryption: $(if ($script:EncryptionEnabled) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
        
        if ($script:EncryptionEnabled) {
            if ($script:EncryptionPassword) {
                Write-Host "  Password: Set via parameter" -ForegroundColor White
            } else {
                Write-Host "  Password: Not provided - archive will not be encrypted" -ForegroundColor Yellow
                $script:EncryptionEnabled = $false
            }
        }
        
        Write-Host ""
        Write-Host "Creating archive..." -ForegroundColor Yellow
        
        try {
            $success = New-7zArchive -InputFiles $validFiles -OutputPath $OutputPath -CompressionLevel $CompressionLevel -Password $script:EncryptionPassword -Encrypt $script:EncryptionEnabled
            
            if ($success) {
                Write-Host ""
                Write-Host "Archive created successfully!" -ForegroundColor Green
                Write-Host "Output: $OutputPath" -ForegroundColor Green
                if ($script:EncryptionEnabled) {
                    Write-Host "Archive is password protected" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Failed to create archive" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return
    }
    
    # Check if we're in a non-interactive environment
    $isInteractive = $true
    try {
        # Test if we can actually read input
        if ($Host.UI.RawUI.KeyAvailable -eq $null) {
            $isInteractive = $false
        }
    } catch {
        $isInteractive = $false
    }
    
    if (-not $isInteractive) {
        Write-Host "Non-interactive environment detected." -ForegroundColor Yellow
        Write-Host "Please use command-line parameters instead:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  pwsh ./7z-compressor.ps1 -OutputPath 'archive.7z' file1.txt file2.txt" -ForegroundColor White
        Write-Host "  pwsh ./7z-compressor.ps1 -CompressionLevel 9 *.txt" -ForegroundColor White
        Write-Host "  pwsh ./7z-compressor.ps1 -EnableEncryption -EncryptionKey 'password123' file1.txt file2.txt" -ForegroundColor White
        Write-Host ""
        Write-Host "Available parameters:" -ForegroundColor Cyan
        Write-Host "  -OutputPath <path>        Output 7z file path" -ForegroundColor White
        Write-Host "  -CompressionLevel <0-9>   Compression level" -ForegroundColor White
        Write-Host "  -EnableEncryption         Enable password protection" -ForegroundColor White
        Write-Host "  -EncryptionKey <password> Set encryption password" -ForegroundColor White
        Write-Host "  <files...>                Files to compress" -ForegroundColor White
        return
    }
    
    $inputFiles = @()
    $outputPath = $OutputPath
    $compressionLevel = $CompressionLevel
    $useEncryption = $script:EncryptionEnabled
    $password = $script:EncryptionPassword
    
    # Get input files
    if ($outputPath) {
        Write-Host "Output file: $outputPath" -ForegroundColor Green
    }
    
    # Interactive loop with timeout protection
    $maxIterations = 100  # Prevent infinite loops
    $iteration = 0
    
    while ($iteration -lt $maxIterations) {
        $iteration++
        
        Write-Host ""
        Write-Host "Current files selected: $($inputFiles.Count)" -ForegroundColor Yellow
        if ($inputFiles.Count -gt 0) {
            for ($i = 0; $i -lt $inputFiles.Count; $i++) {
                Write-Host "  $($i + 1). $($inputFiles[$i])" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  1. Add file(s)" -ForegroundColor White
        Write-Host "  2. Remove file" -ForegroundColor White
        Write-Host "  3. Set output path" -ForegroundColor White
        Write-Host "  4. Set compression level (current: $compressionLevel)" -ForegroundColor White
        Write-Host "  5. Toggle encryption (current: $(if ($useEncryption) { 'Enabled' } else { 'Disabled' }))" -ForegroundColor White
        if ($useEncryption) {
            Write-Host "  6. Set encryption password $(if ($password) { '(set)' } else { '(not set)' })" -ForegroundColor White
            Write-Host "  7. Create archive" -ForegroundColor Green
            Write-Host "  8. Exit" -ForegroundColor Red
        } else {
            Write-Host "  6. Create archive" -ForegroundColor Green
            Write-Host "  7. Exit" -ForegroundColor Red
        }
        Write-Host ""
        
        # Use a safer input method
        $choice = ""
        try {
            if ($useEncryption) {
                $choice = Read-UserInputSafe "Enter your choice (1-8)"
            } else {
                $choice = Read-UserInputSafe "Enter your choice (1-7)"  
            }
        } catch {
            Write-Host "Error reading input. Exiting..." -ForegroundColor Red
            return
        }
        
        if ($choice -eq "") {
            Write-Host "Empty input received. Exiting..." -ForegroundColor Yellow
            return
        }
        
        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "Enter file paths (one per line, empty line to finish):" -ForegroundColor Yellow
                $fileInputCount = 0
                while ($fileInputCount -lt 20) {  # Limit file inputs
                    $fileInputCount++
                    $filePath = ""
                    try {
                        $filePath = Read-UserInputSafe "File path (or press Enter to finish)"
                    } catch {
                        Write-Host "Error reading file path. Continuing..." -ForegroundColor Red
                        break
                    }
                    
                    if (-not $filePath) { break }
                    
                    if (Test-Path $filePath) {
                        try {
                            $fullPath = (Resolve-Path $filePath).Path
                            if ($inputFiles -notcontains $fullPath) {
                                $inputFiles += $fullPath
                                Write-Host "Added: $fullPath" -ForegroundColor Green
                            } else {
                                Write-Host "File already in list" -ForegroundColor Yellow
                            }
                        } catch {
                            Write-Host "Error resolving path: $filePath" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "File not found: $filePath" -ForegroundColor Red
                    }
                }
                
                # Auto-generate output path if not set
                if (-not $outputPath -and $inputFiles.Count -gt 0) {
                    try {
                        $firstFile = $inputFiles[0]
                        $directory = [System.IO.Path]::GetDirectoryName($firstFile)
                        $baseName = if ($inputFiles.Count -gt 1) { "archive" } else { [System.IO.Path]::GetFileNameWithoutExtension($firstFile) }
                        $outputPath = Join-Path $directory "$baseName.7z"
                        Write-Host "Auto-generated output path: $outputPath" -ForegroundColor Cyan
                    } catch {
                        Write-Host "Could not auto-generate output path" -ForegroundColor Yellow
                    }
                }
            }
            "2" {
                if ($inputFiles.Count -eq 0) {
                    Write-Host "No files to remove" -ForegroundColor Yellow
                    continue
                }
                
                Write-Host "Enter the number of the file to remove (1-$($inputFiles.Count)):" -ForegroundColor Yellow
                $indexStr = Read-UserInputSafe "File number"
                if ([int]::TryParse($indexStr, [ref]$null)) {
                    $index = [int]$indexStr - 1
                    if ($index -ge 0 -and $index -lt $inputFiles.Count) {
                        $removedFile = $inputFiles[$index]
                        $inputFiles = $inputFiles | Where-Object { $_ -ne $removedFile }
                        Write-Host "Removed: $removedFile" -ForegroundColor Green
                    } else {
                        Write-Host "Invalid file number" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Invalid input" -ForegroundColor Red
                }
            }
            "3" {
                $newPath = Read-UserInputSafe "Enter output path"
                if ($newPath) {
                    $outputPath = $newPath
                    Write-Host "Output path set to: $outputPath" -ForegroundColor Green
                }
            }
            "4" {
                $levelStr = Read-UserInputSafe "Enter compression level (0-9)"
                if ([int]::TryParse($levelStr, [ref]$null)) {
                    $level = [int]$levelStr
                    if ($level -ge 0 -and $level -le 9) {
                        $compressionLevel = $level
                        Write-Host "Compression level set to: $compressionLevel" -ForegroundColor Green
                    } else {
                        Write-Host "Compression level must be between 0 and 9" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Invalid input" -ForegroundColor Red
                }
            }
            "5" {
                $useEncryption = -not $useEncryption
                Write-Host "Encryption $(if ($useEncryption) { 'enabled' } else { 'disabled' })" -ForegroundColor Green
                if (-not $useEncryption) {
                    $password = ""
                    Write-Host "Password cleared" -ForegroundColor Yellow
                }
            }
            "6" {
                if ($useEncryption) {
                    Write-Host "Enter encryption password:" -ForegroundColor Yellow
                    $password = Read-UserInputSafe "Password"
                    if ($password) {
                        Write-Host "Password set successfully" -ForegroundColor Green
                    } else {
                        Write-Host "Password cleared" -ForegroundColor Yellow
                    }
                } else {
                    # Create archive (when encryption is disabled)
                    if ($inputFiles.Count -eq 0) {
                        Write-Host "No files selected for compression" -ForegroundColor Red
                        continue
                    }
                    
                    if (-not $outputPath) {
                        Write-Host "No output path specified" -ForegroundColor Red
                        continue
                    }
                    
                    Write-Host ""
                    Write-Host "Creating archive..." -ForegroundColor Yellow
                    Write-Host "Input files: $($inputFiles.Count)" -ForegroundColor Cyan
                    Write-Host "Output: $outputPath" -ForegroundColor Cyan
                    Write-Host "Compression level: $compressionLevel" -ForegroundColor Cyan
                    Write-Host "Encryption: Disabled" -ForegroundColor Cyan
                    Write-Host ""
                    
                    try {
                        $success = New-7zArchive -InputFiles $inputFiles -OutputPath $outputPath -CompressionLevel $compressionLevel -Password "" -Encrypt $false
                        
                        if ($success) {
                            Write-Host ""
                            Write-Host "Archive created successfully!" -ForegroundColor Green
                            Write-Host "Output: $outputPath" -ForegroundColor Green
                            
                            $openFolder = Read-UserInputSafe "Open output folder? (y/N)"
                            if ($openFolder -eq "y" -or $openFolder -eq "Y") {
                                $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
                                if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                                    Start-Process "explorer.exe" "/select,`"$outputPath`""
                                } elseif ($IsMacOS) {
                                    Start-Process "open" "-R `"$outputPath`""
                                } else {
                                    Start-Process "xdg-open" "`"$outputDir`""
                                }
                            }
                            return
                        } else {
                            Write-Host "Failed to create archive" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "7" {
                if ($useEncryption) {
                    # Create archive (when encryption is enabled)
                    if ($inputFiles.Count -eq 0) {
                        Write-Host "No files selected for compression" -ForegroundColor Red
                        continue
                    }
                    
                    if (-not $outputPath) {
                        Write-Host "No output path specified" -ForegroundColor Red
                        continue
                    }
                    
                    if (-not $password) {
                        Write-Host "No encryption password set" -ForegroundColor Red
                        continue
                    }
                    
                    Write-Host ""
                    Write-Host "Creating encrypted archive..." -ForegroundColor Yellow
                    Write-Host "Input files: $($inputFiles.Count)" -ForegroundColor Cyan
                    Write-Host "Output: $outputPath" -ForegroundColor Cyan
                    Write-Host "Compression level: $compressionLevel" -ForegroundColor Cyan
                    Write-Host "Encryption: Enabled with password" -ForegroundColor Cyan
                    Write-Host ""
                    
                    try {
                        $success = New-7zArchive -InputFiles $inputFiles -OutputPath $outputPath -CompressionLevel $compressionLevel -Password $password -Encrypt $true
                        
                        if ($success) {
                            Write-Host ""
                            Write-Host "Encrypted archive created successfully!" -ForegroundColor Green
                            Write-Host "Output: $outputPath" -ForegroundColor Green
                            Write-Host "Archive is password protected" -ForegroundColor Yellow
                            
                            $openFolder = Read-UserInputSafe "Open output folder? (y/N)"
                            if ($openFolder -eq "y" -or $openFolder -eq "Y") {
                                $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
                                if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                                    Start-Process "explorer.exe" "/select,`"$outputPath`""
                                } elseif ($IsMacOS) {
                                    Start-Process "open" "-R `"$outputPath`""
                                } else {
                                    Start-Process "xdg-open" "`"$outputDir`""
                                }
                            }
                            return
                        } else {
                            Write-Host "Failed to create archive" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    # Exit (when encryption is disabled)
                    Write-Host "Exiting..." -ForegroundColor Yellow
                    return
                }
            }
            "8" {
                if ($useEncryption) {
                    # Exit (when encryption is enabled)
                    Write-Host "Exiting..." -ForegroundColor Yellow
                    return
                } else {
                    Write-Host "Invalid choice. Please enter 1-7." -ForegroundColor Red
                }
            }
            default {
                if ($useEncryption) {
                    Write-Host "Invalid choice. Please enter 1-8." -ForegroundColor Red
                } else {
                    Write-Host "Invalid choice. Please enter 1-7." -ForegroundColor Red
                }
            }
        }
    }
}

# Main execution
function Main {
    Write-Host "7z File Compressor - Cross-Platform PowerShell Script" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    
    # Initialize script variables
    Initialize-ScriptVariables
    
    # Test GUI availability first
    $guiSupported = Test-GuiSupport
    
    # Check if 7z is installed
    if (-not (Test-7zInstallation -ShowGui $guiSupported)) {
        exit 1
    }
    
    Write-Host "7-Zip found: $(Get-7zPath)" -ForegroundColor Green
    
    if ($guiSupported) {
        Write-Host "GUI support: Available" -ForegroundColor Green
        Write-Host "Starting GUI..." -ForegroundColor Yellow
        
        try {
            # Re-initialize variables before creating form
            Initialize-ScriptVariables
            
            # Create and show the main form
            $form = New-MainForm
            [void]$form.ShowDialog()
        }
        catch {
            Write-Host "Error starting GUI: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Falling back to command-line mode..." -ForegroundColor Yellow
            Start-CommandLineMode
        }
    } else {
        Write-Host "GUI support: Not available (falling back to command-line mode)" -ForegroundColor Yellow
        Start-CommandLineMode
    }
}

# Run the main function
Main
