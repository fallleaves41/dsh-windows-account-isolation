# 用隔离账户启动 DSH Web：以 dsh-agent 的身份跑 run-dsh-web.ps1，然后从日志里取 URL。
# 这里不用计划任务：标准用户默认没有「作为批处理作业登录」权限，任务会起不来（0x80070569）。
param(
    [string]$AgentUser = 'dsh-agent',
    [string]$Root = 'C:\dsh-agent',
    [string]$Profile = 'web',
    [string]$WorkDir,
    [int]$TimeoutSec = 180,
    [string]$TrustedHost
)

$ErrorActionPreference = 'Stop'

# 没显式给 TrustedHost 就自动找 Tailscale 地址（100.64.0.0/10 网段）。
# 它会被当作 --trusted-host 传给 dsh web，让手机的 /api 与 WebSocket 请求通过信任栅栏；
# 不给的话手机能打开页面但界面会一直"重新连接中"。
if (-not $TrustedHost) {
    $TrustedHost = (ipconfig 2>$null |
        Select-String -Pattern '(100\.\d{1,3}\.\d{1,3}\.\d{1,3})' |
        ForEach-Object { $_.Matches[0].Groups[1].Value } |
        Select-Object -First 1)
}

$runner = Join-Path $Root 'run-dsh-web.ps1'

# 每次都把同目录下的 runner 同步过去，避免改了仓库里的脚本但 C:\dsh-agent 里还是旧的。
$here = $PSScriptRoot
if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $here) { $here = (Get-Location).Path }
$localRunner = Join-Path $here 'run-dsh-web.ps1'
if (Test-Path -LiteralPath $localRunner) { Copy-Item -LiteralPath $localRunner -Destination $runner -Force }

if (-not (Test-Path -LiteralPath $runner)) {
    throw "找不到 $runner，先跑 setup-agent-account.ps1。"
}

if (-not $WorkDir) { $WorkDir = Join-Path $Root 'work' }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$cred = Get-Credential -UserName "$env:COMPUTERNAME\$AgentUser" -Message "以 $AgentUser 身份启动 DSH"
if (-not $cred) { throw "没有拿到凭据（凭据框被取消了）。重新跑一次，输入 $AgentUser 的密码。" }

# 清日志放在拿到凭据之后：取消凭据框不该把上一次的日志删掉（里面有正在跑的实例的地址）。
$log = Join-Path $Root 'log\dsh-web.log'
if (Test-Path -LiteralPath $log) {
    try { Remove-Item -LiteralPath $log -Force -ErrorAction Stop } catch { }
}
$procArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$runner`"",
    '-Profile', $Profile,
    '-WorkDir', "`"$WorkDir`""
)
if ($TrustedHost) {
    $procArgs += @('-TrustedHost', $TrustedHost)
    Write-Host "已把 $TrustedHost 加入 web 信任名单（--trusted-host）"
}
else {
    Write-Host '没找到 Tailscale 地址，手机可能连得上但界面会一直"重新连接中"（用 -TrustedHost 手动指定）' -ForegroundColor Yellow
}

# 工作目录必须给成 dsh-agent 有权访问的路径，否则报"目录名称无效"。
Start-Process -FilePath 'powershell.exe' -Credential $cred -ArgumentList $procArgs -WorkingDirectory $Root
Write-Host "已启动，等 dsh web 打印 URL（第一次要装依赖，可能要几分钟）..."

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$url = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    if (-not (Test-Path -LiteralPath $log)) { continue }

    # 只看本次会话的输出：最后一个 session 标记之后才可能出现这次的 URL。
    $lines = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
    $mark = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match 'session start') { $mark = $i; break }
    }
    if ($mark -lt 0) { continue }

    for ($i = $mark + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'dsh web:\s*(\S+)') { $url = $Matches[0].Trim(); break }
    }
    if ($url) { break }
}

if ($url) {
    Write-Host ''
    Write-Host $url -ForegroundColor Green
    Write-Host '在浏览器里打开它。关掉服务用 .\stop.cmd'
}
else {
    Write-Host "没等到 URL，日志在 $log："
    if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 30 }
}
