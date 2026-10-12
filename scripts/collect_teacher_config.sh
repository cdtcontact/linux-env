#!/usr/bin/env bash
# Collect the currently installed teacher environment into this repository.
# Run as the normal account that already has ~/.vim, ~/.vimrc, ~/.zshrc and ~/.oh-my-zsh.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_HOME="${1:-$HOME}"
PAYLOAD="$ROOT/payload/home"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '[collect] %s\n' "$*"; }
die() { printf '[collect][ERROR] %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -ne 0 ]] || die "请使用已经安装了老师配置的普通用户执行，不要用 root。"
command -v rsync >/dev/null 2>&1 || die "缺少 rsync。先执行：sudo apt-get update && sudo apt-get install -y rsync"
[[ -d "$SRC_HOME/.vim" ]] || die "未找到 $SRC_HOME/.vim"
[[ -f "$SRC_HOME/.vimrc" ]] || die "未找到 $SRC_HOME/.vimrc"
[[ -f "$SRC_HOME/.zshrc" ]] || die "未找到 $SRC_HOME/.zshrc"
[[ -d "$SRC_HOME/.oh-my-zsh" ]] || die "未找到 $SRC_HOME/.oh-my-zsh"
[[ -f "$SRC_HOME/.oh-my-zsh/oh-my-zsh.sh" ]] || die "Oh My Zsh 不完整：缺少 oh-my-zsh.sh"

# Keep a copy of a prior payload before replacing it; this affects only the repo,
# never the working files in the user's home directory.
if [[ -e "$PAYLOAD/.vim" || -e "$PAYLOAD/.vimrc" || -e "$PAYLOAD/.zshrc" || -e "$PAYLOAD/.oh-my-zsh" ]]; then
  PREV="$ROOT/archive/payload-before-collect-$STAMP"
  mkdir -p "$PREV/home"
  for item in .vim .vimrc .zshrc .oh-my-zsh; do
    [[ ! -e "$PAYLOAD/$item" ]] || mv "$PAYLOAD/$item" "$PREV/home/$item"
  done
  log "旧的待发布 payload 已移至 $PREV"
fi
mkdir -p "$PAYLOAD"

# Copy the installed bundles/plugins, not their nested .git repositories,
# history files, Vim swap files, machine-specific tags, or compiled zsh dumps.
rsync -a \
  --exclude='.git/' \
  --exclude='systags' \
  --exclude='*.swp' --exclude='*.swo' --exclude='*.un~' \
  --exclude='*.zwc' --exclude='.DS_Store' \
  "$SRC_HOME/.vim/" "$PAYLOAD/.vim/"
cp -p "$SRC_HOME/.vimrc" "$PAYLOAD/.vimrc"
cp -p "$SRC_HOME/.zshrc" "$PAYLOAD/.zshrc"
rsync -a \
  --exclude='.git/' \
  --exclude='*.zwc' --exclude='.DS_Store' \
  --exclude='cache/' \
  "$SRC_HOME/.oh-my-zsh/" "$PAYLOAD/.oh-my-zsh/"

# Legacy scripts are preserved only for reference. The new init_env.sh does not execute them.
mkdir -p "$ROOT/archive/legacy"
for item in init_env.sh isoftstone_env.sh install_vim.sh install_zsh.sh; do
  if [[ -f "$SRC_HOME/$item" ]]; then
    cp -p "$SRC_HOME/$item" "$ROOT/archive/legacy/$item"
    log "已归档参考脚本：$item（新安装流程不会执行它）"
  fi
done

if [[ -f /usr/bin/isoftstone_check ]]; then
  read -r -p "检测到 /usr/bin/isoftstone_check。是否也把旧命令复制进仓库供审核？[y/N] " COPY_CHECKER
  if [[ "$COPY_CHECKER" =~ ^[Yy]$ ]]; then
    mkdir -p "$ROOT/payload/bin"
    cp -p /usr/bin/isoftstone_check "$ROOT/payload/bin/isoftstone_check"
    if command -v file >/dev/null 2>&1; then
      file /usr/bin/isoftstone_check | tee "$ROOT/payload/bin/isoftstone_check.file-info.txt"
    fi
    sha256sum /usr/bin/isoftstone_check | tee "$ROOT/payload/bin/isoftstone_check.sha256"
    log "旧命令已收集，但安装时仍会再询问一次，不会自动执行。"
  fi
fi

# Report items that need review, without uploading or printing private material.
log "收集完成。配置体积："
du -sh "$ROOT/payload/home/.vim" "$ROOT/payload/home/.oh-my-zsh" 2>/dev/null || true
log "Vim bundle 顶层插件数：$(find "$PAYLOAD/.vim/bundle" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
log "Oh My Zsh custom 插件："
find "$PAYLOAD/.oh-my-zsh/custom/plugins" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null || true
if find "$PAYLOAD/.vim" "$PAYLOAD/.oh-my-zsh" -type f \( -name '*.so' -o -name '*.o' -o -name '*.bundle' \) -print -quit 2>/dev/null | grep -q .; then
  printf '\n[collect][WARN] 发现本机编译产物（*.so/*.o/*.bundle）。这些文件可能与 CPU 架构或 Ruby 版本绑定，请运行：\n'
  printf '  find payload/home/.vim payload/home/.oh-my-zsh -type f \\( -name "*.so" -o -name "*.o" -o -name "*.bundle" \\) -print\n\n'
fi
printf '\n下一步：查看 README.md 和 notes/THIRD_PARTY_SOURCES.md；审查后再 git add / commit / push。\n'
