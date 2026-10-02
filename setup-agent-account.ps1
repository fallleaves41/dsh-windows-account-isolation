# 给 DeepSeek Harness 建一个隔离账户。
# 管理员 PowerShell 里跑：.\setup-agent-account.ps1 -ProjectPath C:\work\myproj
param(
    [string]$AgentUser = 'dsh-agent',
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$Root = 'C:\dsh-agent',
    [switch]$DenySensitive,
    [switch]$NoMigrate
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if (-not $isAdmin) { throw '这个脚本要用管理员权限跑。' }

$proj = (Resolve-Path -LiteralPath $ProjectPath).Path
$dshHome = Join-Path $Root 'home'

foreach ($d in @($Root, $dshHome, (Join-Path $Root 'log'), (Join-Path $Root 'work'))) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$here = $PSScriptRoot
if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $here) { $here = (Get-Location).Path }
$runner = Join-Path $here 'run-dsh-web.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "同目录下找不到 run-dsh-web.ps1（当前目录：$here）" }
Copy-Item -LiteralPath $runner -Destination $Root -Force

if (-not (Get-LocalUser -Name $AgentUser -ErrorAction SilentlyContinue)) {
    $pw = Read-Host -AsSecureString "给 $AgentUser 设个密码"
    New-LocalUser $AgentUser -Password $pw -FullName 'DSH agent' `
        -PasswordNeverExpires -AccountNeverExpires | Out-Null
    Write-Host "账户 $AgentUser 建好了"
}

$inAdmin = Get-LocalGroupMember Administrators -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*\$AgentUser" }
if ($inAdmin) {
    throw "$AgentUser 在管理员组里，先移出去：Remove-LocalGroupMember Administrators $AgentUser"
}

if (-not $NoMigrate) {
    $src = Join-Path $env:USERPROFILE '.dsh'
    if (-not (Test-Path -LiteralPath $src)) { throw "找不到 $src" }

    # 会话、附件、缓存和 node_modules 不搬：前几个是隐私，node_modules 让新账户自己装。
    $skip = 'sessions', 'attachments', 'logs', 'cache', 'dsh-session-archive',
    'pnpm-store-tmp', 'task-board', 'dsh-usage', 'node_modules'

    robocopy $src $dshHome /e /xd @skip /r:1 /w:1 /nfl /ndl /njh /njs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy 失败，退出码 $LASTEXITCODE" }
    Write-Host "配置已复制到 $dshHome"
    Write-Host '注意 .credentials.yaml 也复制过去了，模型凭据在这个账户下有一份副本。'
}

icacls $Root /grant "${AgentUser}:(OI)(CI)F" /t /c | Out-Null
if ($LASTEXITCODE -ne 0) { throw "授权失败：$Root" }
Write-Host "$Root 已授权给 $AgentUser"

# 工作区必须给「完全控制」，不能只给「修改(M)」：
# DSH 的 Windows ACL 沙箱每跑一条命令都要往工作区目录写 ACL（加能力 SID 的允许 ACE
# 和 Low 完整性标签），那需要 WRITE_DAC；M 里不含这个权利，结果是 pwsh / run_code
# 全部报 "SetNamedSecurityInfoW failed (Win32 5)"，命令行能力归零。
icacls $proj /grant "${AgentUser}:(OI)(CI)F" /t /c | Out-Null
if ($LASTEXITCODE -ne 0) { throw "授权失败：$proj" }
Write-Host "$proj 已授权给 $AgentUser（完全控制，递归，大目录会慢）"

if ($DenySensitive) {
    foreach ($p in @((Join-Path $env:USERPROFILE '.dsh'), (Join-Path $env:USERPROFILE '.ssh'))) {
        if (Test-Path -LiteralPath $p) {
            icacls $p /deny "${AgentUser}:(OI)(CI)F" | Out-Null
            Write-Host "已拒绝 $AgentUser 访问 $p"
        }
    }
}

Write-Host ''
Write-Host '接下来：'
Write-Host "  .\verify-isolation.ps1 -ProjectPath `"$proj`""
Write-Host '  .\start-agent-dsh.ps1'
