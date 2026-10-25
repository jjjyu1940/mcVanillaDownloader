# MC 原版下载器 (Vanilla Downloader)

一个**零 Python、零第三方运行时**的 Minecraft 原版客户端下载工具，下载结果可被 **PCL2 / HMCL / 官方启动器**直接识别。

## 特性

- 从 Mojang 官方源拉取，纯正原版，不接任何破解账号
- 两套脚本独立，但**下载逻辑完全一致**：Windows 靠 PowerShell，Linux/macOS 靠 bash + jq + curl
- 自动校验 SHA1，已下载且完整的文件会跳过，支持断点续传
- 按启动器通用目录结构落盘，刷新即可见

## 目录结构

```
<游戏根>/
└─ .minecraft/
   ├─ versions/<id>/<id>.jar    客户端本体
   ├─ versions/<id>/<id>.json   版本元数据
   ├─ libraries/...             依赖库（Maven 结构）
   └─ assets/indexes/<id>.json  资源索引
```

> 版本文件夹名、jar 名、json 名三者必须完全一致，启动器才认。

## 快速开始

### Windows (mc_menu.bat)

双击或在 cmd 中执行，进入数字菜单：

```
1) 列出可下载版本
2) 下载指定版本（仅本体 + 库）
3) 下载指定版本（含资源文件）
4) 设置游戏目录
5) 退出
```

下载完成后，在 PCL2 / HMCL 中把游戏目录指向脚本同级的 `.minecraft\` 并刷新。

### Linux / macOS (hmcl_dev.sh)

```bash
chmod +x hmcl_dev.sh
./hmcl_dev.sh
# 菜单选 5 下载 MC，选项 1-4 用于 HMCL 开发
```

### 依赖

| 平台 | 必需 | 说明 |
|---|---|---|
| Windows | PowerShell（Win10/11 自带） | 无需额外安装 |
| Linux/macOS | jq、curl、sha1sum | `sudo apt install jq curl` 或 `brew install jq curl` |

## 工作流程

1. 拉取版本清单 `piston-meta.mojang.com/mc/game/version_manifest_v2.json`
2. 解析指定版本的元数据 JSON
3. 下载客户端 jar 并 SHA1 校验
4. 按 `rules` 过滤平台，下载 `libraries`（含 natives）
5. 下载资源索引；可选下载资源文件
6. 落盘为标准目录结构

## 平台过滤规则

只下载符合当前平台的依赖库：

- 无 `rules` 字段 → 下载
- 有 `rules` 且含 `action: allow, os.name: windows` → 下载
- 有 `rules` 且只允许 linux/macOS → 跳过

> Windows 版下 windows 的 natives，Linux/macOS 版同样按 windows 规则筛选（保证跨平台一致）。

## 测试

沙盒环境无外网，真实网络测试需在本地执行：

```bash
# Windows
mc_menu.bat          # 选 1 看版本列表，选 2 下 1.20.1

# Linux/macOS
./hmcl_dev.sh        # 选 5，输入 1.20.1
```

离线逻辑验证（mock 版本 JSON）：

```bash
# 模拟版本元数据，测试目录结构与平台过滤
VMETA=$(cat <<'EOF'
{
  "downloads": {"client": {"url": "https://example.com/1.20.1.jar", "sha1": "abc"}},
  "libraries": [
    {"rules": [{"action": "allow", "os": {"name": "windows"}}], "downloads": {"artifact": {"url": "https://example.com/a.jar", "path": "a/a.jar"}}},
    {"rules": [{"action": "allow", "os": {"name": "linux"}}], "downloads": {"artifact": {"url": "https://example.com/b.jar", "path": "b/b.jar"}}},
    {"downloads": {"artifact": {"url": "https://example.com/c.jar", "path": "c/c.jar"}}}
  ],
  "assetIndex": {"id": "1.20", "url": "https://example.com/1.20.json"}
}
EOF
)
echo "$VMETA" > /tmp/test.json
# 用 jq 验证平台过滤逻辑
echo "$VMETA" | jq -c '.libraries[]' | while IFS= read -r lib; do
  no_rules=$(echo "$lib" | jq '(.rules // []) | length == 0')
  win_ok=$(echo "$lib" | jq '([.rules[]? | select(.action=="allow" and (.os.name? == "windows"))] | length) > 0')
  if [[ "$no_rules" == "true" || "$win_ok" == "true" ]]; then
    echo "✓ 下载: $(echo "$lib" | jq -r '.downloads.artifact.path')"
  else
    echo "✗ 跳过: $(echo "$lib" | jq -r '.downloads.artifact.path')"
  fi
done
```

预期输出：

```
✓ 下载: a/a.jar      （windows allow）
✗ 跳过: b/b.jar      （仅 linux）
✓ 下载: c/c.jar      （无 rules）
```

## 注意事项

- 只下载原版文件，用于合法拥有的 Minecraft Java 版环境
- PCL2 2.99+ 已移除内置游戏下载，本工具正好补上这块缺口
- 资源文件可能数 GB，建议默认只下索引，进游戏后按需拉取
- HMCL 本身 GPLv3，改完记得保留署名并改个名字区分

## 许可证

MIT（脚本本身），Minecraft 相关资源版权归 Mojang Studios 所有。
