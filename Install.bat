@echo off
setlocal EnableDelayedExpansion

powershell -Command "Set-ItemProperty -Path 'HKCU:\Console' -Name 'VirtualTerminalLevel' -Value 1" >nul 2>&1

set "NEON_CYAN=="
set "NEON_MAGENTA=="
set "NEON_GREEN=="
set "NEON_RED=="
set "NEON_YELLOW=="
set "MATRIX_RESET=="

echo %NEON_MAGENTA%+===============================+%MATRIX_RESET%
echo %NEON_CYAN%    DUO WINDOWS LOGON INSTALL    %MATRIX_RESET%
echo %NEON_MAGENTA%+===============================+%MATRIX_RESET%

REM Check if hostname is provided
if "%~1"=="" (
    echo %NEON_YELLOW%No hostname provided. You will be prompted.%MATRIX_RESET%
    set "HOSTNAME="
) else (
    set "HOSTNAME=%~1"
)

REM Probe network privileges
echo %NEON_YELLOW%Scanning access vectors...%MATRIX_RESET%
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %NEON_RED%Elevating system access%MATRIX_RESET%
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c %~dpnx0 %HOSTNAME%' -Verb RunAs"
    exit /b
)

REM Locate payload
echo %NEON_YELLOW%Locating quantum module...%MATRIX_RESET%
set "CYBERWARE_PAYLOAD=%~dp0DuoWin2Login.ps1"
if not exist "%CYBERWARE_PAYLOAD%" (
    echo %NEON_RED%Module not found%MATRIX_RESET%
    pause
    exit /b 1
)

REM Bypass execution policy
echo %NEON_CYAN%Hacking neural protocols...%MATRIX_RESET%
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force" >nul 2>&1

REM Deploy authentication
echo %NEON_GREEN%Initializing quantum auth...%MATRIX_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -File "%CYBERWARE_PAYLOAD%" -hostname "%HOSTNAME%"
if %ERRORLEVEL% neq 0 (
    echo %NEON_RED%Error: Installation failed. Check %TEMP%\DuoInstallLog.txt for details.%MATRIX_RESET%
    pause
    exit /b 1
)

REM Reset system
echo %NEON_YELLOW%Restoring system integrity...%MATRIX_RESET%
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Restricted -Force" >nul 2>&1

echo %NEON_MAGENTA%+=====================================+%MATRIX_RESET%
echo %NEON_GREEN%    DUO LOGON INSTALLATION COMPLETE    %MATRIX_RESET%
echo %NEON_MAGENTA%+=====================================+%MATRIX_RESET%
pause