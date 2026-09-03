#!/usr/bin/env bash
#
# 把仓库 config/ 下的配置文件软链到 tokscale 配置目录。
#
#   ./link.sh              建立软链
#   ./link.sh --dry-run    只打印将要执行的操作
#   ./link.sh --unlink     拆除软链，把仓库内容拷回成真实文件
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/config"
TARGET_DIR="${TOKSCALE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/tokscale}"

# 即便误放进 config/ 也拒绝处理的文件名模式
DENY_PATTERNS=('*credentials*' 'device.json' '*.bak.*')

DRY_RUN=false
UNLINK=false

usage() {
  sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --unlink)  UNLINK=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log()  { printf '%s\n' "$*"; }
warn() { printf '\033[33m警告\033[0m %s\n' "$*" >&2; }
act()  { if $DRY_RUN; then printf '\033[36m[dry-run]\033[0m %s\n' "$*"; else printf '%s\n' "$*"; fi; }

is_denied() {
  local name="$1" pattern
  for pattern in "${DENY_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    [[ "$name" == $pattern ]] && return 0
  done
  return 1
}

hash_of() { shasum -a 256 "$1" | awk '{print $1}'; }

[[ -d "$SRC_DIR" ]] || { echo "找不到源目录：$SRC_DIR" >&2; exit 1; }

log "仓库源目录：$SRC_DIR"
log "目标配置目录：$TARGET_DIR"
log ""

if ! $DRY_RUN; then
  mkdir -p "$TARGET_DIR"
fi

handled=0

for src in "$SRC_DIR"/*; do
  [[ -e "$src" ]] || continue
  name="$(basename "$src")"

  if [[ -d "$src" ]]; then
    warn "跳过子目录：config/${name}（本脚本只处理顶层普通文件）"
    continue
  fi

  if is_denied "$name"; then
    warn "拒绝处理敏感文件：config/$name"
    continue
  fi

  target="$TARGET_DIR/$name"
  handled=$((handled + 1))

  if $UNLINK; then
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
      act "拆链 $target → 还原为真实文件"
      if ! $DRY_RUN; then
        rm "$target"
        cp "$src" "$target"
      fi
    elif [[ -e "$target" || -L "$target" ]]; then
      log "跳过 ${name}：目标不是指向本仓库的软链，未做改动"
    else
      log "跳过 ${name}：目标不存在"
    fi
    continue
  fi

  # 已经链到本仓库，无需重复处理
  if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    log "跳过 ${name}：已链接到本仓库"
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -f "$target" ]] && [[ "$(hash_of "$target")" == "$(hash_of "$src")" ]]; then
      act "替换 ${name}：内容与仓库版本相同，无需备份"
    else
      backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
      act "备份 $target → $backup"
      if ! $DRY_RUN; then
        cp -RL "$target" "$backup"
      fi
    fi
    if ! $DRY_RUN; then
      rm -rf "$target"
    fi
  fi

  act "建链 $target → $src"
  if ! $DRY_RUN; then
    ln -s "$src" "$target"
  fi
done

log ""
if [[ $handled -eq 0 ]]; then
  warn "config/ 下没有可处理的文件"
else
  log "完成，共处理 $handled 个文件。"
fi
