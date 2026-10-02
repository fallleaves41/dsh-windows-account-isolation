# 停掉隔离账户在跑的 DSH。要管理员权限：结束别的账户的进程需要它。
param(
    [string]$AgentUser = 'dsh-agent'
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if (-not $isAdmin) { throw '停进程需要管理员权限。' }

$killed = 0
foreach ($p in Get-CimInstance Win32_Process -Filter "Name = 'node.exe' or Name = 'powershell.exe'") {
    $owner = ''
    try { $owner = (Invoke-CimMethod -InputObject $p -MethodName GetOwner).User } catch { }
    if ($owner -eq $AgentUser) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "已结束 $($p.Name)（PID $($p.ProcessId)）"
        $killed++
    }
}

if ($killed -eq 0) { Write-Host "$AgentUser 名下没有在跑的进程。" }
