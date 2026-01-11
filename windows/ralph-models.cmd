@echo off
REM ralph-models Windows wrapper - runs ralph-models.sh using WSL or Git Bash
REM Usage: ralph-models.cmd [agent-name] [--refresh]

REM Detect bash environment
where wsl >nul 2>&1
if %ERRORLEVEL% == 0 (
    wsl bash ./ralph-models.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" ./ralph-models.sh %*
    exit /b %ERRORLEVEL%
)

if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" ./ralph-models.sh %*
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
