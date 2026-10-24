<#
.SYNOPSIS
  Puts the connect2m API (sign-in) behind HTTPS on a domain name.
.DESCRIPTION
  Microsoft and Google only allow sign-in to return to an https:// address on
  a real domain name (Google also refuses IP addresses). This sets up Caddy as
  an HTTPS front for the API server:

    https://<Domain>  ->  http://127.0.0.1:21114

  Give it your certificate (-CertFile/-KeyFile, PEM format), or leave them out
  to let Caddy get a free certificate automatically; automatic certificates
  need the domain to be reachable from the internet on ports 80 and 443.

  Then: point <Domain> at this server in your DNS, rebuild the apps with
  "api" = https://<Domain>, and use https://<Domain>/api/oidc/callback as the
  redirect URL in Microsoft Entra / Google Cloud.

  connect2m server setup. Copyright (c) 2026 Abdallah Zreik. AGPL-3.0.
.EXAMPLE
  .\Enable-Connect2mHttps.ps1 -Domain connect2m.example.com -CertFile C:\certs\c2m.crt -KeyFile C:\certs\c2m.key
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Domain,
  [string]$CertFile = "",
  [string]$KeyFile = "",
  [string]$InstallDir = "C:\connect2m-server",
  [switch]$LocalNetworkOnly
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path "$InstallDir\caddy.exe")) { throw "caddy.exe not found in $InstallDir. Run Install-Connect2mServer.ps1 first." }

$tls = ""
if ($CertFile -and $KeyFile) { $tls = "  tls `"$($CertFile -replace '\\','/')`" `"$($KeyFile -replace '\\','/')`"" }
@"
$Domain {
$tls
  reverse_proxy 127.0.0.1:21114
}
"@ | Set-Content -Encoding ASCII "$InstallDir\Caddyfile"

@"
@echo off
cd /d "$InstallDir"
"$InstallDir\caddy.exe" run --config "$InstallDir\Caddyfile" --adapter caddyfile >> "$InstallDir\logs\caddy.log" 2>&1
"@ | Set-Content -Encoding ASCII "$InstallDir\run-https.cmd"

# Sign-in callbacks must use the public https address.
$api = Get-Content "$InstallDir\run-api.cmd"
$api = $api -replace '^set RUSTDESK_API_RUSTDESK_API_SERVER=.*$', "set RUSTDESK_API_RUSTDESK_API_SERVER=https://$Domain"
$api | Set-Content -Encoding ASCII "$InstallDir\run-api.cmd"

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$InstallDir\run-https.cmd`"" -WorkingDirectory $InstallDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 `
  -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Unregister-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-https" -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "connect2m-https" -TaskPath "\connect2m\" -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Description "connect2m HTTPS" | Out-Null

$remote = if ($LocalNetworkOnly) { "LocalSubnet" } else { "Any" }
Get-NetFirewallRule -DisplayName "connect2m HTTPS" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName "connect2m HTTPS" -Direction Inbound -Action Allow -Protocol TCP `
  -LocalPort 80, 443 -RemoteAddress $remote -Profile Any | Out-Null

Stop-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-api" -ErrorAction SilentlyContinue
Get-Process apimain -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-api"
Start-ScheduledTask -TaskPath "\connect2m\" -TaskName "connect2m-https"

Write-Host "HTTPS enabled: https://$Domain" -ForegroundColor Green
Write-Host "Redirect URL for Microsoft / Google sign-in: https://$Domain/api/oidc/callback"
Write-Host "Rebuild the apps with api = https://$Domain so they sign in through it."
