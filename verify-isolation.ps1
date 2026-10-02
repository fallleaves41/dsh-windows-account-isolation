# 检查隔离是否真的生效：用隔离账户的身份去读你的敏感目录，应该全部被拒。
param(
    [string]$AgentUser = 'dsh-agent',
    [string]$Root = 'C:\dsh-agent',
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'

$denyList = @()
foreach ($p in @(
        (Join-Path $env:USERPROFILE '.dsh\.credentials.yaml'),
        (Join-Path $env:USERPROFILE '.dsh'),
        (Join-Path $env:USERPROFILE '.ssh'),
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:USERPROFILE 'OneDrive'),
        (Join-Path $env:USERPROFILE 'AppData\Roaming\Mozilla'),
        (Join-Path $env:USERPROFILE 'AppData\Local\Google')
    )) {
    if (Test-Path -LiteralPath $p) { $denyList += $p }
}

$allowList = @($Root, (Join-Path $Root 'home'))
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $allowList += (Resolve-Path -LiteralPath $ProjectPath).Path
}

if ($denyList.Count -eq 0) { throw '没找到要检查的敏感路径。' }

$probeDir = Join-Path $Root 'verify'
New-Item -ItemType Directory -Force -Path $probeDir | Out-Null
$probeFile = Join-Path $probeDir 'probe.ps1'
$resultFile = Join-Path $probeDir 'result.json'

# 探针用隔离账户的凭据启动，它读得到什么就是隔离账户读得到什么。
# 判定必须靠异常类型：Test-Path 在"拒绝访问"时同样返回 False，会把拒绝误判成"不存在"。
$probe = @'
param([string]$ResultFile, [string]$DenyList, [string]$AllowList)

function Try-Read([string]$path) {
    try {
        $null = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        return 'READABLE'
    }
    catch {
        $t = $_.Exception.GetType().Name
        if ($t -like '*ItemNotFound*') { return 'MISSING' }
        return "DENIED:$t"
    }
}

function Try-Content([string]$path) {
    try {
        $null = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        return 'READABLE'
    }
    catch {
        return "DENIED:$($_.Exception.GetType().Name)"
    }
}

$rows = New-Object System.Collections.ArrayList
foreach ($p in ($DenyList -split '\|' | Where-Object { $_ })) {
    $actual = if ($p -like '*.credentials.yaml') { Try-Content $p } else { Try-Read $p }
    [void]$rows.Add([pscustomobject]@{ path = $p; expect = 'DENIED'; actual = $actual })
}
foreach ($p in ($AllowList -split '\|' | Where-Object { $_ })) {
    [void]$rows.Add([pscustomobject]@{ path = $p; expect = 'OK'; actual = (Try-Read $p) })
}
$rows | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ResultFile -Encoding UTF8
'@

Set-Content -LiteralPath $probeFile -Value $probe -Encoding UTF8
if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force }

$cred = Get-Credential -UserName "$env:COMPUTERNAME\$AgentUser" -Message "验证用，输入 $AgentUser 的密码"
if (-not $cred) { throw "没有拿到凭据（凭据框被取消了）。重新跑一次，输入 $AgentUser 的密码。" }
$procArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$probeFile`"",
    '-ResultFile', "`"$resultFile`"",
    '-DenyList', "`"$($denyList -join '|')`"",
    '-AllowList', "`"$($allowList -join '|')`""
)

# -Credential 需要显式给一个「目标账户能访问」的工作目录，
# 否则会拿当前目录（在你自己的用户目录下，dsh-agent 无权访问）去创建进程，报"目录名称无效"。
$workDir = if (Test-Path -LiteralPath $Root) { $Root } else { $env:SystemRoot }
Start-Process -FilePath 'powershell.exe' -Credential $cred -ArgumentList $procArgs -WorkingDirectory $workDir -Wait

if (-not (Test-Path -LiteralPath $resultFile)) {
    throw "探针没写出结果，手动用 $AgentUser 跑一次：$probeFile"
}

$rows = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
$bad = 0
$skip = 0
foreach ($r in $rows) {
    $actual = [string]$r.actual
    $tag = 'FAIL'
    $color = 'Red'

    if ($r.expect -eq 'OK') {
        if ($actual -eq 'READABLE') { $tag = 'PASS'; $color = 'Green' }
    }
    elseif ($actual -eq 'READABLE') {
        $tag = 'FAIL'
        $color = 'Red'
    }
    elseif ($actual -eq 'MISSING') {
        $tag = 'SKIP'
        $color = 'Yellow'
    }
    else {
        $tag = 'PASS'
        $color = 'Green'
    }

    if ($tag -eq 'FAIL') { $bad++ }
    if ($tag -eq 'SKIP') { $skip++ }
    Write-Host ('{0}  {1,-8} {2,-42} {3}' -f $tag, $r.expect, $actual, $r.path) -ForegroundColor $color
}

Write-Host ''
if ($bad -eq 0) {
    Write-Host "$AgentUser 读不到上面这些路径，自己的目录正常。"
}
else {
    Write-Host "有 $bad 条不该读到的却读到了，看标 FAIL 的行。"
}
if ($skip -gt 0) {
    Write-Host "$skip 条是 SKIP：那些路径在本机不存在，证明不了什么，不算通过也不算失败。" -ForegroundColor Yellow
}
