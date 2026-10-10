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
"%INSTALLER%" -uninstall -branch stable
if errorlevel 1 (
    echo.
    echo Uninstallation failed. Check the installer output above.
    pause
    exit /b 1
)

echo.
echo BLOCK++++ by Dr. Avinash Mandre has been removed with Vencord
echo from Discord Stable.
pause
