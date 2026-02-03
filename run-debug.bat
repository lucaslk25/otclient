@echo off
echo ========================================
echo Running OTClient in Debug Mode
echo ========================================
echo.

cd /d "%~dp0"

if not exist "vc18\x64\Debug\otclient_x64-dbg.exe" (
    echo ERROR: Debug executable not found!
    echo Please build the project first using build-debug.bat
    pause
    exit /b 1
)

echo Starting otclient...
echo.
start "" "vc18\x64\Debug\otclient_x64-dbg.exe"
