# Check Updates installer for Windows 10/11.
# Usage (PowerShell): irm https://check-updates.armanalis.workers.dev/install.ps1 | iex
# Files downloaded by PowerShell don't get the "from the internet" mark, so SmartScreen doesn't block the app.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$url = 'https://check-updates.armanalis.workers.dev/CheckUpdates.exe'
$dir = Join-Path $env:LOCALAPPDATA 'Programs\CheckUpdates'   # per-user, no admin rights needed
$exe = Join-Path $dir 'CheckUpdates.exe'

Write-Host 'Check Updates indiriliyor...'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Get-Process -Name CheckUpdates -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null; $_.WaitForExit(5000) | Out-Null }
$tmp = "$exe.download"
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
Move-Item -Force $tmp $exe

# Start menu shortcut so it can be found by searching "Check Updates"
$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Check Updates.lnk'
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$shortcut.TargetPath = $exe
$shortcut.Save()

Write-Host "Kuruldu: $exe"
Start-Process $exe
