@echo off
echo ========================================
echo Rebuild OTClient with MCP Screenshot API
echo ========================================
echo.

cd build
cmake --build . --config Debug --target otclient
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD SUCCESS!
echo ========================================
echo.
echo Now restart OTClient and test the MCP screenshot capture
pause
