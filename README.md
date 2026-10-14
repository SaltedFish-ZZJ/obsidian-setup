# Obsidian 一键安装

让你的 agent 替你装 Obsidian，不用自己找下载页、点安装。

## 用法

把本 skill 的安装口令复制给你的 agent（Claude Code / Codex / Qoder 等），说「帮我装 Obsidian」即可。

脚本会自动判断系统、检测是否已装、选择最佳安装方式。已安装则跳过。

## 没有 agent？手动三步

1. 打开 https://obsidian.md/download
2. 下载对应系统的安装包
3. 打开安装文件，跟着提示走

## 安装后

- 打开 Obsidian → 创建新库或选择文件夹作为库
- 设置 → 常规 → 启用「命令行界面」（可选）
- 设置 → 第三方插件 → 关闭「受限模式」（使用第三方插件时需要）

## 支持系统

- Windows 10/11（PowerShell 5.1+）
- macOS 12+（Intel / Apple Silicon）

## 仓库内容

```
SKILL.md                      技能说明与执行流程
scripts/install-windows.ps1   Windows 安装脚本（winget → 多源下载）
scripts/install-macos.sh      macOS 安装脚本（brew → 多源下载 DMG）
scripts/test_skill.py         下载源测速与逻辑自检脚本
test-report.md                本机实测结果（未验证项已标注）
```

## 许可证

MIT
