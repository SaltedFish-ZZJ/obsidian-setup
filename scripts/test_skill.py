"""
Obsidian 安装 Skill - 分步测试脚本
验证核心逻辑 + 多源下载速度测试
用法: python test_skill.py
"""

import os
import sys
import json
import time
import tempfile
import urllib.request

DIVIDER = "=" * 50

def step(n, title):
    print(f"\n{DIVIDER}")
    print(f"  步骤 {n}/5: {title}")
    print(f"{DIVIDER}")

def ok(msg):
    print(f"  [OK] {msg}")

def fail(msg):
    print(f"  [FAIL] {msg}")

def info(msg):
    print(f"  [INFO] {msg}")

def warn(msg):
    print(f"  [WARN] {msg}")

def test_download_speed(name, url, timeout=30):
    """测试单个源的下载速度，下载 512KB 后停止"""
    print(f"\n  测试: {name}")
    print(f"  URL: {url}")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "obsidian-skill-test"})
        start = time.time()

        with urllib.request.urlopen(req, timeout=timeout) as resp:
            total_read = 0
            chunk_size = 8192
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                total_read += len(chunk)
                elapsed = time.time() - start

                # 下载 512KB 后停止
                if total_read >= 512 * 1024:
                    break

                # 每 100KB 显示一次进度
                if total_read % (100 * 1024) < chunk_size:
                    mb = total_read / 1024 / 1024
                    speed = total_read / elapsed / 1024 / 1024 if elapsed > 0 else 0
                    print(f"\r  已下载: {mb:.2f} MB | 速度: {speed:.2f} MB/s", end="", flush=True)

        elapsed = time.time() - start
        speed = total_read / elapsed / 1024 / 1024 if elapsed > 0 else 0
        print(f"\r  已下载: {total_read / 1024 / 1024:.2f} MB | 速度: {speed:.2f} MB/s | 耗时: {elapsed:.1f}s")

        if speed > 0:
            ok(f"速度: {speed:.2f} MB/s")
            return speed
        else:
            fail("速度为 0")
            return 0

    except Exception as e:
        print()
        fail(f"失败: {e}")
        return 0

