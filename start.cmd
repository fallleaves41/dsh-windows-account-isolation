@echo off
rem Start DSH web as the isolated account and print the URL.
rem Usage:  start.cmd  [work dir]      (default: C:\dsh-agent\work)
setlocal
cd /d "%~dp0"

set "PRJ=%~1"

powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'start-agent-dsh.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); if ('%PRJ%') { & $sb -WorkDir '%PRJ%' } else { & $sb }"

echo.
pause
