#Requires -Version 5.1
# Obsidian 静默安装脚本（Windows）
# 幂等：已安装则跳过

$ErrorActionPreference = 'Stop'

function Write-Step($msg) {
    Write-Host "[obsidian-setup] $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "[obsidian-setup] ✓ $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "[obsidian-setup] ⚠ $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "[obsidian-setup]  $msg" -ForegroundColor Red
}

# --- 1. 检测是否已安装 ---
$installPaths = @(
    "$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
    "$env:ProgramFiles\Obsidian\Obsidian.exe",
    "${env:ProgramFiles(x86)}\Obsidian\Obsidian.exe"
)

$existingExe = $null
foreach ($p in $installPaths) {
    if (Test-Path $p) {
        $existingExe = $p
        break
    }
}

if ($existingExe) {
    Write-Ok "Obsidian 已安装：$existingExe"
    Write-Host "路径：$existingExe"
    exit 0
}

Write-Step "未检测到 Obsidian，开始安装..."

# --- 2. 尝试 winget ---
$wingetPath = $null

# 先试 PATH
try {
    $check = Get-Command winget -ErrorAction SilentlyContinue
    if ($check) { $wingetPath = 'winget' }
} catch {}

# PATH 没有，试完整路径
if (-not $wingetPath) {
    $fullPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $fullPath) {
        $wingetPath = $fullPath
        Write-Step "winget 不在 PATH 中，使用完整路径：$fullPath"
    }
}

if ($wingetPath) {
    Write-Step "使用 winget 安装..."

    # 先更新 source（避免包索引过期）
    Write-Step "更新 winget 源..."
    & $wingetPath source update 2>&1 | Out-Null

    Write-Step "执行 winget install..."
    $proc = Start-Process -FilePath $wingetPath `
        -ArgumentList 'install', '--id', 'Obsidian.Obsidian', '-e', '--silent',
            '--accept-package-agreements', '--accept-source-agreements' `
        -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0) {
        Write-Ok "winget 安装成功"
    } else {
        Write-Warn "winget 安装退出码：$($proc.ExitCode)，尝试 fallback..."
        $wingetPath = $null
    }
}

