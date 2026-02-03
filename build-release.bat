@echo off
echo ========================================
echo OTClient - Release Build (OpenGL)
echo ========================================
echo.

cd /d "%~dp0\vc18"

echo Building in OpenGL Release mode...
msbuild otclient.sln /p:Configuration=OpenGL /p:Platform=x64 /m:4 /v:minimal

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
echo Executable: vc18\x64\OpenGL\otclient_gl_x64.exe
echo.
echo To run: cd .. ^&^& vc18\x64\OpenGL\otclient_gl_x64.exe
echo.
pause
