@echo off
setlocal
rem Launch the hotspot repair script without keeping this console open.
if not exist "%~dp0Fix-Hotspot.ps1" (
    echo Fix-Hotspot.ps1 is missing from this folder.
    pause
    exit /b 1
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-Hotspot.ps1" %*
endlocal
