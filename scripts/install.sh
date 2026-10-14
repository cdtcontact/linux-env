#!/usr/bin/env bash
# Installs only the maintained configuration, never archive/ or payload/.
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

log() { printf '[linux-env] %s\n' "$*"; }
die() { printf '[linux-env] ERROR: %s\n' "$*" >&2; exit 1; }
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_USER=root
if [[ -n ${SUDO_USER:-} && ${SUDO_USER:-} != root ]] && getent passwd "$SUDO_USER" >/dev/null 2>&1; then
  TARGET_USER="$SUDO_USER"
fi
SKIP_PACKAGES=0
SKIP_CHECKS=0
CHANGE_SHELL=1
INTERACTIVE=auto
while (($#)); do
  case "$1" in
    --user) [[ $# -ge 2 && "$2" != -* ]] || die '--user 需要已有用户名'; TARGET_USER="$2"; shift ;;
    --no-change-shell) CHANGE_SHELL=0 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-checks) SKIP_CHECKS=1 ;;
    --interactive) [[ "$INTERACTIVE" != no ]] || die '不能同时使用 --interactive 和 --non-interactive'; INTERACTIVE=yes ;;
    --non-interactive) [[ "$INTERACTIVE" != yes ]] || die '不能同时使用 --interactive 和 --non-interactive'; INTERACTIVE=no ;;
    --help|-h) bash "$REPO_DIR/init_env.sh" --help; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
  shift
done

