# dsh-windows-account-isolation

[![release](https://img.shields.io/github/v/release/fallleaves41/dsh-windows-account-isolation?color=blue)](https://github.com/fallleaves41/dsh-windows-account-isolation/releases)

Run [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) in a dedicated local Windows account,
so it can only touch the project directory you allow.

[中文](README.md) | English

## Why

DSH normally runs as your own user: it can read and write every file you own, run commands, and read the
credentials in `~/.dsh`. This project draws the boundary with Windows accounts and NTFS permissions instead
of relying on DSH's own sandbox and approval policy. The DSH process belongs to `dsh-agent`, which only has
access to its own directory plus the directories you grant it.

That matters because sandbox and approval checks are policy, not privilege: a web terminal, PTC execution or
a plugin with host-level access can go around them. An account boundary cannot be argued with.

## Requirements

- Windows 10 / 11 with administrator rights (to create the account and change ACLs)
- A system-wide Node.js install — the isolated account uses it too
- PowerShell 5.1 or 7

Keep the project directory out of OneDrive: cloud placeholder files are often unreadable from another account.

## Quick start

```powershell
# 1. create the account, copy the config, grant access (admin, triggers UAC)
.\setup.cmd C:\work\myproj

# 2. check that the boundary actually holds
.\verify.cmd C:\work\myproj

# 3. start (first run installs pnpm and the dsh CLI for the new account, takes a few minutes)
.\start.cmd C:\work\myproj
```

`start` prints a line like `dsh web: http://127.0.0.1:3080/?token=...` — open it in your own browser.
The token is single-use and a new one is issued on every restart.

The `.ps1` scripts work directly as well:

```powershell
.\setup-agent-account.ps1 -ProjectPath 'C:\work\myproj' -DenySensitive
.\verify-isolation.ps1 -ProjectPath 'C:\work\myproj'
.\start-agent-dsh.ps1 -WorkDir 'C:\work\myproj'
```

## Commands

| Command | What it does |
| --- | --- |
| `setup.cmd <project>` | create the account, migrate `~/.dsh`, grant access (admin) |
| `verify.cmd <project>` | read the sensitive paths as the isolated account; anything readable is reported as FAIL |
| `start.cmd [workdir]` | start DSH Web (defaults to `C:\dsh-agent\work`) |
| `stop.cmd` | kill the isolated account's processes (admin) |
| `reset-workspaces.cmd <project>` | rewrite the workspace list to contain only that directory (stop first) |
| `phone-url.cmd` | print the URL to open on a phone |

The `.cmd` entry points exist for Windows PowerShell 5.1: they run the script body through
`[scriptblock]::Create`, which sidesteps the execution policy. If you run a `.ps1` directly and get
"not digitally signed", either use the `.cmd` or run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Verification

`verify-isolation.ps1` does not inspect configuration. It generates a probe script and runs it with the
isolated account's credentials, so whatever it can read is what that account can read. The verdict comes
from the exception type rather than `Test-Path` (`Test-Path` returns False on access-denied too, which
would misreport a denial as "missing").

```
DENIED:UnauthorizedAccessException   refused — what you want
READABLE                             readable; a failure on a sensitive path
MISSING                              the path does not exist; counted as SKIP
```

The `~/.dsh/.credentials.yaml` row additionally tries to read the file contents.

## Configuration

`setup-agent-account.ps1`

| Parameter | Default | Meaning |
| --- | --- | --- |
| `-ProjectPath` | required | directory to grant; must already exist |
| `-AgentUser` | `dsh-agent` | account name |
| `-Root` | `C:\dsh-agent` | the isolated account's DSH_HOME, logs and work directory |
| `-DenySensitive` | off | add explicit deny ACEs on `~/.dsh` and `~/.ssh` |
| `-NoMigrate` | off | do not copy the existing `~/.dsh` |

`run-dsh-web.ps1` (copied into `C:\dsh-agent\` by setup)

| Parameter | Default | Meaning |
| --- | --- | --- |
| `-DshVersion` | `0.1.7-rc.2` | CLI version to install; must match the plugins in the profile |

## Layout

```
setup-agent-account.ps1 / .cmd     create account, migrate config, grant access
verify-isolation.ps1    / .cmd     verify the boundary
start-agent-dsh.ps1     / .cmd     start
stop-agent-dsh.ps1      / .cmd     stop
reset-workspaces.ps1    / .cmd     rewrite the workspace list
phone-url.ps1           / .cmd     print the phone URL
run-dsh-web.ps1                    the runner copied into C:\dsh-agent
```

## Docs

- [docs/remote-tailscale.md](docs/remote-tailscale.md) — remote access from a phone (Tailscale)
- [docs/troubleshooting.md](docs/troubleshooting.md) — known issues
- [docs/publishing.md](docs/publishing.md) — publishing to GitHub

The docs are currently Chinese only.

## Limitations

- Directories open to `Users` / `Authenticated Users` (`C:\Users\Public`, other data drives) remain readable
  by the isolated account. This project protects your user profile and credentials, not the whole machine.
- The migration copies `~/.dsh/.credentials.yaml`. For a clean separation, give the isolated account its own
  rate-limited API key.
- Granting the project directory is recursive, so it is slow on large trees.
- Plugins that depend on the host GUI (computer-use, for example) do not work inside the isolated account.

## Uninstall

```powershell
.\stop.cmd
Remove-LocalUser -Name 'dsh-agent'
Remove-Item -Recurse -Force 'C:\dsh-agent'
icacls 'C:\work\myproj' /remove:g 'dsh-agent' /t /c
```

## License

MIT
