#!/usr/bin/env bash
# Sourced by install.sh. Passwords are handled only by passwd on /dev/tty.

valid_hostname() { local LC_ALL=C; [[ $1 =~ ^[A-Za-z]{1,63}$ ]]; }
valid_new_username() { local LC_ALL=C; [[ $1 =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; }

read_identity_answer() {
  printf '%s' "$1" >&"$TTY_FD"
  IFS= read -r -u "$TTY_FD" "$2" || die '交互输入已结束；安装停止，可重新运行。'
}

select_identity() {
  local answer candidate entry uid current_hostname
  NEW_HOSTNAME=''
  CREATE_USER=0
  RESET_PASSWORD=0
  current_hostname="$(cat /proc/sys/kernel/hostname)"
  printf '\n[linux-env] 设置主机名和开发账号（已有文件与账号会保留）。\n' >&"$TTY_FD"
  while true; do
    read_identity_answer "请输入主机名（纯英文字母，回车保留 $current_hostname）：" answer
    [[ -n "$answer" ]] || break
    if valid_hostname "$answer"; then
      # shellcheck disable=SC2034 # Returned to install.sh through sourced state.
      NEW_HOSTNAME="${answer,,}"
      break
    fi
    printf '主机名只允许 1–63 个英文字母，不能含数字、空格或符号。\n' >&"$TTY_FD"
  done
  while true; do
    read_identity_answer "请输入开发用户名（回车使用 $TARGET_USER；输入新用户名会创建账号）：" candidate
    candidate="${candidate:-$TARGET_USER}"
    if [[ ! "$candidate" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ ]]; then
      printf '用户名格式不合法。\n' >&"$TTY_FD"
      continue
    fi
    if entry="$(getent passwd "$candidate")"; then
      IFS=: read -r _ _ uid _ _ _ _ <<< "$entry"
      if [[ "$candidate" != root && "$uid" -lt 1000 ]]; then
        printf '不能配置系统服务账号，请选择普通用户。\n' >&"$TTY_FD"
        continue
      fi
      TARGET_USER="$candidate"
      break
    fi
    if ! valid_new_username "$candidate"; then
      printf '新用户名需小写字母开头，可含数字、下划线、连字符，最长 32 个字符。\n' >&"$TTY_FD"
      continue
    fi
    if [[ -e "/home/$candidate" || -L "/home/$candidate" ]]; then
      printf '/home/%s 已存在；为保留旧文件，请选择其他用户名或先处理该目录。\n' "$candidate" >&"$TTY_FD"
      continue
    fi
    TARGET_USER="$candidate"
    CREATE_USER=1
    RESET_PASSWORD=1
    break
  done
  if (( ! CREATE_USER )); then
    while true; do
      read_identity_answer "用户 $TARGET_USER 已存在，是否修改密码？[y/N]：" answer
      case "$answer" in
        y|Y) RESET_PASSWORD=1; break ;;
        ''|n|N) break ;;
        *) printf '请输入 y 或 n。\n' >&"$TTY_FD" ;;
      esac
    done
    if [[ $(passwd -S "$TARGET_USER" | awk '{print $2}') == L && $RESET_PASSWORD == 0 ]]; then
      log "提示：$TARGET_USER 的密码目前处于锁定状态，本次保留；需要密码登录时请重新运行并选择设置密码。"
    fi
  fi
}

apply_account() {
  if (( CREATE_USER )); then
    getent group sudo >/dev/null || die '缺少 sudo 组；请先安装 sudo，或去掉 --skip-packages。'
    [[ ! -e "/home/$TARGET_USER" && ! -L "/home/$TARGET_USER" ]] || die '目标 home 已存在，未接管该目录。'
    useradd --create-home --user-group --shell /bin/bash -- "$TARGET_USER"
    log "已创建普通用户 $TARGET_USER。请设置密码（输入不会显示）。"
  fi
  if (( RESET_PASSWORD )); then
    # Never read passwords into shell variables, argv, environment, or tee logs.
    if ! passwd "$TARGET_USER" </dev/tty >/dev/tty 2>/dev/tty; then
      if (( CREATE_USER )); then
        passwd --lock "$TARGET_USER" >/dev/null
        die "用户 $TARGET_USER 已创建，但密码设置未完成；账号保持锁定且未加入 sudo 组。管理员可运行：passwd $TARGET_USER && usermod -aG sudo $TARGET_USER，成功后再运行安装脚本。"
      fi
      die '密码修改未完成；安装停止，请重新运行。'
    fi
  fi
  if (( CREATE_USER )); then
    usermod --append --groups sudo "$TARGET_USER"
    log "用户 $TARGET_USER 已加入 sudo 组，sudo 仍需输入该用户密码。"
    log '新账号未复制 SSH 密钥；设置密码不会更改云主机的 SSH 密码登录策略。'
  fi
}

apply_hostname() {
  local name="$1" system_root="${2:-}" backup_dir hosts_tmp file
  valid_hostname "$name" || die '主机名只允许 1–63 个英文字母。'
  name="${name,,}"
  [[ -f "$system_root/etc/hosts" ]] || die '缺少 /etc/hosts，未修改主机名。'
  install -d -m 700 "$system_root/var/backups/linux-env"
  backup_dir="$(mktemp -d "$system_root/var/backups/linux-env/hostname-$(date +%Y%m%d-%H%M%S).XXXXXXXX")"
  for file in hostname hosts; do
    if [[ -f "$system_root/etc/$file" ]]; then
      cp -p -- "$system_root/etc/$file" "$backup_dir/$file"
    fi
  done
  if [[ -f "$system_root/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg" ]]; then
    cp -p -- "$system_root/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg" "$backup_dir/cloud-hostname.cfg"
  fi
  log "主机名原配置备份: $backup_dir"
  # Change the kernel/systemd hostname before touching persistent files. A
  # restricted container can refuse this operation without changing /etc files.
  if [[ -d "$system_root/run/systemd/system" ]] && command -v hostnamectl >/dev/null; then
    hostnamectl set-hostname "$name" || die "设置主机名失败；原配置备份在 $backup_dir。"
  else
    hostname "$name" || die "当前环境不允许设置主机名；未改写 /etc 配置。备份: $backup_dir"
  fi
  printf '%s\n' "$name" > "$system_root/etc/hostname"
  hosts_tmp="$(mktemp)"
  if ! awk -v name="$name" '
    $1 == "127.0.1.1" && !updated {
      printf "%s\t%s", $1, name
      for (i = 2; i <= NF; i++) if ($i != name) printf " %s", $i
      printf "\n"; updated = 1; next
    }
    { print }
    END { if (!updated) print "127.0.1.1\t" name }
  ' "$system_root/etc/hosts" > "$hosts_tmp"; then
    rm -f -- "$hosts_tmp"
    die "更新主机名解析失败；原配置备份在 $backup_dir。"
  fi
  # cat preserves mount points and file ownership, unlike renaming /etc/hosts.
  cat "$hosts_tmp" > "$system_root/etc/hosts"
  rm -f -- "$hosts_tmp"
  if [[ -f "$system_root/etc/cloud/cloud.cfg" ]]; then
    install -d -m 755 "$system_root/etc/cloud/cloud.cfg.d"
    printf 'preserve_hostname: true\nmanage_etc_hosts: false\n' > "$system_root/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg"
    chmod 644 "$system_root/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg"
  fi
  log "主机名已设置为 $name。"
}
