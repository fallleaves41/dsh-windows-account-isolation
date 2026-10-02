@echo off
rem Build the isolated account. Re-launches itself with UAC when not elevated.
rem Usage:  setup.cmd  [project path]      (default: C:\work\myproj)
setlocal
cd /d "%~dp0"

set "PRJ=%~1"
if "%PRJ%"=="" set "PRJ=C:\work\myproj"

net session >nul 2>&1
if errorlevel 1 (
    echo Administrator rights required, restarting elevated...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%PRJ%' -Verb RunAs"
    exit /b
)

if not exist "%PRJ%" (
    echo Project folder does not exist: %PRJ%
    echo Create it first:  mkdir "%PRJ%"
    pause
    exit /b 1
)

echo Project: %PRJ%
powershell -NoProfile -Command "$f = Join-Path (Get-Location) 'setup-agent-account.ps1'; if (-not (Test-Path -LiteralPath $f)) { Write-Host ('script not found: ' + $f); exit 2 }; Write-Host ('script: ' + $f); $sb = [scriptblock]::Create((Get-Content -LiteralPath $f -Raw -Encoding UTF8)); & $sb -ProjectPath '%PRJ%' -DenySensitive"

echo.
pause
