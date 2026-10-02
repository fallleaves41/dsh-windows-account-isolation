# 发布到 GitHub

面向没发过仓库的人。从零到推上去大概二十分钟。命令都在 Windows PowerShell 里跑。

## 准备

需要 GitHub 账号，以及本机的 Git（`git --version` 有输出就行）。

一次性的身份配置，一台机器配一次：

```powershell
git config --global user.name "你的名字或ID"
git config --global user.email "你的邮箱"
git config --global init.defaultBranch main
git config --global core.autocrlf true
git config --global core.quotepath false
```

后两条是给 Windows 准备的：一条处理行尾，一条让中文文件名不乱码。不想暴露真实邮箱的话，
GitHub 的 Settings → Emails 里有一个 `xxxxx@users.noreply.github.com` 形式的地址，用它。

## 建空仓库

GitHub 右上角 `+` → New repository，起名，选 Public。

**那三个勾（Add a README / .gitignore / license）都不要勾** —— 本地都有，勾了推送前还要多一次合并。

## 推上去

```powershell
git init
git add .
git status
```

`git status` 别跳，确认列出来的都是该提交的文件。

```powershell
git commit -m "初始提交"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

首次推送会弹登录窗口，选浏览器登录。

PowerShell 5.1 不支持 `&&`，命令一行一条。

### 如果让你输密码

GitHub 不收账号密码，"密码"那栏填 **PAT**：Settings → Developer settings →
Personal access tokens → Fine-grained tokens → Generate new token，仓库权限里把 **Contents**
设为 Read and write，生成后立刻复制（只显示一次）。用户名填 GitHub 用户名。

token 等于密码，别贴聊天里，也别写进文件。

### 不想敲命令

装 GitHub Desktop，`File → Add local repository` 选这个目录，提示不是仓库就点 create a repository，
然后填 Summary → Commit to main → Publish repository。Publish 对话框里记得**取消勾选**
Keep this code private。

## 更新

```powershell
git add .
git commit -m "说明改了什么"
git push
```

## 发之前扫一遍

```powershell
Get-ChildItem -File -Recurse |
  Select-String -Pattern 'sk-[A-Za-z0-9]{16,}','api[_-]?key\s*[:=]','password\s*[:=]','PRIVATE KEY'
```

没输出就是干净的。真提交了密钥：**先轮换密钥**（比清历史重要），再决定删仓库重建还是清历史。
还没 push 的话，`git rm --cached 文件`、改 `.gitignore`、重新提交即可。

## 常见问题

`git push` 卡住或 `Connection reset` —— 网络问题。有代理就
`git config --global http.proxy http://127.0.0.1:端口`，或者用 GitHub Desktop 走系统代理。

`Support for password authentication was removed` —— 用 PAT。

`file is 97.5 MB; exceeds GitHub's file size limit` —— 大文件被加进来了，
`git rm --cached` 掉并写进 `.gitignore`。

中文文件名显示成 `\346\226\207` —— `git config --global core.quotepath false`。

满屏 `LF will be replaced by CRLF` —— 警告而已，忽略。
