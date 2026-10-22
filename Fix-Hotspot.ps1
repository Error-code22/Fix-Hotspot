<#
    Fix-Hotspot.ps1

    Repairs the Windows "Connected, no internet" mobile-hotspot bug where the
    ICS DNS proxy stops listening on 192.168.137.1:53 while DHCP keeps working.

    Behaviour:
      * Checks first. If the hotspot is healthy, it exits without a UAC prompt.
      * If broken, it self-elevates, restarts the ICS service, re-enables the
        hotspot, and verifies DNS is answering again.
      * Every run is logged to %LOCALAPPDATA%\HotspotFix\fix.log
#>
param([switch]$NoPause)

$ErrorActionPreference = 'Stop'
$logDir  = Join-Path $env:LOCALAPPDATA 'HotspotFix'
$logFile = Join-Path $logDir 'fix.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    try { '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message | Add-Content -Path $logFile } catch { }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime]
$null = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime]

function Get-TetheringManager {
    $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    if ($null -eq $profile) { throw 'No internet connection profile found.' }
    [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
}

function Get-HotspotAddress {
    (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq '192.168.137.1' } |
        Select-Object -First 1).IPAddress
}

function Test-IcsDns {
    if (-not (Get-HotspotAddress)) { return $false }
    try {
        $answer = Resolve-DnsName 'www.msftconnecttest.com' -Server 192.168.137.1 `
                    -Type A -DnsOnly -QuickTimeout -ErrorAction Stop
        return [bool]($answer | Where-Object { $_.IPAddress })
    } catch { return $false }
}

function Wait-Until {
    param([scriptblock]$Condition, [int]$Seconds)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds 500
    }
    [bool](& $Condition)
}

Write-Log '--- Fix Hotspot started ---'

if (-not (Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq 'Internet' })) {
    Write-Log 'The laptop itself has no internet. Fix the uplink (cellular/Wi-Fi) first.' 'Red'
}
else {
    $mgr = Get-TetheringManager
    Write-Log ("Hotspot state: {0}" -f $mgr.TetheringOperationalState)

    if (Test-IcsDns) {
        Write-Log 'Hotspot DNS is healthy - nothing to fix.' 'Green'
    }
    else {
        Write-Log 'Hotspot DNS proxy is not responding on 192.168.137.1.' 'Yellow'

        if (-not (Test-Admin)) {
            Write-Log 'Repair needed - requesting administrator rights...' 'Yellow'
            Start-Process powershell -Verb RunAs -ArgumentList (
                '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
            exit
        }

        Write-Log 'Restarting Internet Connection Sharing (ICS)...'
        Restart-Service SharedAccess -Force
        Start-Sleep -Seconds 3
        if ((Get-Service SharedAccess).Status -ne 'Running') { Start-Service SharedAccess }

        Write-Log 'Re-enabling the mobile hotspot...'
        $mgr = Get-TetheringManager
        if (-not (Get-HotspotAddress)) {
            if ($mgr.TetheringOperationalState -ne 'Off') {
                try {
                    $null = $mgr.StopTetheringAsync()
                    $null = Wait-Until { $mgr.TetheringOperationalState -eq 'Off' } 15
                } catch { }
            }
            $null = $mgr.StartTetheringAsync()
            $null = Wait-Until { [bool](Get-HotspotAddress) } 30
        }

        Start-Sleep -Seconds 2
        if (Test-IcsDns) {
            Write-Log 'Fixed: hotspot DNS is answering again. Reconnect the phone if needed.' 'Green'
        }
        else {
            Write-Log 'Repair did not take effect. Toggle the hotspot in Settings, then rerun.' 'Red'
        }
    }
}

if (-not $NoPause) { Read-Host 'Press Enter to close' | Out-Null }
