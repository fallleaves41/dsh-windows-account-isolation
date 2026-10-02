# 用隔离账户跑 DSH Web。setup-agent-account.ps1 会把这个文件复制到 C:\dsh-agent\。
param(
    [string]$Profile = 'web',
    [string]$WorkDir,
    [string]$DshVersion = '0.1.7-rc.2',
    [string]$TrustedHost
)

$root = $PSScriptRoot
if (-not $root -and $MyInvocation.MyCommand.Path) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $root) { $root = (Get-Location).Path }
if (-not $WorkDir) { $WorkDir = Join-Path $root 'work' }

$env:DSH_HOME = Join-Path $root 'home'
$env:Path = "$env:APPDATA\npm;$env:Path"

$log = Join-Path $root 'log\dsh-web.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log), $WorkDir | Out-Null

function Say($msg) {
    $line = "$(Get-Date -Format 'HH:mm:ss')  $msg"
    Write-Host $line
    Add-Content -LiteralPath $log -Value $line
}

# 会话分隔标记（纯 ASCII，不受编码影响）。start-agent-dsh.ps1 靠它区分
# "这次的 URL"和"上一次留在日志里的 URL"——日志删不掉时也不会认错。
Say '===== session start ====='

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw '找不到 node，先装系统级 Node.js。'
}

# 新账户里没有 pnpm 和 dsh，第一次跑的时候装上。
# 版本必须和 profile 里的插件对得上：装最新版会让插件因 peerDependencies 不匹配被整体跳过
# （实测装 0.2.0-rc.2 时，dshmarket / vision-router / better-sidebar / mnemon 等全被 skip）。
$dshPkg = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh\package.json'
$have = ''
if (Test-Path -LiteralPath $dshPkg) {
    try { $have = (Get-Content -Raw -LiteralPath $dshPkg | ConvertFrom-Json).version } catch { }
}

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue) -or $have -ne $DshVersion) {
    $shown = if ($have) { $have } else { '未安装' }
    Say "安装 pnpm 和 dsh CLI $DshVersion（当前：$shown）"
    npm install -g pnpm "@deepseek-ai/dsh@$DshVersion" 2>&1 | ForEach-Object { Say $_ }
}

# 只同步要启动的那个 profile。DSH_HOME 里可能还躺着别的 profile 或备份副本，
# 全装一遍要几十分钟，没必要。
# 注意：装依赖时 ssh2 会报 "gyp ERR! find Python ... Failed to build optional crypto binding"，
# 那是可选的原生绑定，机器上没有 Python 就跳过，回退纯 JS，不影响使用。
$profileDir = Join-Path $env:DSH_HOME "profiles\$Profile"
if (Test-Path -LiteralPath (Join-Path $profileDir 'package.json')) {
    Say "同步 profile $Profile 的依赖"
    Push-Location $profileDir
    try { pnpm install 2>&1 | ForEach-Object { Say $_ } }
    finally { Pop-Location }
}

Set-Location -LiteralPath $WorkDir

# --trusted-host：把 Tailscale 地址加进 web 的信任名单。
# 不加的话，手机那种"非回环 Host"的请求能拿到静态页面，但 /api 与 WebSocket 会被拒
# （表现为界面一直"重新连接中"、工作区列表空、插件 API 失败）。
$dshArgs = @('--profile', $Profile)
if ($TrustedHost) { $dshArgs += @('--trusted-host', $TrustedHost) }
Say "启动 dsh $($dshArgs -join ' ')（DSH_HOME=$env:DSH_HOME）"
& dsh @dshArgs 2>&1 | ForEach-Object { Say $_ }
