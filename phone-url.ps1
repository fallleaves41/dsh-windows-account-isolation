# 打印「手机可用的地址」：把日志里最新的 token 套上 Tailscale IP。
# 手机端每次重开实例后都要取一次新 token（只要你用带 token 的地址打开过，cookie 会留在手机上）。
param(
    [string]$TailscaleIp,
    [string]$Root = 'C:\dsh-agent'
)

$ErrorActionPreference = 'Stop'

# 1) Tailscale IP：优先用参数，其次从 portproxy 规则里读（跑过 phone-setup 就有）
if (-not $TailscaleIp) {
    $row = netsh interface portproxy show v4tov4 2>$null | Select-String '3080' | Select-Object -First 1
    if ($row) { $TailscaleIp = ($row.Line.Trim() -split '\s+')[0] }
}
if (-not $TailscaleIp) {
    throw '拿不到 Tailscale IP：加 -TailscaleIp 100.x.y.z，或先按 README 配好 portproxy 转发。'
}

# 2) 实例在跑吗（3080 有没有监听）
$listening = [bool](netstat -ano | Select-String ':3080\s+.*LISTENING')
if (-not $listening) {
    Write-Host '注意：3080 没有在监听，实例可能是停的 —— 先跑 start.cmd 再取地址。' -ForegroundColor Yellow
}

# 3) 从日志里取最新一行的 token
$log = Join-Path $Root 'log\dsh-web.log'
if (-not (Test-Path -LiteralPath $log)) { throw "找不到 $log，先跑 start.cmd。" }

$hit = Get-Content -LiteralPath $log -ErrorAction Stop |
    Where-Object { $_ -match 'dsh web: http' } |
    Select-Object -Last 1
if (-not $hit) { throw '日志里没有 dsh web: 行，实例可能还没起来。' }

$token = ($hit -split 'token=')[-1].Trim()

Write-Host ''
Write-Host '手机浏览器打开这个地址（首次用带 token 的，之后 cookie 会记住）：' -ForegroundColor Green
Write-Host ("  http://{0}:3080/?token={1}" -f $TailscaleIp, $token) -ForegroundColor Green
Write-Host ''
Write-Host '建议在手机上「添加到主屏幕」，下次一键进。'
