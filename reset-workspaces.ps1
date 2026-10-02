# 把隔离实例的工作区清单重置成只含指定目录（默认 C:\work\myproj）。
# 那份清单是从你主账户复制过来的，里面全是你真实的目录，隔离账户访问不到；
# 结果是"新建文件夹"报 EPERM、点开旧工作区报找不到会话。
# 跑之前先 .\stop.cmd 把服务停掉。
#
# 编码注意：这个文件是 UTF-8【无 BOM】且含中文路径。
# Windows PowerShell 5.1 的 Get-Content 默认按 GBK 读，会把中文读坏、吞掉引号，JSON 直接解析失败；
# 所以读要显式 UTF8，写要用 .NET 写「无 BOM 的 UTF-8」（5.1 的 Set-Content -Encoding UTF8 会加 BOM）。
param(
    [string]$Path = 'C:\work\myproj',
    [string]$Root = 'C:\dsh-agent',
    [int]$Port = 3080
)

$ErrorActionPreference = 'Stop'

$file = Join-Path $Root 'home\storages\workspace.json'
if (-not (Test-Path -LiteralPath $file)) { throw "找不到 $file，先跑 setup-agent-account.ps1。" }
if (-not (Test-Path -LiteralPath $Path)) { throw "目录不存在：$Path" }

# 服务在跑的时候改这个文件不会生效，还可能被它覆盖回去
$running = $false
try {
    $running = (Test-NetConnection -ComputerName '127.0.0.1' -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
}
catch { }
if ($running) {
    Write-Host "警告：127.0.0.1:$Port 正在监听，dsh 还在运行。请先 .\stop.cmd。" -ForegroundColor Yellow
    if ((Read-Host '仍要继续？(y/N)') -ne 'y') { return }
}

$backup = "$file.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item -LiteralPath $file -Destination $backup -Force
Write-Host "已备份：$backup"

$utf8 = New-Object Text.UTF8Encoding($false)

# 读：显式 UTF-8（不能用 Get-Content -Raw，5.1 下会按 GBK 解码）
$j = ([IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)) | ConvertFrom-Json

$newId = [guid]::NewGuid().ToString()
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

# 拿现有条目当字段模板（JSON 往返克隆），保证字段集合和原来完全一致
$proto = ($j.tables.workspaces.PSObject.Properties | Select-Object -First 1).Value
$tpl = $proto | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$tpl.path = (Resolve-Path -LiteralPath $Path).Path
$tpl.title = Split-Path -Leaf $Path
$tpl.sessionIds = @()
$tpl.createdAt = $now
$tpl.updatedAt = $now

$ws = New-Object psobject
$ws | Add-Member -NotePropertyName $newId -NotePropertyValue $tpl

$j.tables.workspaces = $ws
$j.global.workspaceIds = @($newId)
$j.global.archivedSessionIds = @()
$j.global.pinnedSessionIds = @()

# 写：无 BOM 的 UTF-8（保持和原文件一致）
$json = $j | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($file, $json, $utf8)

# 读回来校验
$k = ([IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$n = @($k.tables.workspaces.PSObject.Properties).Count
Write-Host "完成，现在只剩 $n 个工作区："
$k.tables.workspaces.PSObject.Properties | ForEach-Object { Write-Host ("  " + $_.Value.path) }