# --- 3. Fallback：从 GitHub 下载 ---
if (-not $wingetPath) {
    Write-Step "winget 不可用，从 GitHub 下载..."

    # 获取最新版本号
    $version = $null

    # 方式 A：GitHub API
    try {
        $apiUrl = 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest'
        $headers = @{ 'User-Agent' = 'obsidian-setup-skill' }
        $resp = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 15

        if ($resp.tag_name -match '^v?(\d+\.\d+\.\d+)') {
            $version = $Matches[1]
            Write-Step "从 GitHub API 获取版本：$version"
        }
    } catch {
        Write-Warn "GitHub API 请求失败：$($_.Exception.Message)"
    }

    # 方式 B：解析 releases 页面（API 限流时）
    if (-not $version) {
        try {
            Write-Step "尝试从 releases 页面获取版本号..."
            $pageUrl = 'https://github.com/obsidianmd/obsidian-releases/releases/latest'
            # 跟随重定向，获取最终 URL 中的版本号
            $response = Invoke-WebRequest -Uri $pageUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue
        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            # 302 重定向，Location header 里有版本号
            if ($_.Exception.Response.Headers.Location) {
                $loc = $_.Exception.Response.Headers.Location.ToString()
                if ($loc -match '/download/v?(\d+\.\d+\.\d+)/') {
                    $version = $Matches[1]
                    Write-Step "从重定向 URL 获取版本：$version"
                }
            }
        } catch {
            Write-Warn "releases 页面请求失败：$($_.Exception.Message)"
        }
    }

    # 方式 C：obsidian.md 官方 CDN（国内速度通常更快）
    if (-not $version) {
        try {
            Write-Step "尝试从 obsidian.md 获取版本号..."
            $cdnUrl = 'https://obsidian.md/latest-exe'
            $response = Invoke-WebRequest -Uri $cdnUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue
        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            if ($_.Exception.Response.Headers.Location) {
                $loc = $_.Exception.Response.Headers.Location.ToString()
                # URL 格式可能是 .../Obsidian-1.14.4.exe 或 .../v1.14.4/...
                if ($loc -match '(\d+\.\d+\.\d+)') {
                    $version = $Matches[1]
                    Write-Step "从 obsidian.md CDN 获取版本：$version"
                }
            }
        } catch {
            Write-Warn "obsidian.md 请求失败：$($_.Exception.Message)"
        }
    }

    if (-not $version) {
        Write-Err "无法获取 Obsidian 最新版本号"
        Write-Host "请手动从 https://obsidian.md/download 下载安装"
        exit 1
    }

    # 下载安装包 — 多源 fallback 链（按实测速度排序）
    $installerName = "Obsidian-$version.exe"
    $downloadSources = @(
        @{
            Name = "GitHub 代理 (gh-proxy.com)"
            Url  = "https://gh-proxy.com/https://github.com/obsidianmd/obsidian-releases/releases/download/v$version/$installerName"
        },
        @{
            Name = "GitHub 代理 (ghfast.top)"
            Url  = "https://ghfast.top/https://github.com/obsidianmd/obsidian-releases/releases/download/v$version/$installerName"
        },
        @{
            Name = "GitHub 直连"
            Url  = "https://github.com/obsidianmd/obsidian-releases/releases/download/v$version/$installerName"
        }
    )

    $tempDir = [System.IO.Path]::GetTempPath()
    $installerPath = Join-Path $tempDir $installerName

    # 逐个源尝试下载
    $downloaded = $false
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    foreach ($source in $downloadSources) {
        Write-Step "尝试从 $($source.Name) 下载..."
        try {
            # 先获取文件大小（用于计算进度和 ETA）
            $totalSize = $null
            try {
                $headResp = Invoke-WebRequest -Uri $source.Url -Method Head -TimeoutSec 15
                if ($headResp.Headers['Content-Length']) {
                    $totalSize = [long]$headResp.Headers['Content-Length']
                }
            } catch {}

            if ($totalSize) {
                $totalMB = [math]::Round($totalSize / 1MB, 1)
                Write-Host "  文件大小：$totalMB MB，国内下载预计需要 10-15 分钟" -ForegroundColor Gray
                Write-Host "  下载中..." -ForegroundColor Gray
            } else {
                Write-Host "  下载中（文件大小未知）..." -ForegroundColor Gray
            }

            # 带进度的下载
            $startTime = Get-Date
            $lastReport = $startTime
            $bytesRead = 0

            $response = Invoke-WebRequest -Uri $source.Url -TimeoutSec 300
            $stream = $response.RawContentStream
            $fileStream = [System.IO.File]::Create($installerPath)

            $buffer = New-Object byte[] 8192
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fileStream.Write($buffer, 0, $read)
                $bytesRead += $read

                # 每 3 秒或每 5% 报告一次进度
                $now = Get-Date
                $elapsed = ($now - $lastReport).TotalSeconds
                if ($totalSize -and $elapsed -ge 3) {
                    $pct = [math]::Round($bytesRead * 100 / $totalSize, 1)
                    $downloadedMB = [math]::Round($bytesRead / 1MB, 1)
                    $speed = $bytesRead / ($now - $startTime).TotalSeconds / 1MB
                    $remainingSec = ($totalSize - $bytesRead) / ($bytesRead / ($now - $startTime).TotalSeconds)
                    $remainingMin = [math]::Round($remainingSec / 60, 1)

                    Write-Host "`r  进度：$pct% ($downloadedMB/$totalMB MB) | 速度：$([math]::Round($speed, 2)) MB/s | 预计剩余：$remainingMin 分钟" -NoNewline -ForegroundColor Gray

                    $lastReport = $now
                }
            }

            $fileStream.Close()
            $stream.Close()
            Write-Host ""  # 换行

            $fileSize = [math]::Round((Get-Item $installerPath).Length / 1MB, 1)
            Write-Ok "下载完成：$($source.Name) ($fileSize MB)"
            $downloaded = $true
            break
        } catch {
            Write-Host ""  # 换行
            Write-Warn "$($source.Name) 下载失败：$($_.Exception.Message)"
            Remove-Item $installerPath -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloaded) {
        Write-Err "所有下载源均失败"
        Write-Host "请手动从 https://obsidian.md/download 下载安装"
        exit 1
    }

    # 静默安装
    Write-Step "运行静默安装..."
    $proc = Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0) {
        Write-Ok "安装完成"
    } else {
        Write-Err "安装程序退出码：$($proc.ExitCode)"
        Write-Host "如果弹出 SmartScreen 安全提示，请点击「更多信息」→「仍要运行」"
        exit 1
    }

    # 清理安装包
    Remove-Item $installerPath -ErrorAction SilentlyContinue
}

# --- 4. 验证安装 ---
Write-Step "验证安装..."
$found = $false
foreach ($p in $installPaths) {
    if (Test-Path $p) {
        $ver = (Get-Item $p).VersionInfo.ProductVersion
        Write-Ok "Obsidian 安装成功！"
        Write-Host "  路径：$p"
        Write-Host "  版本：$ver"
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Warn "安装程序已运行但未找到 Obsidian.exe"
    Write-Host "请检查是否安装到了其他目录，或手动从 https://obsidian.md/download 安装"
    exit 1
}

# --- 5. 收尾提示 ---
Write-Host ""
Write-Host "===== 安装完成 =====" -ForegroundColor Green
Write-Host ""
Write-Host "接下来请手动完成："
Write-Host "  1. 打开 Obsidian → 创建新库或选择文件夹作为库"
Write-Host "  2. 设置 → 常规 → 启用「命令行界面」（可选）"
Write-Host "  3. 设置 → 第三方插件 → 关闭「受限模式」（使用第三方插件时需要）"
Write-Host ""
