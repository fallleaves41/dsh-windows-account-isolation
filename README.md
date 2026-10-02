# dsh-windows-account-isolation

在 Windows 上把 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 放到一个独立的本地账户里运行，
让它只能访问你指定的项目目录。

## 为什么

DSH 默认以你本人的账户运行：能读写你的所有文件、执行命令、读取 `~/.dsh` 里的凭据。
这个项目不依赖 DSH 自身的沙箱与审批策略划边界，而是用 Windows 的账户和 NTFS 权限：
DSH 进程属于 `dsh-agent`，只对自己目录和授权目录有访问权。

## 要求

- Windows 10 / 11，管理员权限（建账户、改 ACL）
- 系统级 Node.js（隔离账户也要用）
- PowerShell 5.1 或 7

项目目录不要放在 OneDrive 里 —— 云占位文件在别的账户下经常读不出内容。

## 快速开始

```powershell
# 1. 建账户、迁配置、授权（管理员，会弹 UAC）
.\setup.cmd C:\work\myproj

# 2. 验证边界真的生效
.\verify.cmd C:\work\myproj

# 3. 启动（第一次会给新账户装 pnpm 和 dsh CLI，几分钟）
.\start.cmd C:\work\myproj
```

`start` 结束后会打印一行 `dsh web: http://127.0.0.1:3080/?token=...`，用浏览器打开。
token 是一次性的，重启换一个。

也可以直接跑 `.ps1`：

```powershell
.\setup-agent-account.ps1 -ProjectPath 'C:\work\myproj' -DenySensitive
.\verify-isolation.ps1 -ProjectPath 'C:\work\myproj'
.\start-agent-dsh.ps1 -WorkDir 'C:\work\myproj'
```

## 命令

| 命令 | 说明 |
| --- | --- |
| `setup.cmd <项目目录>` | 建账户、迁 `~/.dsh`、授权（管理员） |
| `verify.cmd <项目目录>` | 用隔离账户去读敏感路径，读得到就报 FAIL |
| `start.cmd [工作目录]` | 启动 DSH Web（默认 `C:\dsh-agent\work`） |
| `stop.cmd` | 结束隔离账户的进程（管理员） |
| `reset-workspaces.cmd <项目目录>` | 把工作区清单重写成只含该目录（先 stop） |
| `phone-url.cmd` | 打印手机可用的地址 |

`.cmd` 入口是给 PowerShell 5.1 准备的：内部用 scriptblock 执行脚本内容，绕过执行策略限制。
直接跑 `.ps1` 报"未对文件进行数字签名"时，可以 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`。

## 验证

`verify-isolation.ps1` 会用隔离账户的凭据真去读一遍敏感路径，判定看异常类型而不是 `Test-Path`。
输出三种状态：

```
DENIED:UnauthorizedAccessException   被拒（期望结果）
READABLE                             读到了；出现在敏感路径上就是 FAIL
MISSING                              路径不存在，记为 SKIP
```

`~/.dsh/.credentials.yaml` 那一行额外做读内容测试。

## 配置

`setup-agent-account.ps1`

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-ProjectPath` | 必填 | 授权目录，需已存在 |
| `-AgentUser` | `dsh-agent` | 账户名 |
| `-Root` | `C:\dsh-agent` | 隔离账户的 DSH_HOME、日志、工作目录 |
| `-DenySensitive` | 关 | 对 `~/.dsh`、`~/.ssh` 加显式拒绝 ACE |
| `-NoMigrate` | 关 | 不复制现有 `~/.dsh` |

`run-dsh-web.ps1`（setup 会把它复制到 `C:\dsh-agent\`）

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-DshVersion` | `0.1.7-rc.2` | 安装的 CLI 版本，要和 profile 里的插件对得上 |

## 文件

```
setup-agent-account.ps1 / .cmd     建账户、迁配置、授权
verify-isolation.ps1    / .cmd     验证边界
start-agent-dsh.ps1     / .cmd     启动
stop-agent-dsh.ps1      / .cmd     停止
reset-workspaces.ps1    / .cmd     重置工作区清单
phone-url.ps1           / .cmd     打印手机地址
run-dsh-web.ps1                    运行脚本（被复制到 C:\dsh-agent）
```

## 更多文档

- [docs/remote-tailscale.md](docs/remote-tailscale.md) —— 用手机远程访问
- [docs/troubleshooting.md](docs/troubleshooting.md) —— 已知问题
- [docs/publishing.md](docs/publishing.md) —— 改完想发到 GitHub

## 局限

- 对 `Users` / `Authenticated Users` 开放的其他目录（`C:\Users\Public`、其他数据盘）隔离账户照样能读，
  这个方案管的是你的用户目录和凭据，不是全封闭。
- 迁移会带上 `~/.dsh/.credentials.yaml` 的副本；想彻底分开就给隔离账户单独配一把限额 API Key。
- 项目目录的授权是递归的，目录大时较慢。
- 依赖宿主 GUI 的插件（如 computer-use）在隔离账户里用不了。

## 卸载

```powershell
.\stop.cmd
Remove-LocalUser -Name 'dsh-agent'
Remove-Item -Recurse -Force 'C:\dsh-agent'
icacls 'C:\work\myproj' /remove:g 'dsh-agent' /t /c
```

## 许可

MIT
