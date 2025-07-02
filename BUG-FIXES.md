# 7z Compressor - Bug Fixes Applied

## Issue Resolved
Fixed the "You cannot call a method on a null-valued expression" error that was occurring when selecting files in the Windows GUI.

## Root Cause
The issue was caused by:
1. **Array vs ArrayList**: Using PowerShell arrays (`@()`) instead of proper .NET collections for dynamic operations
2. **Null Reference Handling**: Insufficient null checks in event handlers
3. **Variable Initialization**: Script-scoped variables not being properly initialized before GUI creation

## Fixes Applied

### 1. **Improved Variable Initialization**
- Changed `$script:SelectedFiles` from PowerShell array to `System.Collections.ArrayList`
- Added `Initialize-ScriptVariables` function to ensure proper initialization
- Added multiple initialization checkpoints throughout the script

### 2. **Enhanced Event Handlers**
All GUI event handlers now include:
- **Comprehensive null checks** for all objects before use
- **Defensive programming** patterns with explicit null validation
- **Try-catch blocks** with proper error handling and user feedback
- **Safe disposal** of dialog objects

### 3. **Robust File Operations**
- **Add Files**: Now safely handles null dialog results, validates file existence, and includes comprehensive path operations
- **Remove Files**: Uses ArrayList.Remove() instead of array filtering for better performance
- **Clear All**: Safely clears both ArrayList and ListBox with fallback initialization
- **Browse Output**: Added null checks for dialog creation and results

### 4. **Type Safety Improvements**
- Convert ArrayList to array when passing to `New-7zArchive` function
- Explicit null comparisons following PowerShell best practices
- Added validation for all user inputs and file paths

## Testing Recommendations

### Windows Testing
1. **Launch the script** in PowerShell on Windows
2. **Test file selection** - click "Add Files" and select multiple files
3. **Test file removal** - select files in the list and click "Remove Selected"
4. **Test clear functionality** - click "Clear All"
5. **Test output browsing** - click "Browse..." for output path
6. **Test compression** - create an archive with various settings

### Expected Behavior
- **No more stack traces** when selecting files
- **Smooth GUI operations** with proper error handling
- **User-friendly error messages** instead of technical exceptions
- **Graceful degradation** if any component fails

## Files Modified
- `7z-compressor.ps1` - Main script with comprehensive null safety improvements
- All event handlers updated with defensive programming patterns
- Variable initialization system added

## Additional Improvements
- **Better error messages** for users instead of technical stack traces
- **Improved resource management** with proper dialog disposal
- **Enhanced validation** for all file and path operations
- **Consistent null checking** throughout the codebase

The script should now run smoothly on Windows without the null reference errors that were occurring during file selection operations.
