@echo off
rem Check whether the isolation actually holds.
rem Usage:  verify.cmd  [project path]      (default: C:\work\myproj)
setlocal
cd /d "%~dp0"

set "PRJ=%~1"
if "%PRJ%"=="" set "PRJ=C:\work\myproj"

powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'verify-isolation.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); & $sb -ProjectPath '%PRJ%'"

echo.
pause
