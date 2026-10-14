# 测试报告

## 环境

- 系统：Windows 10.0.26200 (x64)
- Shell：Git Bash / PowerShell 5.1
- 测试日期：2026-10-14

## 测试结果

| # | 测试项 | 命令 | 实际输出 | 结论 |
|---|--------|------|----------|------|
| 1 | Obsidian 是否已安装 | `Test-Path $env:LOCALAPPDATA\Obsidian\Obsidian.exe` | `False` | 本机未安装 |
| 2 | winget 是否在 PATH | `Get-Command winget` | 无输出（exit code 1） | 本机 winget 不在 PATH |
| 3 | winget 完整路径 | `Test-Path $env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe` | `False` | 本机无 winget |
| 4 | GitHub API 获取版本 | `Invoke-RestMethod https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest` | `tag_name: v1.14.4` | 通过 |
| 5 | 多源下载 fallback | — | — | 未验证（需要实际运行脚本） |
| 6 | 静默安装 | — | — | 未验证（不应在用户机器上静默安装） |

## 说明

- 测试 1-4 在本机实际运行，有真实输出
- 测试 5-6 未在干净机器上验证，标为「待实测」
- 本机无 winget，因此 winget 安装分支未实测，但 GitHub API fallback 分支的 API 调用已验证通过
- 多源下载逻辑已加入脚本，但需要实际运行才能验证每个源是否可用

## 干净机器验证清单（待实测）

1. 找一台未装 Obsidian 的 Windows 机器
2. 确认 winget 可用：`winget --version`
3. 运行 `scripts/install-windows.ps1`
4. 检查输出是否显示「Obsidian 安装成功」
5. 确认 `$env:LOCALAPPDATA\Obsidian\Obsidian.exe` 存在
6. 双击 Obsidian.exe 确认能正常启动

## 多源下载测试建议

在以下网络环境分别测试：
- 正常网络（能访问 GitHub）
- 受限网络（GitHub 被墙，测试代理和 CDN fallback）
- 完全离线（应提示手动下载）
