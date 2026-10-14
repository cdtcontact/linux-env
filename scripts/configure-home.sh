#!/usr/bin/env bash
# Called as the target user; keep every home write unprivileged.
set -Eeuo pipefail
umask 077
SHARE=/usr/local/share/linux-env
STATE="$HOME/.local/state/linux-env"
BACKUP_DIR="$STATE/backups/$(date +%Y%m%d-%H%M%S)-$$"
BACKED_UP=0

backup() {
  local path="$1" relative="${1#"$HOME/"}"
  if [[ -e "$path" || -L "$path" ]]; then
    mkdir -p -- "$BACKUP_DIR/$(dirname -- "$relative")"
    mv -- "$path" "$BACKUP_DIR/$relative"
    BACKED_UP=1
  fi
}

deploy() {
  local src="$1" dest="$2"
  # A symlink is backed up even if its destination happens to have the same bytes.
  if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s -- "$src" "$dest"; then return; fi
  backup "$dest"
  mkdir -p -- "$(dirname -- "$dest")"
  install -m 644 -- "$src" "$dest"
}

mkdir -p -- "$STATE" "$HOME/.config"
chmod 700 "$STATE"
# These are managed subdirectories; do not follow a pre-existing directory link.
if [[ -L "$HOME/.config/linux-env" || ( -e "$HOME/.config/linux-env" && ! -d "$HOME/.config/linux-env" ) ]]; then
  backup "$HOME/.config/linux-env"
fi
mkdir -p -- "$HOME/.config/linux-env"
deploy "$SHARE/config/vimrc" "$HOME/.vimrc"
deploy "$SHARE/config/zshrc" "$HOME/.zshrc"
deploy "$SHARE/config/tmux.conf" "$HOME/.tmux.conf"
deploy "$SHARE/config/gitconfig" "$HOME/.config/linux-env/gitconfig"
deploy "$SHARE/config/editorconfig" "$HOME/.config/linux-env/editorconfig"

# Add the include once, preserving existing identity and explicit Git settings.
INCLUDE_PATH="$HOME/.config/linux-env/gitconfig"
if ! git config --global --get-all include.path | grep -qxF "$INCLUDE_PATH"; then
  # Includes are evaluated in order. Put defaults first, so an existing editor,
  # pager, merge policy, etc. still wins. Respect Git's alternate global file.
  GLOBAL_CONFIG="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
  XDG_GIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
  if [[ -z ${GIT_CONFIG_GLOBAL:-} && ! -e "$HOME/.gitconfig" && -f "$XDG_GIT_CONFIG" ]]; then
    GLOBAL_CONFIG="$XDG_GIT_CONFIG"
  fi
  if [[ -e "$GLOBAL_CONFIG" || -L "$GLOBAL_CONFIG" ]]; then
    RELATIVE_CONFIG="${GLOBAL_CONFIG#"$HOME/"}"
    [[ "$RELATIVE_CONFIG" != /* ]] || RELATIVE_CONFIG=gitconfig-external
    mkdir -p -- "$BACKUP_DIR/$(dirname -- "$RELATIVE_CONFIG")"
    cp -P -- "$GLOBAL_CONFIG" "$BACKUP_DIR/$RELATIVE_CONFIG"
    BACKED_UP=1
  fi
  TMP_CONFIG="$(mktemp "${GLOBAL_CONFIG}.linux-env.XXXXXXXX")"
  trap 'rm -f -- "${TMP_CONFIG:-}"' EXIT
  git config --file "$TMP_CONFIG" --add include.path "$INCLUDE_PATH"
  if [[ -f "$GLOBAL_CONFIG" ]]; then cat -- "$GLOBAL_CONFIG" >> "$TMP_CONFIG"; fi
  mv -f -- "$TMP_CONFIG" "$GLOBAL_CONFIG"
fi

EXAMPLES="$HOME/code/linux-env-examples"
if [[ -L "$EXAMPLES" ]] || { [[ -e "$EXAMPLES" ]] && ! diff -qr "$SHARE/examples" "$EXAMPLES" >/dev/null 2>&1; }; then
  backup "$EXAMPLES"
fi
if [[ ! -d "$EXAMPLES" ]]; then
  mkdir -p -- "$HOME/code"
  cp -R -- "$SHARE/examples" "$EXAMPLES"
fi
if (( BACKED_UP )); then
  printf '[linux-env] 原配置已备份: %s\n' "$BACKUP_DIR"
fi
printf '[linux-env] 学习样例: %s\n' "$EXAMPLES"
