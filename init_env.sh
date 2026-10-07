#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Linux C/C++ Learning Environment Initializer
# Compatible with modern Ubuntu / Debian based systems
# ============================================================

# ---------- 基础颜色 ----------
setup_color() {
    if [[ -t 1 ]]; then
        RED='\033[31m'
        GREEN='\033[32m'
        YELLOW='\033[33m'
        BLUE='\033[34m'
        BOLD='\033[1m'
        RESET='\033[0m'
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        BOLD=''
        RESET=''
    fi
}

setup_color

info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

die() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
    exit 1
}

# ---------- 必须 root ----------
if [[ "${EUID}" -ne 0 ]]; then
    die "请先执行 sudo -i，然后再运行本脚本"
fi

# ---------- 系统检查 ----------
if [[ ! -r /etc/os-release ]]; then
    die "无法识别当前 Linux 系统"
fi

source /etc/os-release

case "${ID:-}" in
    ubuntu|debian)
        ;;
    *)
        die "当前脚本主要支持 Ubuntu / Debian，检测到：${ID:-unknown}"
        ;;
esac

info "当前系统：${PRETTY_NAME}"

# ============================================================
# 1. SSH 保活
# ============================================================

info "配置 SSH 保活..."

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-learning-env.conf <<'EOF'
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

if /usr/sbin/sshd -t; then
    if systemctl list-unit-files | grep -q '^ssh\.service'; then
        systemctl reload ssh
    elif systemctl list-unit-files | grep -q '^sshd\.service'; then
        systemctl reload sshd
    fi

    ok "SSH 保活配置完成"
else
    rm -f /etc/ssh/sshd_config.d/99-learning-env.conf
    die "SSH 配置检测失败，已撤销修改"
fi

# ============================================================
# 2. 更新软件源
# ============================================================

info "更新软件源..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

# 不自动 full-upgrade，避免初始化脚本无意升级大量系统组件。
# 如果需要完整升级，可自行执行：
# apt upgrade -y

# ============================================================
# 3. 安装开发环境
# ============================================================

info "安装 C/C++ / Git / Vim / Zsh 开发工具..."

BASE_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    vim
    zsh
    gcc
    g++
    make
    gdb
    python3
    python3-pip
)

apt-get install -y "${BASE_PACKAGES[@]}"

# 某些系统可能没有这些包，因此单独判断
OPTIONAL_PACKAGES=(
    libc6-doc
    autojump
    universal-ctags
)

for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        apt-get install -y "$pkg"
    else
        warn "当前系统没有软件包：$pkg，已跳过"
    fi
done

ok "基础开发工具安装完成"

# ============================================================
# 4. 设置主机名
# ============================================================

HOST_REGEX='^[a-zA-Z][a-zA-Z0-9-]{0,62}$'

while true; do
    read -r -p "$(echo -e "请输入云主机名称 ${YELLOW}(英文/数字/-)${RESET}: ")" HOST_NAME

    if [[ "${HOST_NAME}" =~ ${HOST_REGEX} ]]; then
        break
    fi

    echo -e "${RED}主机名格式不正确，请重新输入${RESET}"
done

hostnamectl set-hostname "${HOST_NAME}"

# 使用 hostname -I / ip，不再依赖旧的 ifconfig eth0。
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"

if [[ -n "${HOST_IP}" ]]; then

    # 删除同 IP 的旧记录
    sed -i "\|^${HOST_IP}[[:space:]]|d" /etc/hosts

    echo -e "${HOST_IP}\t${HOST_NAME}" >> /etc/hosts

else
    warn "没有检测到主机 IP，跳过 /etc/hosts 修改"
fi

ok "主机名已修改为：${HOST_NAME}"

# ============================================================
# 5. 创建/配置普通用户
# ============================================================

USER_REGEX='^[a-z][a-z0-9_-]{0,31}$'

while true; do
    read -r -p "$(echo -e "请输入用户名 ${YELLOW}(小写英文开头)${RESET}: ")" NEW_USER

    if [[ "${NEW_USER}" =~ ${USER_REGEX} ]]; then
        break
    fi

    echo -e "${RED}用户名格式不正确，请重新输入${RESET}"
done

# 不再 userdel！
if id "${NEW_USER}" >/dev/null 2>&1; then

    warn "用户 ${NEW_USER} 已存在，不删除、不重建"
    usermod -aG sudo "${NEW_USER}"

else

    useradd \
        --create-home \
        --shell /bin/bash \
        --groups sudo \
        "${NEW_USER}"

    ok "用户 ${NEW_USER} 创建完成"
fi

# ============================================================
# 6. 设置密码
# ============================================================

while true; do

    echo -ne "请输入 ${BLUE}${NEW_USER}${RESET} 的密码: "
    read -rs USER_PASSWORD
    echo

    echo -n "请再次输入密码: "
    read -rs USER_PASSWORD_CONFIRM
    echo

    if [[ -z "${USER_PASSWORD}" ]]; then
        echo -e "${RED}密码不能为空${RESET}"
        continue
    fi

    if [[ "${USER_PASSWORD}" != "${USER_PASSWORD_CONFIRM}" ]]; then
        echo -e "${RED}两次密码输入不一致${RESET}"
        continue
    fi

    break
