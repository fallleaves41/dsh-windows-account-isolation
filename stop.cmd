@echo off
rem Stop the DSH server running as the isolated account. Needs administrator rights.
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo Administrator rights required, restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'stop-agent-dsh.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); & $sb"

echo.
pause
