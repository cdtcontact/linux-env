#!/usr/bin/env bash
# Standalone entry point: download this file, then run it with Bash as root.
set -Eeuo pipefail

# This one value is platform-specific; shared configuration stays identical.
DEFAULT_SOURCE=github

usage() {
  cat <<'HELP'
Ubuntu C/C++ / Python 学习环境
用法: bash init_env.sh [--source gitee|github] [--user 已有用户名] [--no-change-shell]
                        [--skip-packages] [--skip-checks] [--help]
默认配置 sudo 调用者；直接 root 登录时配置 root。
--skip-packages  依赖已安装时使用；不会安装缺失的软件包
--skip-checks    跳过最后的编译和配置自检
入口默认使用其发布平台；--source 可手动切换来源。
LINUX_ENV_SOURCE / LINUX_ENV_REPO_URL / LINUX_ENV_REF 可指定来源、自定义仓库与版本。
HELP
  printf '当前入口默认来源: %s\n' "$DEFAULT_SOURCE"
}

SKIP_PACKAGES=0
SOURCE="${LINUX_ENV_SOURCE:-$DEFAULT_SOURCE}"
args=()
while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --source) [[ $# -ge 2 && "$2" != -* ]] || { usage >&2; exit 2; }; SOURCE="$2"; shift ;;
    --user) [[ $# -ge 2 && "$2" != -* ]] || { usage >&2; exit 2; }; args+=("$1" "$2"); shift ;;
    --skip-packages) SKIP_PACKAGES=1; args+=("$1") ;;
    --no-change-shell|--skip-checks) args+=("$1") ;;
    *) printf '未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
case "$SOURCE" in
  gitee) DEFAULT_REPO_URL=https://gitee.com/peacecdt/linux-env.git ;;
  github) DEFAULT_REPO_URL=https://github.com/cdtcontact/linux-env.git ;;
  *) printf '来源不合法: %s；可用 gitee / github。\n' "$SOURCE" >&2; exit 2 ;;
esac

[[ $EUID -eq 0 ]] || { printf '请使用 sudo -i 后运行此脚本。\n' >&2; exit 1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/scripts/install.sh" && -f "$SCRIPT_DIR/config/vimrc" ]]; then
  exec bash "$SCRIPT_DIR/scripts/install.sh" "${args[@]}"
fi

# Reject unsupported hosts before installing bootstrap dependencies.
[[ -r /etc/os-release ]] || { printf '无法读取 /etc/os-release。\n' >&2; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} =~ ^(22\.04|24\.04|26\.04)$ ]] || {
  printf '支持 Ubuntu 22.04 / 24.04 / 26.04 LTS；当前为 %s。\n' "${PRETTY_NAME:-unknown}" >&2
  exit 1
}

if (( ! SKIP_PACKAGES )); then
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
  apt-get -o DPkg::Lock::Timeout=180 update
  apt-get -o DPkg::Lock::Timeout=180 -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold install -y --no-install-recommends ca-certificates git
fi
command -v git >/dev/null || { printf '需要 git；请安装它或去掉 --skip-packages。\n' >&2; exit 1; }

REPO_URL="${LINUX_ENV_REPO_URL:-$DEFAULT_REPO_URL}"
REF="${LINUX_ENV_REF:-main}"
[[ -n "$REF" && "$REF" != -* ]] || { printf 'LINUX_ENV_REF 不合法。\n' >&2; exit 2; }
WORK_DIR="$(mktemp -d /tmp/linux-env.XXXXXXXX)"
trap 'rm -rf -- "$WORK_DIR"' EXIT
trap 'printf "安装入口失败（第 %s 行）。检查网络后可重新运行。\n" "$LINENO" >&2' ERR
printf '[linux-env] 获取配置仓库 %s (%s)\n' "$REPO_URL" "$REF"
# Partial + sparse checkout avoids downloading the archived 100+ MB plugin data.
git init -q "$WORK_DIR/repo"
git -C "$WORK_DIR/repo" remote add origin "$REPO_URL"
git -C "$WORK_DIR/repo" config remote.origin.promisor true
git -C "$WORK_DIR/repo" config remote.origin.partialclonefilter blob:none
GIT_TERMINAL_PROMPT=0 git -C "$WORK_DIR/repo" fetch --depth=1 --filter=blob:none origin "$REF"
git -C "$WORK_DIR/repo" sparse-checkout init --cone
git -C "$WORK_DIR/repo" sparse-checkout set config scripts examples
git -C "$WORK_DIR/repo" -c advice.detachedHead=false checkout --detach FETCH_HEAD
[[ -f "$WORK_DIR/repo/scripts/install.sh" ]] || { printf '仓库中缺少 scripts/install.sh。\n' >&2; exit 1; }
bash "$WORK_DIR/repo/scripts/install.sh" "${args[@]}"
