#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf '%s\n' '== 文件体积超过 50 MiB =='
find payload archive -type f -size +50M -printf '%s bytes  %p\n' 2>/dev/null || true

printf '\n%s\n' '== 嵌套 Git 元数据（正常情况下应为空）=='
find payload -type d -name .git -print 2>/dev/null || true
find payload -type f -name .git -print 2>/dev/null || true

printf '\n%s\n' '== 可能的密钥/令牌/密码痕迹（请人工判断命中；不要直接发布敏感项）=='
grep -RInE --exclude='*.png' --exclude='*.jpg' --exclude='*.gif' \
  'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9]{20,}|password[[:space:]]*=[[:space:]]*[^[:space:]]+|token[[:space:]]*=[[:space:]]*[^[:space:]]+' \
  payload archive 2>/dev/null || true

printf '\n%s\n' '== 禁止提交的个人历史/缓存文件 ==' 
find payload -type f \( -name '.zsh_history' -o -name '.viminfo' -o -name '.zcompdump*' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name 'known_hosts' -o -name 'authorized_keys' \) -print 2>/dev/null || true

printf '\n%s\n' '== 文件统计 =='
find payload archive -type f 2>/dev/null | wc -l
 du -sh payload archive 2>/dev/null || true