[[ $EUID -eq 0 ]] || die '请使用 sudo -i 后运行。'
[[ -r /etc/os-release ]] || die '无法读取 /etc/os-release。'
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} =~ ^(22\.04|24\.04|26\.04)$ ]] || die '仅支持 Ubuntu 22.04 / 24.04 / 26.04 LTS。'
[[ "$TARGET_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ ]] || die '用户名不合法。'
getent passwd "$TARGET_USER" >/dev/null || die "用户 $TARGET_USER 不存在；请交互运行并在引导中输入新用户名。"
resolve_target_account() {
  local entry
  entry="$(getent passwd "$TARGET_USER")" || die "用户 $TARGET_USER 不存在。"
  IFS=: read -r _ _ TARGET_UID _ _ TARGET_HOME _ <<< "$entry"
  [[ "$TARGET_HOME" == /* && -d "$TARGET_HOME" && ! -L "$TARGET_HOME" ]] || die '目标 home 必须是已存在的绝对目录，不能是符号链接。'
  TARGET_HOME="$(realpath -- "$TARGET_HOME")"
  [[ "$TARGET_HOME" != / && "$TARGET_HOME" != /etc && "$TARGET_HOME" != /usr && "$TARGET_HOME" != /var ]] || die '目标 home 不合法。'
  [[ "$TARGET_UID" == 0 && "$TARGET_USER" == root || "$TARGET_UID" -ge 1000 ]] || die '不配置系统服务账号。'
  [[ $(stat -c %u "$TARGET_HOME") == "$TARGET_UID" ]] || die 'home 所有者与目标用户不一致。'
}
for item in config/vimrc config/zshrc config/tmux.conf config/gitconfig config/editorconfig scripts/identity.sh scripts/configure-home.sh scripts/linux-env-doctor scripts/linux-env-new examples/c/CMakeLists.txt examples/cpp/CMakeLists.txt examples/python/pyproject.toml; do
  [[ -f "$REPO_DIR/$item" ]] || die "配置不完整: $item"
done
# Detect the original terminal before stdout is redirected through tee.
if [[ "$INTERACTIVE" == auto ]]; then
  if [[ -t 0 && -t 1 ]]; then INTERACTIVE=yes; else INTERACTIVE=no; fi
fi
if [[ "$INTERACTIVE" == yes ]]; then
  { exec {TTY_FD}<>/dev/tty; } 2>/dev/null || die '--interactive 需要可用的交互终端。'
fi
# shellcheck source=scripts/identity.sh
source "$REPO_DIR/scripts/identity.sh"

umask 022
install -d -m 700 /var/log/linux-env
LOG_FILE="/var/log/linux-env/install-$(date +%Y%m%d-%H%M%S)-$$.log"
exec > >(tee -a "$LOG_FILE") 2>&1
on_error() {
  local status="$1" line="$2"
  printf '[linux-env] 安装失败：第 %s 行，退出码 %s。日志: %s；修复后可重跑。\n' "$line" "$status" "$LOG_FILE" >&2
  exit "$status"
}
trap 'on_error "$?" "$LINENO"' ERR
exec 9>/run/lock/linux-env.lock
flock -n 9 || die '已有 linux-env 安装正在运行。'
log "日志: $LOG_FILE"
NEW_HOSTNAME=''
CREATE_USER=0
RESET_PASSWORD=0
if [[ "$INTERACTIVE" == yes ]]; then
  select_identity
else
  log "无交互模式：保留主机名和密码，配置已有用户 $TARGET_USER。"
fi
if (( ! CREATE_USER )); then resolve_target_account; fi
log "目标开发用户: $TARGET_USER"

if (( ! SKIP_PACKAGES )); then
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
  apt_options=(-o DPkg::Lock::Timeout=180 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold
    -o 'Dpkg::Options::=--path-include=/usr/share/doc/fzf/*')
  apt-get "${apt_options[@]}" update
  # Some cloud images disable universe, which contains useful development tools.
  if ! apt-cache show zsh-autosuggestions >/dev/null 2>&1; then
    apt-get "${apt_options[@]}" install -y --no-install-recommends software-properties-common
    add-apt-repository -y universe
    apt-get "${apt_options[@]}" update
  fi
  packages=(
    ca-certificates git curl wget file unzip zip locales bsdutils sudo
    build-essential clang clangd clang-format clang-tidy cmake ninja-build
    gdb pkg-config man-db manpages-dev universal-ctags
    python3 python3-dev python3-pip python3-venv pipx
    vim zsh tmux ripgrep fzf shellcheck
    zsh-autosuggestions zsh-syntax-highlighting
  )
  apt-get "${apt_options[@]}" install -y --no-install-recommends "${packages[@]}"
  # Minimal cloud/container images often exclude /usr/share/doc via dpkg.
  # Ubuntu stores executable fzf Zsh integration there, so preserve these files
  # for this apt invocation only. Also repair an already-installed stripped fzf.
  if [[ ! -r /usr/share/doc/fzf/examples/key-bindings.zsh && ! -r /usr/share/fzf/key-bindings.zsh ]]; then
    apt-get "${apt_options[@]}" install -y --no-install-recommends --reinstall fzf
  fi
  if [[ $(apt-cache policy valgrind) == *'Candidate: (none)'* ]] || ! apt-cache show valgrind >/dev/null 2>&1; then
    log '当前架构/软件源无 valgrind；跳过此可选工具。'
  else
    apt-get "${apt_options[@]}" install -y --no-install-recommends valgrind
  fi
fi
for cmd in git zsh vim tmux python3 gcc g++ cmake ninja gdb clang clangd clang-format clang-tidy pkg-config pipx rg fzf ctags shellcheck runuser passwd useradd usermod hostname; do
  command -v "$cmd" >/dev/null || die "缺少 $cmd；去掉 --skip-packages 后重试。"
done
if [[ "$INTERACTIVE" == yes ]]; then apply_account; fi
resolve_target_account
if [[ -n "$NEW_HOSTNAME" ]]; then apply_hostname "$NEW_HOSTNAME"; fi
log "配置用户: $TARGET_USER，home: $TARGET_HOME"

# All third-party programs are installed by apt; no opaque remote install scripts.
# User files are written as the target user, not by following symlinks as root.
SHARE=/usr/local/share/linux-env
[[ ! -L "$SHARE" ]] || die "$SHARE 不应为符号链接。"
install -d -m 755 "$SHARE" /usr/local/bin
install -d -m 755 "$SHARE/config" "$SHARE/examples" "$SHARE/fzf"
# Keep a packaged fallback: a later apt upgrade may strip documentation again.
for integration in key-bindings.zsh completion.zsh; do
  for integration_dir in /usr/share/doc/fzf/examples /usr/share/fzf; do
    if [[ -r "$integration_dir/$integration" ]]; then
      install -m 644 "$integration_dir/$integration" "$SHARE/fzf/$integration"
      break
    fi
  done
done
[[ -r "$SHARE/fzf/key-bindings.zsh" ]] || die '缺少 fzf Zsh 集成脚本；去掉 --skip-packages 后重试。'
install -m 644 "$REPO_DIR"/config/* "$SHARE/config/"
cp -R "$REPO_DIR/examples/." "$SHARE/examples/"
chmod -R u=rwX,go=rX "$SHARE/config" "$SHARE/examples"
install -m 644 "$REPO_DIR/scripts/configure-home.sh" "$SHARE/configure-home.sh"
install -m 755 "$REPO_DIR/scripts/linux-env-doctor" /usr/local/bin/linux-env-doctor
install -m 755 "$REPO_DIR/scripts/linux-env-new" /usr/local/bin/linux-env-new
runuser -u "$TARGET_USER" -- env -i HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
  PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 TERM="${TERM:-xterm-256color}" \
  bash "$SHARE/configure-home.sh"

if (( CHANGE_SHELL )); then
  ZSH_BIN="$(command -v zsh)"
  grep -qxF "$ZSH_BIN" /etc/shells || printf '%s\n' "$ZSH_BIN" >> /etc/shells
  if [[ $(getent passwd "$TARGET_USER" | cut -d: -f7) != "$ZSH_BIN" ]]; then
    usermod -s "$ZSH_BIN" "$TARGET_USER"
  fi
fi

if (( ! SKIP_CHECKS )); then
  runuser -u "$TARGET_USER" -- env -i HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
    PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 TERM="${TERM:-xterm-256color}" \
    /usr/local/bin/linux-env-doctor
fi
log "安装完成。重新登录，或运行: su - $TARGET_USER"
log '创建项目: linux-env-new cpp ~/code/hello-cpp（也支持 c / python）'
log '以后自检: linux-env-doctor'
