<#
.SYNOPSIS
  Installs the connect2m server on this Windows PC or Windows Server.

.DESCRIPTION
  Sets up, as background tasks that start with Windows:
    - ID server  (hbbs, ports 21115-21116, 21118)
    - Relay      (hbbr, ports 21117, 21119)
    - API server (port 21114): sign-in (Microsoft / Google / local accounts),
      the shared client list (address book), admin web page and the
      connect2m download page.
  Firewall rules only accept connections from this computer's local network.

  Run from an elevated PowerShell in the unzipped bundle folder:
    powershell -ExecutionPolicy Bypass -File .\Install-Connect2mServer.ps1

.PARAMETER ServerAddress
  The address the apps use to reach this server: its LAN IP (detected
  automatically) or a DNS name such as connect2m-server.

.PARAMETER InstallDir
  Where the server is installed. Default: C:\connect2m-server

.PARAMETER RequireKey
  Only accept apps built with this server's key. Use it once your apps have
  been rebuilt with the key this script prints.

.NOTES
  connect2m server setup. Copyright (c) 2026 Abdallah Zreik. AGPL-3.0.
#>
[CmdletBinding()]
param(
  [string]$ServerAddress = "",
  [string]$InstallDir = "C:\connect2m-server",
  [switch]$RequireKey
)

$ErrorActionPreference = "Stop"
$Bundle = Split-Path -Parent $MyInvocation.MyCommand.Path

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run this script from PowerShell opened with 'Run as administrator'."
  }
}

function Get-LanAddress {
  $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Sort-Object -Property InterfaceMetric | Select-Object -First 1
  if ($ip) { return $ip.IPAddress }
  return $env:COMPUTERNAME
}

