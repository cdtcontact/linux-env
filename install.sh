#!/usr/bin/env bash

set -e

echo "===== 1. 更新软件源 ====="
sudo apt update

echo "===== 2. 安装基础软件 ====="
sudo apt install -y \
  git \
  curl \
  wget \
  vim \
  zsh \
  gcc \
  g++ \
  make \
  gdb

echo "===== 3. 安装 Oh My Zsh ====="
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no \
    CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh 已存在，跳过安装"
fi

echo "===== 4. 下载自己的配置仓库 ====="

REPO_URL="https://github.com/cdtcontact/linux-env.git"
TMP_DIR="/tmp/linux-env"

rm -rf "$TMP_DIR"

git clone "$REPO_URL" "$TMP_DIR"

echo "===== 5. 安装配置文件 ====="

cp "$TMP_DIR/.zshrc" "$HOME/.zshrc"
cp "$TMP_DIR/.vimrc" "$HOME/.vimrc"

echo "===== 6. 修改默认 Shell ====="

ZSH_PATH="$(which zsh)"

if [ "$SHELL" != "$ZSH_PATH" ]; then
    sudo chsh -s "$ZSH_PATH" "$USER"
fi

echo "===== 安装完成 ====="
echo
echo "请退出 SSH 后重新登录："
echo "exit"
