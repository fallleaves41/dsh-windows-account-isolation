@echo off
rem Trim the isolated instance's workspace list down to one project directory.
rem Run stop.cmd first. Usage:  reset-workspaces.cmd  [project path]   (default: C:\work\myproj)
setlocal
cd /d "%~dp0"

set "PRJ=%~1"
if "%PRJ%"=="" set "PRJ=C:\work\myproj"

powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'reset-workspaces.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); & $sb -Path '%PRJ%'"

echo.
pause
