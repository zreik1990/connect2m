<#
.SYNOPSIS
  Removes the connect2m server tasks and firewall rules.
.DESCRIPTION
  Keeps the install folder (with the server key, user accounts and client
  list) unless -DeleteFiles is given.
  connect2m server setup. Copyright (c) 2026 Abdallah Zreik. AGPL-3.0.
#>
[CmdletBinding()]
param(
  [string]$InstallDir = "C:\connect2m-server",
  [switch]$DeleteFiles
)
$ErrorActionPreference = "Stop"
foreach ($t in "connect2m-id", "connect2m-relay", "connect2m-api") {
  Stop-ScheduledTask -TaskPath "\connect2m\" -TaskName $t -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskPath "\connect2m\" -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}
Get-Process hbbs, hbbr, apimain -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName "connect2m *" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if ($DeleteFiles) {
  Start-Sleep -Seconds 2
  Remove-Item -Recurse -Force $InstallDir
  Write-Host "connect2m server removed, including $InstallDir."
} else {
  Write-Host "connect2m server stopped and removed. Data kept in $InstallDir."
}
