@echo off
REM Ralph Windows wrapper - runs ralph.sh using WSL or Git Bash
REM Usage: ralph.cmd [max_iterations] [--verbose] [--timeout SECONDS]

REM Detect bash environment
where wsl >nul 2>&1
if %ERRORLEVEL% == 0 (
    wsl bash ./ralph.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" ./ralph.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" ./ralph.sh %*
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
