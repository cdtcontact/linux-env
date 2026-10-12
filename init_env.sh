#!/usr/bin/env bash
# Bootstrap installer for cdtcontact/linux-env.
# Run as root. This script only installs files bundled in this repository;
# it does not download the teacher's old scripts or plugins from legacy hosts.
set -Eeuo pipefail

REPO_URL="${LINUX_ENV_REPO_URL:-https://gitee.com/peacecdt/linux-env.git}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR=""
WORK_DIR=""

log() { printf '\033[1;34m[linux-env]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

[[ "${EUID}" -eq 0 ]] || die "请使用 root 执行：sudo -i 后再运行。"
command -v apt-get >/dev/null 2>&1 || die "此安装脚本面向 Ubuntu/Debian（需要 apt-get）。"

export DEBIAN_FRONTEND=noninteractive
log "更新软件包索引并安装基础依赖。"
apt-get update
apt-get install -y ca-certificates git rsync vim zsh xclip astyle autojump build-essential wget curl file

# Optional packages vary by Ubuntu release. Install only when apt knows them.
if apt-cache show universal-ctags >/dev/null 2>&1; then
  apt-get install -y universal-ctags
elif apt-cache show exuberant-ctags >/dev/null 2>&1; then
  apt-get install -y exuberant-ctags
else
  warn "apt 源中没有找到 universal-ctags 或 exuberant-ctags；系统 tags 索引将跳过。"
fi
if apt-cache show python3-autopep8 >/dev/null 2>&1; then
  apt-get install -y python3-autopep8
fi

# If run from a checked-out repository, use its files. Otherwise clone the full
# repository because a raw init_env.sh download does not contain the payload.
if [[ -d "$SCRIPT_DIR/payload/home/.vim" && -f "$SCRIPT_DIR/payload/home/.vimrc" ]]; then
  REPO_DIR="$SCRIPT_DIR"
else
  WORK_DIR="$(mktemp -d /tmp/linux-env.XXXXXX)"
  log "正在克隆你的配置仓库：$REPO_URL"
  git clone --depth 1 "$REPO_URL" "$WORK_DIR/repo" || die "克隆失败。确认 GitHub 仓库已推送、公开可读，并且默认分支为 main。私有仓库请设置 LINUX_ENV_REPO_URL 并配置凭据。"
  REPO_DIR="$WORK_DIR/repo"
fi

PAYLOAD="$REPO_DIR/payload/home"
for item in .vim .vimrc .zshrc .oh-my-zsh; do
  [[ -e "$PAYLOAD/$item" ]] || die "缺少 payload/home/$item。请先在原来已配置好的主机运行 scripts/collect_teacher_config.sh，将配置收集进仓库后再 push。"
done
[[ -f "$PAYLOAD/.oh-my-zsh/oh-my-zsh.sh" ]] || die "payload/home/.oh-my-zsh/oh-my-zsh.sh 不存在；Oh My Zsh 目录未收集完整。"

# Optional hostname setup, deliberately separate from the /etc/hosts rewrite in
# the old script, which was brittle on modern Ubuntu and on non-eth0 machines.
read -r -p "是否设置这台机器的主机名？[y/N] " SET_HOSTNAME
if [[ "$SET_HOSTNAME" =~ ^[Yy]$ ]]; then
  read -r -p "请输入纯英文主机名（字母开头，可含数字和连字符）：" NEW_HOSTNAME
  [[ "$NEW_HOSTNAME" =~ ^[A-Za-z][A-Za-z0-9-]{0,62}$ ]] || die "主机名格式不合法。"
  hostnamectl set-hostname "$NEW_HOSTNAME"
  log "主机名已设置为 $NEW_HOSTNAME（未覆盖 /etc/hosts）。"
fi

read -r -p "请输入要配置的普通用户名（可为新用户，也可为已有用户）：" TARGET_USER
[[ "$TARGET_USER" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] || die "用户名格式不合法，只允许英文字母开头及字母、数字、下划线、连字符。"
[[ "$TARGET_USER" != root ]] || die "请勿将 root 作为编程环境用户。"

if getent passwd "$TARGET_USER" >/dev/null 2>&1; then
  log "用户 $TARGET_USER 已存在，将配置该用户；不会删除或重建用户。"
  CREATED_USER=0
else
  read -r -s -p "请为新用户 $TARGET_USER 设置密码：" USER_PASSWORD; printf '\n'
  [[ -n "$USER_PASSWORD" ]] || die "密码不能为空。"
  read -r -s -p "请再次输入密码：" USER_PASSWORD_CONFIRM; printf '\n'
  [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]] || die "两次密码不一致。"
  useradd -m -s /usr/bin/zsh -G sudo "$TARGET_USER"
  printf '%s:%s\n' "$TARGET_USER" "$USER_PASSWORD" | chpasswd
  unset USER_PASSWORD USER_PASSWORD_CONFIRM
  CREATED_USER=1
  log "已创建用户 $TARGET_USER，并加入 sudo 组。sudo 仍需输入该用户密码。"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" && "$TARGET_HOME" != /root && -d "$TARGET_HOME" ]] || die "无法确认目标用户的安全家目录。"
TARGET_GROUP="$(id -gn "$TARGET_USER")"

# Preserve the original SSH login public key when making a new account. Never
# copy a private key and never overwrite an existing authorized_keys file.
if [[ "$CREATED_USER" -eq 1 ]]; then
  CALLER_USER="${SUDO_USER:-}"
  if [[ -n "$CALLER_USER" && "$CALLER_USER" != root ]] && getent passwd "$CALLER_USER" >/dev/null 2>&1; then
    CALLER_HOME="$(getent passwd "$CALLER_USER" | cut -d: -f6)"
    if [[ -f "$CALLER_HOME/.ssh/authorized_keys" && ! -e "$TARGET_HOME/.ssh/authorized_keys" ]]; then
      install -d -m 700 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.ssh"
      install -m 600 -o "$TARGET_USER" -g "$TARGET_GROUP" "$CALLER_HOME/.ssh/authorized_keys" "$TARGET_HOME/.ssh/authorized_keys"
      log "已复制调用者的 SSH 登录公钥文件到新用户；未复制任何私钥。"
    else
      warn "没有自动复制 SSH 公钥（源文件不存在，或目标已有 authorized_keys）。请确认你知道如何登录新用户。"
    fi
  else
    warn "未识别到原登录用户，未自动复制 SSH 公钥。请在退出原会话前测试新用户登录。"
  fi
fi

# Back up only the paths this installer is about to replace.
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$TARGET_HOME/.linux-env-backup-$STAMP"
BACKUP_CREATED=0
for item in .vim .vimrc .zshrc .oh-my-zsh; do
  if [[ -e "$TARGET_HOME/$item" || -L "$TARGET_HOME/$item" ]]; then
    if [[ "$BACKUP_CREATED" -eq 0 ]]; then
      install -d -m 700 -o "$TARGET_USER" -g "$TARGET_GROUP" "$BACKUP_DIR"
      BACKUP_CREATED=1
    fi
    mv -- "$TARGET_HOME/$item" "$BACKUP_DIR/$item"
  fi
done
if [[ "$BACKUP_CREATED" -eq 1 ]]; then
  log "旧配置已备份到 $BACKUP_DIR"
fi

cp -a "$PAYLOAD/.vim" "$TARGET_HOME/.vim"
cp -a "$PAYLOAD/.vimrc" "$TARGET_HOME/.vimrc"
cp -a "$PAYLOAD/.zshrc" "$TARGET_HOME/.zshrc"
cp -a "$PAYLOAD/.oh-my-zsh" "$TARGET_HOME/.oh-my-zsh"
chown -R "$TARGET_USER:$TARGET_GROUP" \
  "$TARGET_HOME/.vim" "$TARGET_HOME/.vimrc" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.oh-my-zsh"

read -r -p "是否将 $TARGET_USER 的默认登录 Shell 改为 zsh？[Y/n] " CHANGE_SHELL
if [[ ! "$CHANGE_SHELL" =~ ^[Nn]$ ]]; then
  ZSH_BIN="$(command -v zsh)"
  grep -qxF "$ZSH_BIN" /etc/shells || printf '%s\n' "$ZSH_BIN" >> /etc/shells
  usermod -s "$ZSH_BIN" "$TARGET_USER"
  log "默认 Shell 已设置为 $ZSH_BIN。"
fi

# Regenerate system-header tags on this machine; this file is machine-specific
# and intentionally should not be stored in GitHub.
if command -v ctags >/dev/null 2>&1; then
  TAG_DIRS=()
  [[ -d /usr/include ]] && TAG_DIRS+=(/usr/include)
  [[ -d /usr/local/include ]] && TAG_DIRS+=(/usr/local/include)
  if [[ ${#TAG_DIRS[@]} -gt 0 ]]; then
    log "正在生成本机系统头文件索引 ~/.vim/systags（可能需要一些时间）。"
    if ! runuser -u "$TARGET_USER" -- ctags \
      -I __THROW -I __attribute_pure__ -I __nonnull -I __attribute__ \
      --file-scope=yes --langmap=c:+.h --languages=c,c++ --links=yes \
      --c-kinds=+p --c++-kinds=+p --fields=+iaS --extra=+q \
      -R -f "$TARGET_HOME/.vim/systags" "${TAG_DIRS[@]}"; then
      warn "系统 tags 索引生成失败，但不会回滚已经安装的配置。"
    else
      chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.vim/systags"
    fi
  fi
fi

# The old checker is an opaque legacy binary/script. Install only after explicit
# consent, and into /usr/local/bin rather than replacing anything under /usr/bin.
if [[ -f "$REPO_DIR/payload/bin/isoftstone_check" ]]; then
  log "发现旧版 isoftstone_check："
  file "$REPO_DIR/payload/bin/isoftstone_check" || true
  read -r -p "是否将该旧版命令安装到 /usr/local/bin/isoftstone_check？[y/N] " INSTALL_CHECKER
  if [[ "$INSTALL_CHECKER" =~ ^[Yy]$ ]]; then
    install -m 755 "$REPO_DIR/payload/bin/isoftstone_check" /usr/local/bin/isoftstone_check
    log "已安装 /usr/local/bin/isoftstone_check。若它是旧架构二进制，仍可能需要重新编译或弃用。"
  fi
fi

log "配置文件安装完成。请先在当前会话中测试：su - $TARGET_USER，然后运行 zsh 和 vim。"
log "确认新用户 SSH 登录正常后，再关闭当前管理员会话。"
log "此脚本不会删除用户，不会复制 SSH 私钥，也不会修改 sudoers 为免密码 sudo。"
