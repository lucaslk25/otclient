@echo off
echo ========================================
echo OTClient - Debug Build
echo ========================================
echo.

cd /d "%~dp0\vc18"

echo Building in Debug mode...
msbuild otclient.sln /p:Configuration=Debug /p:Platform=x64 /m:4 /v:minimal

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo Build FAILED!
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Executable: vc18\x64\Debug\otclient_x64-dbg.exe
echo.
echo To run: cd .. ^&^& vc18\x64\Debug\otclient_x64-dbg.exe
echo.
pause
