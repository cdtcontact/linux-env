#!/bin/bash
#!/usr/bin/env bash

set -Eeuo pipefail

# 当前脚本自己的绝对路径，用于成功后自删除
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

REPO_URL="https://github.com/cdtcontact/linux-env.git"

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

TMP_DIR=""

cleanup() {
    if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}

trap cleanup EXIT


# ============================================================
# 必须使用 root
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] 请使用 root 用户执行：sudo -i${RESET}"
    exit 1
fi


# ============================================================
# 1. 更新软件源
# ============================================================

echo -e "${GREEN}[1/8] 更新软件源${RESET}"

apt-get update


# ============================================================
# 2. 安装开发环境
# ============================================================

echo -e "${GREEN}[2/8] 安装开发环境${RESET}"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    ca-certificates \
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


# 可选工具
# 某个软件在当前 Ubuntu 仓库不存在时，不影响主流程
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autojump \
    astyle \
    xclip \
    python3-setuptools || true


# ============================================================
# 主机名
# ============================================================

echo

while true; do

    read -r -p "请输入云主机名称（英文/数字/-）: " HOST_NAME

    if [[ "$HOST_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
        break
    fi

    echo -e "${RED}[ERROR] 主机名格式不正确，请重新输入${RESET}"

done


hostnamectl set-hostname "$HOST_NAME"


# 同步 /etc/hosts，避免 hostname 修改后 sudo 出现：
# unable to resolve host
if grep -qE '^[[:space:]]*127\.0\.1\.1[[:space:]]+' /etc/hosts; then

    sed -i -E \
        "s/^[[:space:]]*127\.0\.1\.1.*/127.0.1.1\t${HOST_NAME}/" \
        /etc/hosts

else

    printf '127.0.1.1\t%s\n' "$HOST_NAME" >> /etc/hosts

fi


echo -e "${GREEN}[OK] 主机名已修改为：${HOST_NAME}${RESET}"


# ============================================================
# 用户名
# ============================================================

echo

while true; do

    read -r -p "请输入用户名（小写英文开头）: " NEW_USER

    if [[ "$NEW_USER" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        break
    fi

    echo -e "${RED}[ERROR] 用户名格式不正确，请重新输入${RESET}"

done


# ============================================================
# 用户处理
#
# 重要：
# 已存在用户绝不删除
# 不删除 HOME
# 不重建用户
# ============================================================

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


# ============================================================
# 密码
# ============================================================

echo

while true; do

    read -r -s -p "请输入 ${NEW_USER} 的密码: " PASS1
    echo

    read -r -s -p "请再次输入密码: " PASS2
    echo

    if [[ "$PASS1" == "$PASS2" ]]; then
        break
    fi

    echo -e "${RED}[ERROR] 两次密码不一致，请重新输入${RESET}"
    echo

done


echo "${NEW_USER}:${PASS1}" | chpasswd

unset PASS1
unset PASS2


echo -e "${GREEN}[OK] 用户密码设置完成${RESET}"


# ============================================================
# SSH 密钥保护
#
# 规则：
#
# 1. 不删除 ~/.ssh
# 2. 已存在 authorized_keys 时绝不覆盖
# 3. 新用户优先继承 sudo 前用户的 authorized_keys
# 4. 如果没有 sudo 来源，再尝试 root
# ============================================================

install \
    -d \
    -m 700 \
    -o "$NEW_USER" \
    -g "$NEW_USER" \
    "${NEW_HOME}/.ssh"


if [[ -s "${NEW_HOME}/.ssh/authorized_keys" ]]; then

    echo -e "${GREEN}[OK] 已存在 authorized_keys，保持原样${RESET}"

else

    SOURCE_USER="${SUDO_USER:-}"
    SOURCE_HOME=""

    if [[ -n "$SOURCE_USER" && "$SOURCE_USER" != "root" ]]; then

        SOURCE_HOME="$(getent passwd "$SOURCE_USER" | cut -d: -f6 || true)"

    fi


    if [[ -n "$SOURCE_HOME" &&
          -s "${SOURCE_HOME}/.ssh/authorized_keys" ]]; then

        install \
            -m 600 \
            -o "$NEW_USER" \
            -g "$NEW_USER" \
            "${SOURCE_HOME}/.ssh/authorized_keys" \
            "${NEW_HOME}/.ssh/authorized_keys"

        echo -e "${GREEN}[OK] 已继承 ${SOURCE_USER} 的 SSH 公钥${RESET}"


    elif [[ -s "/root/.ssh/authorized_keys" ]]; then

        install \
            -m 600 \
            -o "$NEW_USER" \
            -g "$NEW_USER" \
            "/root/.ssh/authorized_keys" \
            "${NEW_HOME}/.ssh/authorized_keys"

        echo -e "${GREEN}[OK] 已继承 root 的 SSH 公钥${RESET}"


    else

        echo -e "${YELLOW}[WARN] 没有发现可继承的 authorized_keys${RESET}"

    fi

fi


chown -R \
    "${NEW_USER}:${NEW_USER}" \
    "${NEW_HOME}/.ssh"

chmod 700 \
    "${NEW_HOME}/.ssh"


if [[ -f "${NEW_HOME}/.ssh/authorized_keys" ]]; then

    chmod 600 \
        "${NEW_HOME}/.ssh/authorized_keys"

fi


# ============================================================
# 3. 下载自己的 GitHub 环境仓库
# ============================================================

echo -e "${GREEN}[3/8] 下载个人 Linux 环境${RESET}"

TMP_DIR="$(mktemp -d)"


git clone \
    --depth 1 \
    "$REPO_URL" \
    "${TMP_DIR}/linux-env"


# 检查关键配置
if [[ ! -f "${TMP_DIR}/linux-env/.vimrc" ||
      ! -f "${TMP_DIR}/linux-env/.zshrc" ||
      ! -d "${TMP_DIR}/linux-env/.vim" ]]; then

    echo -e "${RED}[ERROR] GitHub 环境文件不完整${RESET}"
    exit 1

fi


# ============================================================
# 4. 备份已有环境
# ============================================================

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


# ============================================================
# 5. 恢复 Vim
# ============================================================

echo -e "${GREEN}[5/8] 恢复 Vim 环境${RESET}"


mkdir -p \
    "${NEW_HOME}/.vim"


rsync -a \
    "${TMP_DIR}/linux-env/.vim/" \
    "${NEW_HOME}/.vim/"


cp \
    "${TMP_DIR}/linux-env/.vimrc" \
    "${NEW_HOME}/.vimrc"


# ============================================================
# 6. 配置 Zsh
# ============================================================

echo -e "${GREEN}[6/8] 配置 Zsh${RESET}"


if [[ ! -d "${NEW_HOME}/.oh-my-zsh" ]]; then

    sudo -u "$NEW_USER" \
        env HOME="$NEW_HOME" \
        git clone \
        --depth 1 \
        https://github.com/ohmyzsh/ohmyzsh.git \
        "${NEW_HOME}/.oh-my-zsh"

fi


ZSH_CUSTOM="${NEW_HOME}/.oh-my-zsh/custom"

mkdir -p \
    "${ZSH_CUSTOM}/plugins"


# zsh-syntax-highlighting
if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then

    sudo -u "$NEW_USER" \
        env HOME="$NEW_HOME" \
        git clone \
        --depth 1 \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

fi


# incr 自动补全插件
if [[ -f "${TMP_DIR}/linux-env/zsh/incr/incr.plugin.zsh" ]]; then

    mkdir -p \
        "${NEW_HOME}/.oh-my-zsh/plugins/incr"

    cp \
        "${TMP_DIR}/linux-env/zsh/incr/incr.plugin.zsh" \
        "${NEW_HOME}/.oh-my-zsh/plugins/incr/"

fi


# 恢复自己的 .zshrc
cp \
    "${TMP_DIR}/linux-env/.zshrc" \
    "${NEW_HOME}/.zshrc"


# ------------------------------------------------------------
# 保证 ll / la / l 存在
#
# 正常情况下 GitHub 的 .zshrc 已经包含这些配置。
# 这里只做兜底。
# ------------------------------------------------------------

if ! grep -q "^alias ll=" "${NEW_HOME}/.zshrc"; then

    printf "\n# Common ls aliases\n" >> "${NEW_HOME}/.zshrc"
    printf "alias ll='ls -alF'\n" >> "${NEW_HOME}/.zshrc"
    printf "alias la='ls -A'\n" >> "${NEW_HOME}/.zshrc"
    printf "alias l='ls -CF'\n" >> "${NEW_HOME}/.zshrc"

fi


# ============================================================
# 7. 配置 CTags
# ============================================================

echo -e "${GREEN}[7/8] 配置 CTags${RESET}"


CTAGS_PATH="$(command -v ctags || true)"


if [[ -n "$CTAGS_PATH" ]]; then

    ln -sf \
        "$CTAGS_PATH" \
        /usr/local/bin/ctags

fi


# systags 是自动生成文件
# 不上传 GitHub
#
# 此处由 root 生成，
# 最后统一 chown 给 NEW_USER。
if command -v ctags >/dev/null 2>&1; then

    ctags \
        --languages=C,C++ \
        -R \
        -f "${NEW_HOME}/.vim/systags" \
        /usr/include \
        /usr/local/include \
        >/dev/null 2>&1 || true

fi


# ============================================================
# 8. 修复权限
# ============================================================

echo -e "${GREEN}[8/8] 修复文件权限${RESET}"


chown -R \
    "${NEW_USER}:${NEW_USER}" \
    "${NEW_HOME}/.vim" \
    "${NEW_HOME}/.vimrc" \
    "${NEW_HOME}/.zshrc" \
    "${NEW_HOME}/.oh-my-zsh"


chmod 644 \
    "${NEW_HOME}/.vimrc"


chmod 644 \
    "${NEW_HOME}/.zshrc"


# SSH 权限最后再保险一次
chown -R \
    "${NEW_USER}:${NEW_USER}" \
    "${NEW_HOME}/.ssh"


chmod 700 \
    "${NEW_HOME}/.ssh"


if [[ -f "${NEW_HOME}/.ssh/authorized_keys" ]]; then

    chmod 600 \
        "${NEW_HOME}/.ssh/authorized_keys"

fi


# ============================================================
# 完成
# ============================================================

echo
echo -e "${GREEN}================================================${RESET}"
echo -e "${GREEN}[OK] Linux 开发环境配置完成${RESET}"
echo
echo "主机名：${HOST_NAME}"
echo "用户名：${NEW_USER}"
echo
echo "SSH authorized_keys 已保留/继承。"
echo "不会删除现有 SSH 登录密钥。"
echo
echo "请重新登录该用户，使 Zsh 和相关配置完全生效。"
echo -e "${GREEN}================================================${RESET}"


# ============================================================
# 成功后删除当前下载的 init_env.sh
#
# 如果脚本本身位于 Git 仓库中，则不删除，
# 避免把 ~/linux-env/init_env.sh 删除。
# ============================================================

SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"


if git -C "$SCRIPT_DIR" \
    rev-parse --is-inside-work-tree \
    >/dev/null 2>&1; then

    echo
    echo -e "${YELLOW}[INFO] init_env.sh 当前位于 Git 仓库中，不自动删除。${RESET}"

else

    echo
    echo -e "${GREEN}[OK] 配置全部成功，删除本地 init_env.sh${RESET}"

    rm -f -- "$SCRIPT_PATH"

fi
