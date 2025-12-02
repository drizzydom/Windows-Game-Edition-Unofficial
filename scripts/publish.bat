@echo off
REM ============================================================================
REM Windows Game Edition - Build & Publish Script (Windows)
REM ============================================================================
REM This script compiles the WPF application to a single Windows EXE.
REM
REM Usage: scripts\publish.bat [--clean] [--verbose]
REM ============================================================================

setlocal EnableDelayedExpansion

echo.
echo ======================================================================
echo     Windows Game Edition - Build Script
echo     Building on Windows
echo ======================================================================
echo.

REM Check for .NET SDK
where dotnet >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] .NET SDK not found!
    echo Please install it first:
    echo   winget install Microsoft.DotNet.SDK.8
    echo   or download from https://dotnet.microsoft.com/download
    exit /b 1
)

for /f "tokens=*" %%i in ('dotnet --version') do set DOTNET_VERSION=%%i
echo [OK] .NET SDK version: %DOTNET_VERSION%

REM Set paths
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set APP_PROJECT=%PROJECT_ROOT%\src\WGE.App
set DIST_DIR=%PROJECT_ROOT%\dist

REM Parse arguments
set CLEAN=false
set VERBOSE=false
:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="--clean" set CLEAN=true
if "%~1"=="--verbose" set VERBOSE=true
shift
goto :parse_args
:done_parsing

REM Clean if requested
if "%CLEAN%"=="true" (
    echo [INFO] Cleaning previous builds...
    if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
    if exist "%APP_PROJECT%\bin" rmdir /s /q "%APP_PROJECT%\bin"
    if exist "%APP_PROJECT%\obj" rmdir /s /q "%APP_PROJECT%\obj"
    echo [OK] Clean complete
)

REM Create dist directory
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

REM Build configuration
set RUNTIME=win-x64
set CONFIG=Release

echo.
echo [INFO] Building for %RUNTIME%...
echo        Configuration: %CONFIG%
echo        Output: %DIST_DIR%
echo.

REM Build arguments
set BUILD_ARGS=publish -c %CONFIG% -r %RUNTIME% -o "%DIST_DIR%" --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true

if "%VERBOSE%"=="true" (
    set BUILD_ARGS=%BUILD_ARGS% -v normal
) else (
    set BUILD_ARGS=%BUILD_ARGS% -v minimal
)

REM Run the build
cd /d "%APP_PROJECT%"
echo [INFO] Compiling (this may take a minute)...

dotnet %BUILD_ARGS%
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build failed!
    exit /b 1
)

echo.
echo [OK] Build successful!

REM Check output
if exist "%DIST_DIR%\WGE.App.exe" (
    echo.
    echo [SUCCESS] Single-file executable ready!
    echo           File: %DIST_DIR%\WGE.App.exe
    echo.
    echo Next steps:
    echo   1. Run WGE.App.exe as Administrator
    echo   2. Select a preset and click 'Apply Preset'
    echo.
)

echo ======================================================================
endlocal
