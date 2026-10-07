#!/usr/bin/env bash

set -Eeuo pipefail

REPO_URL="https://github.com/cdtcontact/linux-env.git"

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] 请使用 root 用户执行：sudo -i${RESET}"
    exit 1
fi

echo -e "${GREEN}[1/8] 更新软件源${RESET}"
apt-get update

echo -e "${GREEN}[2/8] 安装开发环境${RESET}"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    zsh \
    vim \
    gcc \
    g++ \
    gdb \
    make \
    cmake \
    universal-ctags \
    curl \
    wget \
    rsync \
    python3 \
    python3-pip

# 可选工具，某个不存在也不影响主流程
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autojump \
    astyle \
    xclip \
    python3-setuptools || true


echo
read -r -p "请输入云主机名称（英文/数字/-）: " HOST_NAME

if [[ ! "$HOST_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    echo -e "${RED}[ERROR] 主机名格式不正确${RESET}"
    exit 1
fi

hostnamectl set-hostname "$HOST_NAME"

echo -e "${GREEN}[OK] 主机名已修改为：${HOST_NAME}${RESET}"


echo
read -r -p "请输入用户名（小写英文开头）: " NEW_USER

if [[ ! "$NEW_USER" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    echo -e "${RED}[ERROR] 用户名格式不正确${RESET}"
    exit 1
fi


# ------------------------------------------------------------
# 用户处理
# ------------------------------------------------------------

if id "$NEW_USER" >/dev/null 2>&1; then

    echo -e "${YELLOW}[WARN] 用户 ${NEW_USER} 已存在，不删除、不重建${RESET}"

    NEW_HOME="$(getent passwd "$NEW_USER" | cut -d: -f6)"

else

    echo -e "${GREEN}[INFO] 创建用户 ${NEW_USER}${RESET}"

    useradd \
        -m \
        -s /usr/bin/zsh \
        -G sudo \
        "$NEW_USER"

    NEW_HOME="$(getent passwd "$NEW_USER" | cut -d: -f6)"
fi


usermod -aG sudo "$NEW_USER"

if [[ -x /usr/bin/zsh ]]; then
    chsh -s /usr/bin/zsh "$NEW_USER"
fi


# ------------------------------------------------------------
# 密码
# ------------------------------------------------------------

echo
read -r -s -p "请输入 ${NEW_USER} 的密码: " PASS1
echo
read -r -s -p "请再次输入密码: " PASS2
echo

if [[ "$PASS1" != "$PASS2" ]]; then
    echo -e "${RED}[ERROR] 两次密码不一致${RESET}"
    exit 1
fi

echo "${NEW_USER}:${PASS1}" | chpasswd

unset PASS1
unset PASS2

echo -e "${GREEN}[OK] 用户密码设置完成${RESET}"


# ------------------------------------------------------------
# SSH 密钥保护
#
# 非常重要：
# 不删除用户 HOME
# 不删除 ~/.ssh
# 已存在 authorized_keys 时绝不覆盖
# ------------------------------------------------------------

mkdir -p "${NEW_HOME}/.ssh"

if [[ -s "${NEW_HOME}/.ssh/authorized_keys" ]]; then

    echo -e "${GREEN}[OK] 已存在 authorized_keys，保持原样${RESET}"

else

    SOURCE_USER="${SUDO_USER:-}"

    if [[ -n "$SOURCE_USER" &&
          "$SOURCE_USER" != "root" &&
          -s "/home/${SOURCE_USER}/.ssh/authorized_keys" ]]; then

        cp \
          "/home/${SOURCE_USER}/.ssh/authorized_keys" \
          "${NEW_HOME}/.ssh/authorized_keys"

        echo -e "${GREEN}[OK] 已继承 ${SOURCE_USER} 的 SSH 公钥${RESET}"

    else

        echo -e "${YELLOW}[WARN] 没有发现可继承的 authorized_keys${RESET}"

    fi
fi

chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.ssh"
chmod 700 "${NEW_HOME}/.ssh"

if [[ -f "${NEW_HOME}/.ssh/authorized_keys" ]]; then
    chmod 600 "${NEW_HOME}/.ssh/authorized_keys"
fi


# ------------------------------------------------------------
# 下载自己的环境仓库
# ------------------------------------------------------------

echo -e "${GREEN}[3/8] 下载个人 Linux 环境${RESET}"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

git clone --depth 1 \
    "$REPO_URL" \
    "${TMP_DIR}/linux-env"


if [[ ! -f "${TMP_DIR}/linux-env/.vimrc" ||
      ! -f "${TMP_DIR}/linux-env/.zshrc" ||
      ! -d "${TMP_DIR}/linux-env/.vim" ]]; then

    echo -e "${RED}[ERROR] GitHub 环境文件不完整${RESET}"
    exit 1
fi


# ------------------------------------------------------------
# 备份旧配置
# ------------------------------------------------------------

echo -e "${GREEN}[4/8] 备份已有环境${RESET}"

STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ -e "${NEW_HOME}/.vimrc" ]]; then
    cp -a \
      "${NEW_HOME}/.vimrc" \
      "${NEW_HOME}/.vimrc.bak.${STAMP}"
fi

if [[ -e "${NEW_HOME}/.zshrc" ]]; then
    cp -a \
      "${NEW_HOME}/.zshrc" \
      "${NEW_HOME}/.zshrc.bak.${STAMP}"
fi

if [[ -d "${NEW_HOME}/.vim" ]]; then
    mv \
      "${NEW_HOME}/.vim" \
      "${NEW_HOME}/.vim.bak.${STAMP}"
fi


# ------------------------------------------------------------
# 恢复 Vim
# ------------------------------------------------------------

echo -e "${GREEN}[5/8] 恢复 Vim 环境${RESET}"

mkdir -p "${NEW_HOME}/.vim"

rsync -a \
    "${TMP_DIR}/linux-env/.vim/" \
    "${NEW_HOME}/.vim/"

cp \
    "${TMP_DIR}/linux-env/.vimrc" \
    "${NEW_HOME}/.vimrc"


# ------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------

echo -e "${GREEN}[6/8] 配置 Zsh${RESET}"

if [[ ! -d "${NEW_HOME}/.oh-my-zsh" ]]; then

    sudo -u "$NEW_USER" \
        HOME="$NEW_HOME" \
        git clone --depth 1 \
        https://github.com/ohmyzsh/ohmyzsh.git \
        "${NEW_HOME}/.oh-my-zsh"
fi


ZSH_CUSTOM="${NEW_HOME}/.oh-my-zsh/custom"

mkdir -p "${ZSH_CUSTOM}/plugins"

if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then

    sudo -u "$NEW_USER" \
        HOME="$NEW_HOME" \
        git clone --depth 1 \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
fi


# incr 插件
if [[ -f "${TMP_DIR}/linux-env/zsh/incr/incr.plugin.zsh" ]]; then

    mkdir -p "${NEW_HOME}/.oh-my-zsh/plugins/incr"

    cp \
      "${TMP_DIR}/linux-env/zsh/incr/incr.plugin.zsh" \
      "${NEW_HOME}/.oh-my-zsh/plugins/incr/"
fi


cp \
    "${TMP_DIR}/linux-env/.zshrc" \
    "${NEW_HOME}/.zshrc"


# ------------------------------------------------------------
# ctags
# ------------------------------------------------------------

echo -e "${GREEN}[7/8] 配置 CTags${RESET}"

CTAGS_PATH="$(command -v ctags || true)"

if [[ -n "$CTAGS_PATH" ]]; then
    ln -sf "$CTAGS_PATH" /usr/local/bin/ctags
fi


# systags 属于生成文件，不上传 GitHub
if command -v ctags >/dev/null 2>&1; then

    sudo -u "$NEW_USER" \
        HOME="$NEW_HOME" \
        ctags \
        --languages=C,C++ \
        -R \
        -f "${NEW_HOME}/.vim/systags" \
        /usr/include \
        /usr/local/include \
        >/dev/null 2>&1 || true
fi


# ------------------------------------------------------------
# 权限
# ------------------------------------------------------------

echo -e "${GREEN}[8/8] 修复文件权限${RESET}"

chown -R \
    "${NEW_USER}:${NEW_USER}" \
    "${NEW_HOME}/.vim" \
    "${NEW_HOME}/.vimrc" \
    "${NEW_HOME}/.zshrc" \
    "${NEW_HOME}/.oh-my-zsh"

chmod 644 "${NEW_HOME}/.vimrc"
chmod 644 "${NEW_HOME}/.zshrc"


echo
echo -e "${GREEN}==============================================${RESET}"
echo -e "${GREEN}[OK] Linux 开发环境配置完成${RESET}"
echo
echo "主机名：${HOST_NAME}"
echo "用户名：${NEW_USER}"
echo
echo "SSH authorized_keys 已保留/继承。"
echo "不会删除现有 SSH 登录密钥。"
echo -e "${GREEN}==============================================${RESET}"
EOF
