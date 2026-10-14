---
name: obsidian-setup
description: 安装 Obsidian 笔记软件。当用户说"装 Obsidian""安装 Obsidian""帮我装一个笔记软件""Obsidian 怎么装"时使用。支持 Windows 和 macOS，多源下载（GitHub 代理加速），已安装则自动跳过。
---

# Obsidian 安装 Skill

## 概述

本技能帮用户在电脑上安装 Obsidian 笔记软件。
- Windows：优先 winget，无 winget 时多源下载（GitHub 代理 → 直连）
- macOS：优先 brew，无 brew 时多源下载 DMG
- 已安装则跳过，不重复操作
- 全程静默，无需用户干预安装过程
- 国内网络友好：自动 fallback 到 GitHub 代理加速

**安全声明**：本技能仅从 Obsidian 官方 GitHub releases 下载安装包，不收集任何用户数据，不修改用户任何已有文件。

## 执行流程

### 第一步：判断操作系统

根据用户环境判断 Windows 或 macOS。Linux 用户请自行安装（`flatpak install flathub md.obsidian.Obsidian`）。

### 第二步：检测是否已安装

**Windows**：检查以下路径是否存在 `Obsidian.exe`：
- `$env:LOCALAPPDATA\Obsidian\Obsidian.exe`
- `$env:ProgramFiles\Obsidian\Obsidian.exe`
- `$env:ProgramFiles(x86)\Obsidian\Obsidian.exe`

**macOS**：检查 `/Applications/Obsidian.app` 是否存在。

已安装 → 跳到第五步。

### 第三步：运行安装脚本

将下方对应系统的脚本保存为文件并执行。

#### Windows（PowerShell）

```powershell
# 见 scripts/install-windows.ps1
# 关键逻辑：
# 1. 探测 winget 是否在 PATH，不在则尝试完整路径
# 2. 有 winget → winget install --id Obsidian.Obsidian -e --silent --accept-package-agreements --accept-source-agreements
# 3. 无 winget → 多源获取版本号（GitHub API → releases 页面）
# 4. 多源下载安装包（GitHub 直连 → ghfast.top → gh-proxy.com）
# 5. 静默安装 + 验证 Obsidian.exe 存在
```

#### macOS（bash）

```bash
# 见 scripts/install-macos.sh
# 关键逻辑：
# 1. 检查 brew → brew install --cask obsidian
# 2. 无 brew → 多源获取版本号 + 多源下载 DMG
# 3. hdiutil attach → cp 到 /Applications → hdiutil detach
# 4. 验证 /Applications/Obsidian.app 存在
```

### 第四步：验证安装

- Windows：确认 `Obsidian.exe` 存在于安装目录
- macOS：确认 `/Applications/Obsidian.app` 存在
- 验证失败 → 告知用户手动从 https://obsidian.md/download 下载

### 第五步：收尾告知

安装完成后，告知用户：

1. 打开 Obsidian → 创建新库或打开已有文件夹作为库
2. **需手动操作**（无法自动化）：
   - 设置 → 常规 → 启用「命令行界面」
   - 想用第三方插件时：设置 → 第三方插件 → 关闭「受限模式」

## 用户沟通规范（重要）

**下载前必须告知用户：**
> 「Obsidian 安装包约 325 MB，国内网络下载可能需要 10-15 分钟。我会实时显示进度，请耐心等待。」

**下载中定期汇报：**
- 每 30 秒或每 10% 进度向用户汇报一次
- 格式：「已下载 30% (97/325 MB)，预计还需 10 分钟」
- 如果某个下载源失败，告知用户：「GitHub 直连较慢，切换到加速源...」

**下载完成后：**
> 「下载完成，正在安装...」

**如果下载失败：**
> 「下载失败，可能是网络问题。你可以：
> 1. 让我重试一次
> 2. 手动从 https://obsidian.md/download 下载安装」

**绝对不要：**
- 让用户面对黑屏等待超过 30 秒不说话
- 只说「正在下载」然后沉默 10 分钟
- 下载失败了不告诉用户

## 注意事项

- 脚本幂等：已安装会自动跳过
- 不删除或修改用户任何已有文件
- 路径支持中文和空格
- 不要写死版本号，始终从 GitHub API 获取最新版
- 不要声称"官方支持静默安装"（官方文档只教 GUI 安装）
- Windows 脚本使用 PowerShell，不用 bash 语法
- 如果用户网络无法访问 GitHub，提示用户手动从 obsidian.md/download 下载