function New-RandomPassword([int]$Length = 16) {
  $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  $bytes = New-Object byte[] $Length
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Register-Connect2mTask([string]$Name, [string]$Cmd, [string]$WorkDir) {
  $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$Cmd`"" -WorkingDirectory $WorkDir
  $trigger = New-ScheduledTaskTrigger -AtStartup
  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable
  Unregister-ScheduledTask -TaskPath "\connect2m\" -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue
  Register-ScheduledTask -TaskName $Name -TaskPath "\connect2m\" -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Description "connect2m server" | Out-Null
}

Assert-Admin
if (-not $ServerAddress) { $ServerAddress = Get-LanAddress }
Write-Host "Installing the connect2m server for address $ServerAddress into $InstallDir" -ForegroundColor Cyan

# Stop an earlier installation before files are replaced.
foreach ($t in "connect2m-id", "connect2m-relay", "connect2m-api") {
  Stop-ScheduledTask -TaskPath "\connect2m\" -TaskName $t -ErrorAction SilentlyContinue
}
Get-Process hbbs, hbbr, apimain -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Files
New-Item -ItemType Directory -Force -Path $InstallDir, "$InstallDir\data", "$InstallDir\logs", "$InstallDir\api" | Out-Null
Copy-Item "$Bundle\bin\*" $InstallDir -Recurse -Force
Copy-Item "$Bundle\api\*" "$InstallDir\api" -Recurse -Force
$Upload = "$InstallDir\api\resources\public\upload"
New-Item -ItemType Directory -Force -Path $Upload | Out-Null
Copy-Item "$Bundle\www\*" $Upload -Recurse -Force
foreach ($f in "Install-Connect2mServer.ps1", "Uninstall-Connect2mServer.ps1", "Update-Connect2mDownloads.ps1", "README.md") {
  if (Test-Path "$Bundle\$f") { Copy-Item "$Bundle\$f" $InstallDir -Force }
}

# ID server and relay
$KeyArg = if ($RequireKey) { "-k _" } else { "" }
@"
@echo off
cd /d "$InstallDir\data"
set MUST_LOGIN=N
"$InstallDir\hbbs.exe" -r $($ServerAddress):21117 $KeyArg >> "$InstallDir\logs\hbbs.log" 2>&1
"@ | Set-Content -Encoding ASCII "$InstallDir\run-id.cmd"
@"
@echo off
cd /d "$InstallDir\data"
"$InstallDir\hbbr.exe" $KeyArg >> "$InstallDir\logs\hbbr.log" 2>&1
"@ | Set-Content -Encoding ASCII "$InstallDir\run-relay.cmd"

# API server (sign-in, shared client list, admin page, download page)
@"
@echo off
cd /d "$InstallDir\api"
set RUSTDESK_API_LANG=en
set RUSTDESK_API_ADMIN_TITLE=connect2m Admin
set RUSTDESK_API_APP_REGISTER=false
set RUSTDESK_API_APP_WEB_CLIENT=0
set RUSTDESK_API_RUSTDESK_ID_SERVER=$($ServerAddress):21116
set RUSTDESK_API_RUSTDESK_RELAY_SERVER=$($ServerAddress):21117
set RUSTDESK_API_RUSTDESK_API_SERVER=http://$($ServerAddress):21114
set RUSTDESK_API_RUSTDESK_KEY_FILE=$InstallDir\data\id_ed25519.pub
set RUSTDESK_API_JWT_KEY=
"$InstallDir\api\apimain.exe" >> "$InstallDir\logs\api.log" 2>&1
"@ | Set-Content -Encoding ASCII "$InstallDir\run-api.cmd"

Register-Connect2mTask "connect2m-id" "$InstallDir\run-id.cmd" "$InstallDir\data"
Register-Connect2mTask "connect2m-relay" "$InstallDir\run-relay.cmd" "$InstallDir\data"
Register-Connect2mTask "connect2m-api" "$InstallDir\run-api.cmd" "$InstallDir\api"

# Firewall: only this computer's local network may connect.
Get-NetFirewallRule -DisplayName "connect2m *" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName "connect2m server (TCP)" -Direction Inbound -Action Allow -Protocol TCP `
  -LocalPort 21114-21119 -RemoteAddress LocalSubnet -Profile Any | Out-Null
New-NetFirewallRule -DisplayName "connect2m server (UDP)" -Direction Inbound -Action Allow -Protocol UDP `
  -LocalPort 21116 -RemoteAddress LocalSubnet -Profile Any | Out-Null

# Start, and wait for the ID server to create its key pair.
Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-id"
Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-relay"
$pub = "$InstallDir\data\id_ed25519.pub"
for ($i = 0; $i -lt 30 -and -not (Test-Path $pub); $i++) { Start-Sleep -Seconds 1 }
if (-not (Test-Path $pub)) { throw "The ID server did not start. See $InstallDir\logs\hbbs.log" }
$Key = (Get-Content $pub -Raw).Trim()

Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-api"
Start-Sleep -Seconds 6

# Admin password for the web admin page.
$AdminPassword = New-RandomPassword 14
Push-Location "$InstallDir\api"
try {
  Stop-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-api" -ErrorAction SilentlyContinue
  Get-Process apimain -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  & "$InstallDir\api\apimain.exe" reset-admin-pwd $AdminPassword | Out-Null
} finally { Pop-Location }
Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-api"

$info = @"
connect2m server
================
Server address : $ServerAddress
Server key     : $Key
Admin page     : http://$($ServerAddress):21114/_admin/
  user         : admin
  password     : $AdminPassword
Download page  : http://$($ServerAddress):21114/upload/

Build the apps for this server: in GitHub, Actions > "Build connect2m for Windows" >
Run workflow, and enter the server address and key above. After installing
the rebuilt apps, run this script again with -RequireKey.
"@
Set-Content -Encoding UTF8 "$InstallDir\connect2m-server-info.txt" $info
Write-Host ""
Write-Host $info -ForegroundColor Green
Write-Host "(Saved to $InstallDir\connect2m-server-info.txt. Keep the admin password safe.)"
