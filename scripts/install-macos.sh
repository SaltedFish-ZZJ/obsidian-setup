#!/bin/bash
# Obsidian 静默安装脚本（macOS）
# 幂等：已安装则跳过

set -euo pipefail

info()  { echo "[obsidian-setup] $*"; }
ok()    { echo "[obsidian-setup] ✓ $*"; }
warn()  { echo "[obsidian-setup] ⚠ $*"; }
err()   { echo "[obsidian-setup]  $*" >&2; }

# --- 1. 检测是否已安装 ---
if [ -d "/Applications/Obsidian.app" ]; then
    ok "Obsidian 已安装：/Applications/Obsidian.app"
    exit 0
fi

info "未检测到 Obsidian，开始安装..."

# --- 2. 尝试 brew ---
if command -v brew &>/dev/null; then
    info "使用 Homebrew 安装..."
    if brew install --cask obsidian; then
        ok "Homebrew 安装成功"
    else
        warn "Homebrew 安装失败，尝试 fallback..."
    fi
fi

# --- 3. Fallback：下载 DMG ---
if [ ! -d "/Applications/Obsidian.app" ]; then
    info "从 GitHub 下载..."

    # 获取最新版本号 — 多源 fallback
    version=""

    # 方式 A：从重定向 URL 提取（GitHub releases）
    redirect_url=$(curl -sI -L -o /dev/null -w '%{url_effective}' \
        'https://github.com/obsidianmd/obsidian-releases/releases/latest' 2>/dev/null || true)

    if echo "$redirect_url" | grep -qE '/download/v?[0-9]+\.[0-9]+\.[0-9]+'; then
        version=$(echo "$redirect_url" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        info "从重定向 URL 获取版本：$version"
    fi

    # 方式 B：GitHub API
    if [ -z "$version" ]; then
        api_resp=$(curl -s 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest' \
            -H 'User-Agent: obsidian-setup-skill' --max-time 15 2>/dev/null || true)
        if echo "$api_resp" | grep -q '"tag_name"'; then
            version=$(echo "$api_resp" | grep -oE '"tag_name":\s*"v?[^"]*"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -n "$version" ] && info "从 GitHub API 获取版本：$version"
        fi
    fi

    # 方式 C：obsidian.md 官方 CDN
    if [ -z "$version" ]; then
        cdn_redirect=$(curl -sI -L -o /dev/null -w '%{url_effective}' \
            'https://obsidian.md/latest-exe' 2>/dev/null || true)
        if echo "$cdn_redirect" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
            version=$(echo "$cdn_redirect" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -n "$version" ] && info "从 obsidian.md CDN 获取版本：$version"
        fi
    fi

    if [ -z "$version" ]; then
        err "无法获取 Obsidian 最新版本号"
        echo "请手动从 https://obsidian.md/download 下载安装"
        exit 1
    fi

    # 下载 DMG — 多源 fallback 链（按实测速度排序）
    dmg_name="Obsidian-${version}.dmg"
    download_sources=(
        "GitHub 代理 (gh-proxy.com)|https://gh-proxy.com/https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/${dmg_name}"
        "GitHub 代理 (ghfast.top)|https://ghfast.top/https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/${dmg_name}"
        "GitHub 直连|https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/${dmg_name}"
    )

    tmp_dmg="/tmp/${dmg_name}"
    downloaded=false

    for source_entry in "${download_sources[@]}"; do
        source_name="${source_entry%%|*}"
        source_url="${source_entry#*|}"

        info "尝试从 $source_name 下载..."
        if curl -L -o "$tmp_dmg" "$source_url" --max-time 60 --silent --fail 2>/dev/null; then
            ok "下载完成：$source_name"
            downloaded=true
            break
        else
            warn "$source_name 下载失败"
            rm -f "$tmp_dmg"
        fi
    done

    if [ "$downloaded" = false ]; then
        err "所有下载源均失败"
        echo "请手动从 https://obsidian.md/download 下载安装"
        exit 1
    fi

    # 挂载 DMG
    info "挂载 DMG..."
    mount_point=$(hdiutil attach "$tmp_dmg" -nobrowse -readonly -noautoopen 2>/dev/null | grep '/Volumes/' | tail -1 | awk '{print $NF}')

    if [ -z "$mount_point" ]; then
        err "挂载 DMG 失败"
        rm -f "$tmp_dmg"
        exit 1
    fi

    ok "挂载到：$mount_point"

    # 复制到 /Applications
    info "复制到 /Applications..."
    if [ -d "$mount_point/Obsidian.app" ]; then
        cp -R "$mount_point/Obsidian.app" /Applications/
    else
        # 尝试找 .app 文件
        app_file=$(find "$mount_point" -name "*.app" -maxdepth 2 | head -1)
        if [ -n "$app_file" ]; then
            cp -R "$app_file" /Applications/
        else
            err "在 DMG 中未找到 Obsidian.app"
            hdiutil detach "$mount_point" 2>/dev/null
            rm -f "$tmp_dmg"
            exit 1
        fi
    fi

    # 卸载 DMG
    hdiutil detach "$mount_point" 2>/dev/null
    rm -f "$tmp_dmg"
    ok "安装完成"
fi

# --- 4. 验证 ---
if [ -d "/Applications/Obsidian.app" ]; then
    ok "Obsidian 安装成功！"
    echo "  路径：/Applications/Obsidian.app"
else
    warn "安装程序已运行但未找到 Obsidian.app"
    echo "请手动从 https://obsidian.md/download 下载安装"
    exit 1
fi

# --- 5. 收尾提示 ---
echo ""
echo "===== 安装完成 ====="
echo ""
echo "接下来请手动完成："
echo "  1. 打开 Obsidian → 创建新库或选择文件夹作为库"
echo "  2. 设置 → 常规 → 启用「命令行界面」（可选）"
echo "  3. 设置 → 第三方插件 → 关闭「受限模式」（使用第三方插件时需要）"
echo ""
