@echo off
REM create-prd Windows wrapper - runs create-prd.sh using WSL or Git Bash
REM Usage: create-prd.cmd [OPTIONS] "your project description"

REM Detect bash environment
where wsl >nul 2>&1
if %ERRORLEVEL% == 0 (
    wsl bash ./create-prd.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" ./create-prd.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" ./create-prd.sh %*
    exit /b %ERRORLEVEL%
)

echo ERROR: No bash environment found!
echo.
echo Ralph requires either:
echo   1. WSL (Windows Subsystem for Linux) - Recommended
echo   2. Git Bash
echo.
echo To install WSL, run:
echo   wsl --install
echo.
exit /b 1
