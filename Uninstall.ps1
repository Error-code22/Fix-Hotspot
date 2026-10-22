# Removes the "Fix Hotspot" shortcut from the current user's Desktop.
# The project files and log file are left in place.

$ErrorActionPreference = 'Stop'

$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fix Hotspot.lnk'

if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "Removed: $shortcutPath"
}
else {
    Write-Host "Shortcut not found: $shortcutPath"
}

Write-Host "Logs remain in: $(Join-Path $env:LOCALAPPDATA 'HotspotFix')"
