# Creates or refreshes the "Fix Hotspot" shortcut on the current user's Desktop.
# Run this after moving the project folder to a new location.

$ErrorActionPreference = 'Stop'

$batPath = Join-Path $PSScriptRoot 'Fix Hotspot.bat'
$iconPath = Join-Path $PSScriptRoot 'hotspot.ico'

if (-not (Test-Path $batPath)) {
    throw "Fix Hotspot.bat was not found next to Install.ps1."
}
if (-not (Test-Path $iconPath)) {
    throw "hotspot.ico was not found. Run Build-Icon.ps1 to regenerate it."
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Fix Hotspot.lnk'

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($shortcutPath)
$sc.TargetPath = $batPath
$sc.WorkingDirectory = $PSScriptRoot
$sc.IconLocation = "$iconPath,0"
$sc.Description = 'Repair the Windows mobile hotspot DNS (ICS)'
$sc.Save()

Write-Host "Shortcut created: $shortcutPath"
Write-Host "Icon: $iconPath"
