# Install Ralph setup script globally for Windows
# Usage: .\install.ps1

$ErrorActionPreference = "Stop"

$RalphDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = "$env:LOCALAPPDATA\Ralph"
$WrapperName = "ralph-setup.cmd"

# Check if running with administrator privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ""
Write-Host "Installing Ralph for Windows..." -ForegroundColor Cyan
Write-Host ""

# Detect available bash environment
$BashPath = $null
$BashType = $null

# Check for WSL
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $BashPath = "wsl"
    $BashType = "WSL"
}
# Check for Git Bash
elseif (Test-Path "C:\Program Files\Git\bin\bash.exe") {
    $BashPath = "C:\Program Files\Git\bin\bash.exe"
    $BashType = "Git Bash"
}
elseif (Test-Path "C:\Program Files (x86)\Git\bin\bash.exe") {
    $BashPath = "C:\Program Files (x86)\Git\bin\bash.exe"
    $BashType = "Git Bash"
}
else {
    Write-Host "ERROR: No bash environment found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ralph requires either:" -ForegroundColor Yellow
    Write-Host "  1. WSL (Windows Subsystem for Linux) - Recommended" -ForegroundColor Yellow
    Write-Host "  2. Git Bash" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install WSL, run:" -ForegroundColor Cyan
    Write-Host "  wsl --install" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✓ Found $BashType" -ForegroundColor Green

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Convert Windows path to WSL/Unix path for the wrapper
$UnixRalphPath = $RalphDir -replace '\\', '/'
if ($BashType -eq "WSL") {
    # Convert C:\Path to /mnt/c/Path for WSL
    if ($UnixRalphPath -match '^([A-Za-z]):(.*)') {
        $drive = $matches[1].ToLower()
        $path = $matches[2]
        $UnixRalphPath = "/mnt/$drive$path"
    }
}

# Create wrapper batch file
$WrapperPath = Join-Path $InstallDir $WrapperName
$WrapperContent = @"
@echo off
REM Ralph setup wrapper for Windows
REM This script calls ralph-setup.sh using $BashType

if "%BashType%" == "WSL" (
    wsl bash "$UnixRalphPath/setup-ralph.sh" %*
) else (
    "$BashPath" "$UnixRalphPath/setup-ralph.sh" %*
)
"@

$WrapperContent = $WrapperContent -replace '%BashType%', $BashType
$WrapperContent | Set-Content -Path $WrapperPath -Encoding ASCII

Write-Host "✓ Created wrapper script at $WrapperPath" -ForegroundColor Green

# Add to PATH if not already there
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Host ""
    Write-Host "Adding Ralph to your PATH..." -ForegroundColor Cyan
    
    $NewPath = "$UserPath;$InstallDir"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    
    # Update current session
    $env:Path = "$env:Path;$InstallDir"
    
    Write-Host "✓ Added $InstallDir to PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✓ Ralph installed globally!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run from anywhere:" -ForegroundColor White
Write-Host "  ralph-setup C:\path\to\your\project" -ForegroundColor Yellow
Write-Host ""
Write-Host "Using: $BashType" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall:" -ForegroundColor White
Write-Host "  Remove-Item -Recurse '$InstallDir'" -ForegroundColor Gray
Write-Host "  Then manually remove from PATH in System Environment Variables" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTE: You may need to restart your terminal for PATH changes to take effect" -ForegroundColor Yellow
Write-Host ""