done

echo "${NEW_USER}:${USER_PASSWORD}" | chpasswd

ok "用户密码设置完成"

# 尽量减少密码在 Shell 中停留时间
unset USER_PASSWORD
unset USER_PASSWORD_CONFIRM

# ============================================================
# 7. 保留当前云服务器 SSH 公钥
# ============================================================

NEW_HOME="$(getent passwd "${NEW_USER}" | cut -d: -f6)"

mkdir -p "${NEW_HOME}/.ssh"
chmod 700 "${NEW_HOME}/.ssh"

# sudo -i 进入 root 时通常可以拿到原登录用户
SOURCE_USER="${SUDO_USER:-}"

if [[ -n "${SOURCE_USER}" && "${SOURCE_USER}" != "root" ]]; then

    SOURCE_HOME="$(getent passwd "${SOURCE_USER}" | cut -d: -f6 || true)"

    if [[ -f "${SOURCE_HOME}/.ssh/authorized_keys" ]]; then

        cp "${SOURCE_HOME}/.ssh/authorized_keys" \
           "${NEW_HOME}/.ssh/authorized_keys"

        ok "已从 ${SOURCE_USER} 复制 SSH 公钥给 ${NEW_USER}"
    fi
fi

# 如果 root 自己有 authorized_keys，也可作为兜底
if [[ ! -f "${NEW_HOME}/.ssh/authorized_keys" ]] &&
   [[ -f /root/.ssh/authorized_keys ]]; then

    cp /root/.ssh/authorized_keys \
       "${NEW_HOME}/.ssh/authorized_keys"

    ok "已从 root 复制 SSH 公钥"
fi

if [[ -f "${NEW_HOME}/.ssh/authorized_keys" ]]; then
    chmod 600 "${NEW_HOME}/.ssh/authorized_keys"
fi

chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.ssh"

# ============================================================
# 8. 安装 Oh My Zsh
# ============================================================

info "安装 Oh My Zsh..."

if [[ ! -d "${NEW_HOME}/.oh-my-zsh" ]]; then

    sudo -u "${NEW_USER}" \
        HOME="${NEW_HOME}" \
        RUNZSH=no \
        CHSH=no \
        sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

else
    warn "Oh My Zsh 已存在，跳过安装"
fi

# ============================================================
# 9. 下载自己的 GitHub 配置
# ============================================================

CONFIG_REPO="https://github.com/cdtcontact/linux-env.git"
TMP_CONFIG_DIR="/tmp/linux-env-${NEW_USER}"

info "下载个人 Linux 配置..."

rm -rf "${TMP_CONFIG_DIR}"

git clone --depth 1 "${CONFIG_REPO}" "${TMP_CONFIG_DIR}"

if [[ -f "${TMP_CONFIG_DIR}/.zshrc" ]]; then
    cp "${TMP_CONFIG_DIR}/.zshrc" "${NEW_HOME}/.zshrc"
fi

if [[ -f "${TMP_CONFIG_DIR}/.vimrc" ]]; then
    cp "${TMP_CONFIG_DIR}/.vimrc" "${NEW_HOME}/.vimrc"
fi

chown "${NEW_USER}:${NEW_USER}" \
    "${NEW_HOME}/.zshrc" \
    "${NEW_HOME}/.vimrc" 2>/dev/null || true

rm -rf "${TMP_CONFIG_DIR}"

# ============================================================
# 10. 修改默认 Shell
# ============================================================

ZSH_PATH="$(command -v zsh)"

usermod --shell "${ZSH_PATH}" "${NEW_USER}"

ok "默认 Shell 已设置为 ${ZSH_PATH}"

# ============================================================
# 11. sudo 权限
# ============================================================

# 不直接 sed /etc/sudoers
# 不修改全局 sudo 组
#
# 如果以后确实需要免密 sudo，可以单独创建：
#
# /etc/sudoers.d/90-peacecdt
#
# 并用 visudo 验证。
#
# 默认仍然保留系统安全策略。

if command -v visudo >/dev/null 2>&1; then
    visudo -c >/dev/null
fi

# ============================================================
# 12. 完成
# ============================================================

echo
echo -e "${GREEN}${BOLD}========================================${RESET}"
echo -e "${GREEN}${BOLD} Linux 环境配置完成${RESET}"
echo -e "${GREEN}${BOLD}========================================${RESET}"
echo
echo -e "主机名：${BLUE}${HOST_NAME}${RESET}"
echo -e "用户名：${BLUE}${NEW_USER}${RESET}"
echo
echo "已经安装："
echo "  - gcc / g++"
echo "  - make"
echo "  - gdb"
echo "  - git"
echo "  - vim"
echo "  - zsh"
echo "  - Oh My Zsh"
echo "  - Python 3"
echo
echo -e "${YELLOW}请退出当前 SSH，然后使用新用户重新连接。${RESET}"
echo
echo "例如："
echo
echo "ssh ${NEW_USER}@服务器IP"
echo
