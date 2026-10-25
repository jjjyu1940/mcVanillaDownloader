#!/usr/bin/env bash
# hmcl_dev.sh – HMCL 开发 & MC 原版下载器（纯 shell，无 Python）
set -euo pipefail

HMCL_DIR="${HMCL_DIR:-$HOME/HMCL}"
MC_DIR="${MC_DIR:-$HOME/.minecraft}"
MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"

# 依赖检查
command -v jq >/dev/null 2>&1 || { echo "需要 jq：sudo apt install jq / brew install jq"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "需要 curl"; exit 1; }
command -v sha1sum >/dev/null 2>&1 || { echo "需要 sha1sum"; exit 1; }

banner() { echo -e "\n\033[1;36m$1\033[0m"; }

# ---------- 菜单 ----------
menu() {
  clear
  echo "  ☕ HMCL DEV TOOLKIT (Linux/macOS)"
  echo "  ─────────────────────────"
  echo "  1) 克隆 HMCL 源码"
  echo "  2) 检查 JDK（需 17+）"
  echo "  3) Gradle 构建（makeExecutables）"
  echo "  4) 运行开发版 HMCL"
  echo "  5) 下载原版 MC（给 HMCL 测试用）"
  echo "  6) 退出"
  read -rp "  > 选择: " c
  case "$c" in
    1) clone_hmcl ;;
    2) check_jdk ;;
    3) build_hmcl ;;
    4) run_hmcl ;;
    5) download_mc ;;
    6) exit 0 ;;
    *) menu ;;
  esac
}

clone_hmcl() {
  banner "克隆 HMCL..."
  git clone https://github.com/HMCL-dev/HMCL.git "$HMCL_DIR"
  echo "已克隆到 $HMCL_DIR"
  menu
}

check_jdk() {
  banner "JDK 版本:"
  java -version 2>&1 | head -3
  if ! java -version 2>&1 | grep -q '"1[789]\|2[0-9]"'; then
    echo "⚠ 需要 JDK 17+，请先安装：sudo apt install openjdk-17-jdk"
  fi
  read -rp "按回车返回"
  menu
}

build_hmcl() {
  banner "构建 HMCL..."
  cd "$HMCL_DIR"
  ./gradlew clean makeExecutables
  echo "产物在 HMCL/build/libs/"
  menu
}

run_hmcl() {
  banner "启动开发版 HMCL..."
  cd "$HMCL_DIR"
  ./gradlew run
  menu
}

# ---------- MC 原版下载（纯 shell，与 bat 逻辑一致）----------
# 平台过滤：无 rules 或 含 windows allow 才下载
lib_allowed() {
  local lib="$1"
  local no_rules
  no_rules=$(echo "$lib" | jq '(.rules // []) | length == 0')
  if [[ "$no_rules" == "true" ]]; then
    return 0
  fi
  local win_ok
  win_ok=$(echo "$lib" | jq '
    ([.rules[]? | select(.action=="allow" and (.os.name? == "windows"))] | length) > 0
  ')
  if [[ "$win_ok" == "true" ]]; then
    return 0
  fi
  return 1
}

download_mc() {
  read -rp "输入版本号（如 1.20.1）: " VER
  [[ -z "$VER" ]] && menu
  banner "下载 $VER 到 $MC_DIR ..."

  local VURL
  VURL=$(curl -s "$MANIFEST" | jq -r ".versions[] | select(.id==\"$VER\") | .url")
  [[ -z "$VURL" || "$VURL" == "null" ]] && { echo "版本不存在"; read -rp "回车返回"; menu; }

  local VMETA
  VMETA=$(curl -s "$VURL")
  local VDIR="$MC_DIR/versions/$VER"
  mkdir -p "$VDIR"

  # 1. 版本 json
  echo "$VMETA" > "$VDIR/$VER.json"
  echo "[ok] 版本元数据 $VER.json"

  # 2. 客户端 jar
  local CJAR CSHA JARPATH
  CJAR=$(echo "$VMETA" | jq -r '.downloads.client.url')
  CSHA=$(echo "$VMETA" | jq -r '.downloads.client.sha1')
  JARPATH="$VDIR/$VER.jar"
  if [[ -f "$JARPATH" ]] && [[ "$(sha1sum "$JARPATH" | cut -d' ' -f1)" == "$CSHA" ]]; then
    echo "[skip] jar 已存在"
  else
    curl -sL "$CJAR" -o "$JARPATH"
    local size
    size=$(du -h "$JARPATH" | cut -f1)
    echo "[ok] 客户端 jar ($size)"
  fi

  # 3. 依赖库
  mkdir -p "$MC_DIR/libraries"
  echo "$VMETA" | jq -c '.libraries[]' | while IFS= read -r lib; do
    if ! lib_allowed "$lib"; then
      continue
    fi
    # artifact
    local art_url art_path dst
    art_url=$(echo "$lib" | jq -r '.downloads.artifact.url // empty')
    if [[ -n "$art_url" && "$art_url" != "null" ]]; then
      art_path=$(echo "$lib" | jq -r '.downloads.artifact.path')
      dst="$MC_DIR/libraries/$art_path"
      mkdir -p "$(dirname "$dst")"
      if [[ ! -f "$dst" ]]; then
        curl -sL "$art_url" -o "$dst"
      fi
    fi
    # natives-windows
    local nurl npath ndst
    nurl=$(echo "$lib" | jq -r '.downloads.classifiers."natives-windows".url // empty')
    if [[ -n "$nurl" && "$nurl" != "null" ]]; then
      npath=$(echo "$lib" | jq -r '.downloads.classifiers."natives-windows".path')
      ndst="$MC_DIR/libraries/$npath"
      mkdir -p "$(dirname "$ndst")"
      if [[ ! -f "$ndst" ]]; then
        curl -sL "$nurl" -o "$ndst"
      fi
    fi
  done
  echo "[ok] 依赖库下载完成"

  # 4. 资源索引
  local AID AURL
  AID=$(echo "$VMETA" | jq -r '.assetIndex.id // empty')
  if [[ -n "$AID" && "$AID" != "null" ]]; then
    AURL=$(echo "$VMETA" | jq -r '.assetIndex.url')
    mkdir -p "$MC_DIR/assets/indexes"
    curl -sL "$AURL" -o "$MC_DIR/assets/indexes/$AID.json"
    echo "[ok] 资源索引 $AID.json"
  fi

  echo -e "\n完成！用 HMCL 打开 $MC_DIR 即可看到 $VER"
  read -rp "回车返回"
  menu
}

menu
