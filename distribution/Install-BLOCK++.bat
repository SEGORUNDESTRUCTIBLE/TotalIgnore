@echo off
setlocal

set "BUNDLE_DIR=%~dp0"
set "INSTALLER=%BUNDLE_DIR%dist\Installer\VencordInstallerCli.exe"

if not exist "%INSTALLER%" (
    echo Could not find the bundled Vencord installer:
    echo "%INSTALLER%"
    pause
    exit /b 1
)

choice /m "Have you completely closed Discord"
if errorlevel 2 exit /b 1

set "VENCORD_USER_DATA_DIR=%BUNDLE_DIR%"
set "VENCORD_DEV_INSTALL=1"
"%INSTALLER%" -install -branch stable
if errorlevel 1 (
    echo.
    echo Installation failed. Check the installer output above.
    pause
    exit /b 1
)

echo.
echo BLOCK++ by Dr. Avinash Mandre is installed.
echo Start Discord and enable BLOCK++ in
echo User Settings -^> BLOCK++ Settings -^> Plugins.
pause
