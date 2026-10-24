<#
.SYNOPSIS
  Puts the newest connect2m installers on the server's download page.
.DESCRIPTION
  Downloads connect2m-Setup.exe (technicians) and connect2m-Client.msi (client
  PCs) from the latest GitHub release, or copies them from -FromFolder.
  connect2m server setup. Copyright (c) 2026 Abdallah Zreik. AGPL-3.0.
.EXAMPLE
  .\Update-Connect2mDownloads.ps1
.EXAMPLE
  .\Update-Connect2mDownloads.ps1 -FromFolder "$env:USERPROFILE\Downloads"
#>
[CmdletBinding()]
param(
  [string]$InstallDir = "C:\connect2m-server",
  [string]$Repository = "__CONNECT2M_REPOSITORY__",
  [string]$FromFolder = ""
)
$ErrorActionPreference = "Stop"
$Upload = "$InstallDir\api\resources\public\upload"
New-Item -ItemType Directory -Force -Path $Upload | Out-Null
$files = "connect2m-Setup.exe", "connect2m-Client.msi"
foreach ($f in $files) {
  if ($FromFolder) {
    Copy-Item (Join-Path $FromFolder $f) (Join-Path $Upload $f) -Force
  } else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/$Repository/releases/latest/download/$f"
    Write-Host "Downloading $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $Upload $f)
  }
}
Write-Host "Download page updated: $Upload" -ForegroundColor Green
