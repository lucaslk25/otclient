@echo off
echo ========================================
echo OTClient Build Script for Windows
echo ========================================
echo.

REM Check if vcpkg is installed
if not defined VCPKG_ROOT (
    echo ERROR: VCPKG_ROOT environment variable is not set!
    echo Please install vcpkg and set VCPKG_ROOT to its path.
    echo Example: set VCPKG_ROOT=C:\vcpkg
    pause
    exit /b 1
)

echo Using vcpkg from: %VCPKG_ROOT%
echo.

REM Try to find CMake from Visual Studio
set "CMAKE_PATH="
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" (
    set "CMAKE_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" (
    set "CMAKE_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
)
if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" (
    set "CMAKE_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
)

if not defined CMAKE_PATH (
    echo ERROR: CMake not found!
    echo Please install CMake from: https://cmake.org/download/
    echo Or use Visual Studio Developer Command Prompt
    pause
    exit /b 1
)

echo Found CMake at: %CMAKE_PATH%
set "PATH=%CMAKE_PATH%;%PATH%"
echo.

REM Clean previous build
if exist build\windows-release (
    echo Cleaning previous build...
    rmdir /s /q build\windows-release
)

echo.
echo Configuring CMake...
cmake --preset windows-release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: CMake configuration failed!
    pause
    exit /b 1
)

echo.
echo Building project...
cmake --build build\windows-release --config RelWithDebInfo -j 4

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo Executable location: build\windows-release\
echo ========================================
pause
