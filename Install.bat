@echo off
setlocal

REM Check if running as admin; if not, relaunch with elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c %~dpnx0' -Verb RunAs"
    exit /b
)

REM Define the PowerShell script path based on the .bat file location
set "PS_SCRIPT=%~dp0DuoWin2Login.ps1"

REM Check if the PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo Error: PowerShell script not found at %PS_SCRIPT%
    echo Please ensure DuoWin2Login.ps1 is in the same directory as this .bat file.
    pause
    exit /b 1
)

REM Temporarily set PowerShell execution policy to Bypass
echo Setting PowerShell execution policy to Bypass...
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force"

REM Run the PowerShell script from the .bat file's location
echo Launching PowerShell script with admin privileges...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

REM Optional: Revert execution policy to default
echo Reverting PowerShell execution policy...
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Restricted -Force"

echo Script execution completed.
pause