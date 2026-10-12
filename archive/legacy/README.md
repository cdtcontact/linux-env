# Legacy teacher scripts

`collect_teacher_config.sh` may copy the original `init_env.sh`, `isoftstone_env.sh`, `install_vim.sh` and `install_zsh.sh` here for reference. They are historical source snapshots only and are **not executed** by the new installer. They can contain unsafe operations (for example destructive wildcard deletion, remote HTTP downloads, or brittle edits to `/etc/sudoers`); review them before publishing and do not use them as the production installation path.
