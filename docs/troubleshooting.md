# 已知问题

都是实际撞出来的，按遇到的可能性排。

## 脚本跑不起来，报"未对文件进行数字签名"

Windows 默认禁止运行本地 `.ps1`。用 `.cmd` 入口（内部走 scriptblock，不受执行策略限制），
或者在当前用户下放开一次：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 脚本中文乱码、报解析错误

`.ps1` 里有中文时必须存成 UTF-8 **带 BOM**。没有 BOM 时 PowerShell 5.1 按 GBK 解码，
乱码可能吃掉字符串的引号，直接让文件解析失败。

同一个坑换到 JSON 上：读别人的 UTF-8 文件要显式指定编码，写回去用 .NET。

```powershell
$text = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($f, $json, (New-Object Text.UTF8Encoding($false)))
```

`Set-Content -Encoding UTF8` 在 5.1 下会加 BOM，JSON 可能因此解析失败。

## start 报"目录名称无效"

`Start-Process -Credential` 需要显式给 `-WorkingDirectory`。不给的话它拿当前目录创建进程，
而当前目录在你自己的用户目录下、隔离账户无权访问。脚本已经处理，自己写类似脚本时注意。

## 验证报 FAIL，但路径明明是对的

`Test-Path` 在权限被拒时也返回 `False`，会把"被拒绝"误判成"不存在"。要区分这两种情况只能看异常类型。
`verify-isolation.ps1` 用的是这个办法。

## 计划任务起不来，错误码 0x80070569

用密码登录类型注册的计划任务要求账户有"作为批处理作业登录"权限，标准用户默认没有。
本项目改用 `Start-Process -Credential` 启动，不碰计划任务。

## 命令行工具全部失败：`SetNamedSecurityInfoW failed (Win32 5)`

工作区目录的权限给少了。DSH 的 Windows ACL 沙箱每执行一条命令都要往工作区目录写 ACL
（加能力 SID 的允许 ACE、加 Low 完整性标签），需要 `WRITE_DAC`，而"修改(M)"不含这个权利。
给"完全控制(F)"：

```powershell
icacls 'C:\work\myproj' /grant 'dsh-agent:(OI)(CI)F' /t /c
```

注意此时**文件工具是正常的**，只有命令行和 run_code 挂，容易误判成模型的问题。

## 启动日志里一堆 `skipping profile bundle`

CLI 版本和 profile 里的插件对不上。DSH 遇到 peerDependencies 不匹配会跳过整包，插件等于全废。
把 `run-dsh-web.ps1` 的 `-DshVersion` 改成和插件对应的版本，或者把插件一起升级。

## 从别的设备访问，页面一直"重新连接中"

`dsh web` 的 `/api/*` 和 WebSocket 要求 Host 命中信任名单，而绑 `127.0.0.1` 时不会派生任何 LAN 地址，
所以远程访问只有静态页面能用。启动时用 `--trusted-host` 加上那个地址
（`start-agent-dsh.ps1` 会自动带上 Tailscale 地址）。

## 远程端改设置报 403

一批插件（`@linxin666/*`、`dsh-whale-widget` 等）在自己的路由上又查了一次 Host，只认回环地址，
连宿主的 `--trusted-host` 也不认。这是它们的安全设计：远程能干活，不能改配置和凭据。
改设置回本机操作。

## patch 加了 `disabled: true` 却没有任何效果

行 id 写错了。DSH 对不存在的行 id 不报错，只是静默不生效。行 id 在 `设置 → 内置插件`
的卡片标题上；`dsh-web-all` 插入的行都带 `web-ui-` 前缀，例如 `web-ui-task-board`、`web-ui-pet`。

## 装完插件前端卡死在"加载插件……"

插件的 `dsh.engines` 只是安装期检查，过了不代表运行时兼容。
实测 `dsh-ui-mobile@0.1.8` 能装在 0.1.7-rc.2 上，装完界面直接卡住。
界面点不了也能回滚——把该包从 profile 的 `package.json` 里 `dsh.profile.bundles` 摘掉，重启：

```powershell
$p = 'C:\dsh-agent\home\profiles\web\package.json'
$j = Get-Content $p -Raw | ConvertFrom-Json
$j.dsh.profile.bundles = @($j.dsh.profile.bundles | Where-Object { $_ -ne 'dsh-ui-mobile' })
[IO.File]::WriteAllText($p, ($j | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
```

## 工作区里"新建文件夹"报 EPERM，点旧工作区报找不到会话

工作区清单是从原账户复制过来的，里面是原账户的目录，隔离账户访问不到。
用 `reset-workspaces.cmd <项目目录>` 重写。