def main():
    print(f"\n{DIVIDER}")
    print("  Obsidian 安装 Skill - 分步测试 + 速度测试")
    print(f"{DIVIDER}")
    print("  测试: GitHub API / 多源下载速度 / 文件校验")
    print("  不执行实际安装，仅验证核心逻辑")
    print(DIVIDER)

    passed = 0
    failed = 0
    exe_url = None
    tag = "未知"
    tmp_file = None

    # ===== 步骤 1: GitHub API =====
    step(1, "测试 GitHub API 连通性")
    api_url = "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
    info(f"目标: {api_url}")

    try:
        req = urllib.request.Request(api_url, headers={"User-Agent": "obsidian-skill-test"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
            tag = data.get("tag_name", "未知")
            assets = data.get("assets", [])

        ok(f"API 连通成功")
        ok(f"最新版本: {tag}")
        info(f"可用资产数: {len(assets)}")

        exe_asset = None
        for a in assets:
            if a["name"].endswith(".exe"):
                exe_asset = a
                break

        if exe_asset:
            ok(f"找到 Windows 安装包: {exe_asset['name']}")
            info(f"大小: {exe_asset['size'] / 1024 / 1024:.1f} MB")
            exe_url = exe_asset["browser_download_url"]
        else:
            fail("未找到 .exe 安装包")

        passed += 1

    except Exception as e:
        fail(f"API 请求失败: {e}")
        info("可能原因: 网络问题 / GitHub API 限流")
        failed += 1

    # ===== 步骤 2: 多源下载速度测试 =====
    step(2, "测试多源下载速度（各下载 512KB）")

    if not exe_url:
        fail("跳过: 步骤 1 未获取到版本信息")
        failed += 1
    else:
        version = tag.lstrip("v")
        installer_name = f"Obsidian-{version}.exe"

        sources = [
            ("GitHub 直连", f"https://github.com/obsidianmd/obsidian-releases/releases/download/v{version}/{installer_name}"),
            ("GitHub 代理 (ghfast.top)", f"https://ghfast.top/https://github.com/obsidianmd/obsidian-releases/releases/download/v{version}/{installer_name}"),
            ("GitHub 代理 (gh-proxy.com)", f"https://gh-proxy.com/https://github.com/obsidianmd/obsidian-releases/releases/download/v{version}/{installer_name}"),
            ("Obsidian 官方 CDN", "https://obsidian.md/latest-exe"),
        ]

        speeds = []
        for name, url in sources:
            speed = test_download_speed(name, url)
            speeds.append((name, speed))

        # 排序显示
        print(f"\n  {'='*40}")
        print("  速度排名:")
        print(f"  {'='*40}")
        speeds.sort(key=lambda x: x[1], reverse=True)
        for i, (name, speed) in enumerate(speeds, 1):
            if speed > 0:
                print(f"  {i}. {name}: {speed:.2f} MB/s")
            else:
                print(f"  {i}. {name}: 失败")

        best = speeds[0]
        if best[1] > 0:
            ok(f"最快源: {best[0]} ({best[1]:.2f} MB/s)")
            passed += 1
        else:
            fail("所有源均失败")
            failed += 1

    # ===== 步骤 3: 下载完整文件 =====
    step(3, "测试完整下载（从最快源）")

    if not exe_url:
        fail("跳过: 步骤 1 未获取到下载链接")
        failed += 1
    else:
        tmp_dir = tempfile.gettempdir()
        tmp_file = os.path.join(tmp_dir, f"Obsidian-test-{tag}.exe")
        info(f"下载链接: {exe_url}")
        info(f"临时文件: {tmp_file}")
        info("开始下载...")

        try:
            def progress(block_num, block_size, total_size):
                downloaded = block_num * block_size
                if total_size > 0:
                    pct = min(100, downloaded * 100 // total_size)
                    mb_d = downloaded / 1024 / 1024
                    mb_t = total_size / 1024 / 1024
                    print(f"\r  进度: {pct}% ({mb_d:.1f}/{mb_t:.1f} MB)", end="", flush=True)

            urllib.request.urlretrieve(exe_url, tmp_file, reporthook=progress)
            print()
            ok("下载完成")
            passed += 1

        except Exception as e:
            print()
            fail(f"下载失败: {e}")
            info("可能原因: 网络不稳定 / GitHub 下载被墙")
            failed += 1
            tmp_file = None

    # ===== 步骤 4: 文件校验 =====
    step(4, "验证下载文件完整性")

    if not tmp_file or not os.path.exists(tmp_file):
        fail("跳过: 文件不存在")
        failed += 1
    else:
        size = os.path.getsize(tmp_file)
        ok(f"文件存在: {tmp_file}")
        ok(f"文件大小: {size / 1024 / 1024:.1f} MB")

        with open(tmp_file, "rb") as f:
            header = f.read(2)

        if header == b"MZ":
            ok("文件头正确 (PE 格式)")
        else:
            fail(f"文件头异常: {header}")

        passed += 1

    # ===== 步骤 5: 清理 =====
    step(5, "清理临时文件")

    if tmp_file and os.path.exists(tmp_file):
        try:
            os.remove(tmp_file)
            ok(f"已删除: {tmp_file}")
        except Exception as e:
            fail(f"删除失败: {e}")
            info("请手动删除临时文件")
    else:
        info("无需清理")

    passed += 1

    # ===== 总结 =====
    print(f"\n{DIVIDER}")
    print("  测试结果")
    print(f"{DIVIDER}")
    print(f"  通过: {passed}/5")
    print(f"  失败: {failed}/5")

    if failed == 0:
        print("\n  [SUCCESS] 所有测试通过，Skill 核心逻辑正常")
        print("  可以上传到 SkillHub 了")
    elif failed <= 2:
        print("\n  [WARNING] 部分测试失败，建议排查后重试")
    else:
        print("\n  [FAIL] 多数测试失败，Skill 可能无法正常工作")

    print(f"{DIVIDER}\n")
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
