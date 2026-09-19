@echo off
setlocal
title Tube2Reaper Setup
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Windows.ps1"
set "setupExitCode=%ERRORLEVEL%"
echo.
if not "%setupExitCode%"=="0" echo Setup failed. Review the message above.
pause
exit /b %setupExitCode%
