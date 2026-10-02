# 手机远程访问（Tailscale）

目标是在外面用手机操作这台电脑上的 DSH，同时不开公网入口。

## 思路

`dsh web` 只能绑回环地址（官方不允许绑 `0.0.0.0`），所以需要有东西把手机的请求送进
`127.0.0.1:3080`。用 Tailscale 组一个只有自己设备能进的私有网，再在本机加一条端口转发就够了：
不经过公网中继，也不用折腾 HTTPS 证书（Tailscale 本身就是 WireGuard 隧道）。

```
手机 ──Tailscale──> PC(100.x.y.z:3080) ──portproxy──> 127.0.0.1:3080 ──> dsh web
```

## 步骤

**1. 两台设备装 Tailscale，登同一个账号**

下载：<https://tailscale.com/download>。PC 的地址这样看（CLI 走受保护管道，需要管理员）：

```powershell
& 'C:\Program Files\Tailscale\tailscale.exe' ip -4
& 'C:\Program Files\Tailscale\tailscale.exe' status    # 确认两台都在线
```

**2. PC 上把 3080 转发给 tailnet**（管理员）

```powershell
netsh interface portproxy add v4tov4 listenaddress=100.x.y.z listenport=3080 connectaddress=127.0.0.1 connectport=3080

New-NetFirewallRule -DisplayName 'DSH 3080 via Tailscale' -Direction Inbound -Action Allow `
  -Protocol TCP -LocalPort 3080 -RemoteAddress 100.64.0.0/10
```

`listenaddress` 只绑 Tailscale 那个地址，不要写 `0.0.0.0`；防火墙也只放行 Tailscale 网段
（`100.64.0.0/10`）。

**3. 启动并取地址**

```powershell
.\start.cmd C:\work\myproj    # 脚本会自动把 Tailscale 地址加进 --trusted-host
.\phone-url.cmd               # 打印手机要打开的地址
```

**4. 手机上打开**

第一次要带 token 的完整地址，加载后 token 换成 cookie，只要实例不重启就一直有效。
建议在浏览器里"添加到主屏幕"。

## 能做什么

| 操作 | 手机 | 本机 |
| --- | --- | --- |
| 聊天、跑任务、读写工作区文件、执行命令 | ✅ | ✅ |
| 改设置、插件管理、使用统计、写凭据 | ❌ 403 | ✅ |

那个 403 是插件自己的规矩（只认回环地址），不是配置错了，详见
[troubleshooting.md](troubleshooting.md#远程端改设置报-403)。

## 安全

搭好之后是四层：Tailscale 私有网（设备级身份）→ 防火墙只放行 `100.64.0.0/10` →
DSH 的 token 认证 → dsh-agent 账户隔离。

不用的时候 `stop.cmd` 加上手机关掉 Tailscale，暴露窗口就是 0。不要把 tailnet 分享给别人，
手机也别 Root 后乱装东西。

## 撤销

```powershell
netsh interface portproxy delete v4tov4 listenaddress=100.x.y.z listenport=3080
Remove-NetFirewallRule -DisplayName 'DSH 3080 via Tailscale'
```
