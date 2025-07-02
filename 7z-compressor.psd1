@{
    # Module manifest for 7z-compressor
    RootModule = '7z-compressor.ps1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'PowerShell Developer'
    CompanyName = 'Unknown'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'Cross-platform PowerShell script with Windows Forms GUI for creating 7z archives'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # Functions to export from this module
    FunctionsToExport = @('New-7zArchive', 'Get-7zPath', 'Test-7zInstallation')
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('7zip', 'compression', 'archive', 'gui', 'cross-platform', 'windows-forms')
            
            # A URL to the license for this module
            LicenseUri = ''
            
            # A URL to the main website for this project
            ProjectUri = ''
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # Release notes
            ReleaseNotes = @'
Version 1.0.0
- Initial release
- Cross-platform support (Windows, macOS, Linux)
- Windows Forms GUI interface
- Multi-file selection and compression
- Configurable compression levels
- Auto-generate output filenames
- File validation and error handling
'@
        }
    }
}
