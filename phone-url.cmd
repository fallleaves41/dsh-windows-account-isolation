@echo off
rem Print the phone-ready URL (Tailscale IP + current token).
rem Usage:  phone-url.cmd  [100.x.y.z]
setlocal
cd /d "%~dp0"

set "TS=%~1"

powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'phone-url.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); if ('%TS%') { & $sb -TailscaleIp '%TS%' } else { & $sb }"

echo.
pause
