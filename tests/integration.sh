#!/usr/bin/env bash
# Run only in a disposable Ubuntu container: this test installs packages/accounts.
set -Eeuo pipefail
trap 'printf "Integration test failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID -eq 0 ]] || { printf 'Run this test as root in a disposable container.\n' >&2; exit 1; }
[[ -f /.dockerenv || ${LINUX_ENV_TEST_ALLOW_HOST:-0} == 1 ]] || {
    printf 'Refusing to change accounts outside a disposable container.\n' >&2
    exit 1
}

note() { printf '\n[test] %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
as_learner() { runuser -u learner -- env HOME=/home/learner TERM=xterm-256color "$@"; }
expect_failure() {
    if "$@"; then
        fail "Command unexpectedly succeeded: $*"
    fi
}
backup_listing() {
    find /home/learner/.local/state/linux-env/backups -type f -printf '%P\n' | LC_ALL=C sort
}

note 'Prepare an existing user with personal settings and an SSH key'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends sudo ca-certificates
! getent passwd learner >/dev/null || fail 'The learner account already exists; use a fresh container.'
useradd --create-home --shell /bin/bash learner
printf 'learner ALL=(ALL:ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/linux-env-test
chmod 0440 /etc/sudoers.d/linux-env-test
printf '" linux-env-test original vimrc\nset number\n' >/home/learner/.vimrc
printf '# linux-env-test original zshrc\n' >/home/learner/.zshrc
printf '# linux-env-test original tmux\n' >/home/learner/.tmux.conf
install -d -m 0755 -o learner -g learner /home/learner/.vim/plugin
printf "throw 'legacy plugin loaded'\n" >/home/learner/.vim/plugin/legacy-error.vim
chown learner:learner /home/learner/.vim/plugin/legacy-error.vim
install -d -m 0700 -o learner -g learner /home/learner/.ssh
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixture learner@example.invalid\n' >/home/learner/.ssh/authorized_keys
chmod 0600 /home/learner/.ssh/authorized_keys
chown learner:learner /home/learner/.vimrc /home/learner/.zshrc /home/learner/.tmux.conf /home/learner/.ssh/authorized_keys
ssh_before=$(sha256sum /home/learner/.ssh/authorized_keys)
sudo_before=$(sha256sum /etc/sudoers /etc/sudoers.d/linux-env-test)
as_learner git --version >/dev/null 2>&1 || apt-get install -y --no-install-recommends git
as_learner git config --global user.name 'Existing Learner'
as_learner git config --global user.email learner@example.invalid
as_learner git config --global core.editor nano

note 'Help must work without root; unknown accounts and options must fail'
as_learner bash "$repo_root/init_env.sh" --help
as_learner bash "$repo_root/scripts/install.sh" --help
expect_failure bash "$repo_root/init_env.sh" --user linux-env-missing-test-user --skip-packages
expect_failure bash "$repo_root/init_env.sh" --invalid-linux-env-test-option
expect_failure bash "$repo_root/init_env.sh" --source
expect_failure bash "$repo_root/init_env.sh" --source unsupported
expect_failure env LINUX_ENV_SOURCE=unsupported bash "$repo_root/init_env.sh" --skip-packages

note 'Install through a real sudo -i session and detect the original user'
as_learner sudo -i bash "$repo_root/init_env.sh" --no-change-shell
[[ -f /home/learner/.config/linux-env/gitconfig ]] || fail 'sudo -i did not configure the invoking user'
[[ $(getent passwd learner | cut -d: -f7) == /bin/bash ]] || fail '--no-change-shell changed the login shell'
[[ $(as_learner git config --global --includes user.name) == 'Existing Learner' ]] || fail 'Git user.name was lost'
[[ $(as_learner git config --global --includes user.email) == learner@example.invalid ]] || fail 'Git user.email was lost'
[[ $(as_learner git config --global --includes core.editor) == nano ]] || fail 'Existing Git preference was lost'
[[ $(as_learner git config --global --get-all include.path | grep -Fxc /home/learner/.config/linux-env/gitconfig) == 1 ]] || fail 'Git include is missing or duplicated'
grep -R -Fq 'linux-env-test original vimrc' /home/learner/.local/state/linux-env/backups || fail 'Original Vim configuration was not backed up'
grep -R -Fq 'linux-env-test original zshrc' /home/learner/.local/state/linux-env/backups || fail 'Original Zsh configuration was not backed up'
backups_before=$(backup_listing)
[[ ! -e /home/learner/code ]] || fail "Installer automatically created project directories"

note 'Repeat installation without new backups, duplicate includes, or project directories'
bash "$repo_root/init_env.sh" --user learner --skip-packages
[[ $(getent passwd learner | cut -d: -f7) == /usr/bin/zsh || $(getent passwd learner | cut -d: -f7) == /bin/zsh ]] || fail 'Default login shell is not Zsh'
[[ $(backup_listing) == "$backups_before" ]] || fail 'Unchanged reinstall created another backup'
[[ ! -e /home/learner/code ]] || fail "Reinstall automatically created project directories"
[[ $(as_learner git config --global --get-all include.path | grep -Fxc /home/learner/.config/linux-env/gitconfig) == 1 ]] || fail 'Reinstall duplicated the Git include'
[[ $(sha256sum /home/learner/.ssh/authorized_keys) == "$ssh_before" ]] || fail 'Installer modified SSH keys'
[[ $(sha256sum /etc/sudoers /etc/sudoers.d/linux-env-test) == "$sudo_before" ]] || fail 'Installer modified sudo policy'
grep -Fq "throw 'legacy plugin loaded'" /home/learner/.vim/plugin/legacy-error.vim || fail 'Old Vim plugins were removed instead of preserved'
[[ -z $(find /home/learner/.config/linux-env -not -user learner -print -quit) ]] || fail 'Installed user files are owned by root'

note 'Doctor, Vim, and interactive Zsh must work as the ordinary user'
as_learner /usr/local/bin/linux-env-doctor
as_learner zsh -n /home/learner/.zshrc
as_learner zsh -ic 'command -v gcc; command -v python3; exit'
# zsh -ic does not run precmd hooks; do not depend on a plugin loading the
# optional introspection module on our behalf before querying its widgets hash.
# shellcheck disable=SC2016 # Function/widget parameters belong to the child Zsh.
as_learner zsh -ic '
    zmodload zsh/zleparameter || exit 1
    print -r -- "interactive=${options[interactive]} zle=${options[zle]}"
    print -r -- "autosuggestions=${+functions[_zsh_autosuggest_start]} highlighting=${+functions[_zsh_highlight]} fzf-function=${+functions[fzf-file-widget]} fzf-widget=${+widgets[fzf-file-widget]}"
    print -r -- "fzf widget handler=${widgets[fzf-file-widget]-missing}"
    (( ${+functions[_zsh_autosuggest_start]} && ${+functions[_zsh_highlight]} && ${+widgets[fzf-file-widget]} ))
'
vim_log=$(mktemp /tmp/linux-env-vim-test.XXXXXXXX)
chown learner:learner "$vim_log"
# Test the real terminal startup path: Ex/silent modes have different init rules.
as_learner script -qefc 'vim -i NONE -n -c "qa!"' "$vim_log" || { cat "$vim_log"; fail 'Normal Vim startup failed'; }

note 'Generate and execute C, C++, and isolated Python starter projects'
project_dir=$(mktemp -d /tmp/linux-env-projects.XXXXXX)
chown learner:learner "$project_dir"
for language in c cpp; do
    as_learner /usr/local/bin/linux-env-new "$language" "$project_dir/$language"
    as_learner cmake -S "$project_dir/$language" -B "$project_dir/$language/build" -G Ninja -DCMAKE_BUILD_TYPE=Debug
    as_learner cmake --build "$project_dir/$language/build"
    as_learner ctest --test-dir "$project_dir/$language/build" --output-on-failure
done
as_learner /usr/local/bin/linux-env-new python "$project_dir/python"
as_learner python3 -m venv "$project_dir/python/.venv"
# shellcheck disable=SC2016 # The child Bash intentionally expands its own $1.
as_learner bash -c 'cd "$1"; .venv/bin/python -m unittest discover -s tests -v; .venv/bin/python -c "import sys; assert sys.prefix != sys.base_prefix"' bash "$project_dir/python"
printf 'Do not overwrite this file\n' >"$project_dir/c/personal.txt"
expect_failure as_learner /usr/local/bin/linux-env-new c "$project_dir/c"
grep -Fq 'Do not overwrite this file' "$project_dir/c/personal.txt" || fail 'Project generator overwrote an existing directory'
expect_failure as_learner /usr/local/bin/linux-env-new unknown "$project_dir/unknown"

note 'Existing personal project directories must stay untouched'
install -d -o learner -g learner /home/learner/code/linux-env-examples
printf 'personal project\n' >/home/learner/code/linux-env-examples/personal.txt
chown learner:learner /home/learner/code/linux-env-examples/personal.txt
bash "$repo_root/init_env.sh" --user learner --skip-packages --skip-checks
[[ $(cat /home/learner/code/linux-env-examples/personal.txt) == 'personal project' ]] || fail 'Existing project was changed'
[[ $(find /home/learner/code/linux-env-examples -type f | wc -l) == 1 ]] || fail 'Installer added example projects'

note 'Explicit root configuration is supported without changing its login shell'
root_shell=$(getent passwd root | cut -d: -f7)
bash "$repo_root/init_env.sh" --user root --skip-packages --skip-checks --no-change-shell
[[ -f /root/.config/linux-env/gitconfig ]] || fail 'Explicit root configuration failed'
[[ $(getent passwd root | cut -d: -f7) == "$root_shell" ]] || fail 'Root login shell changed despite --no-change-shell'

note 'Exercise standalone bootstrap against the exact tested source revision'
bash "$repo_root/tests/bootstrap.sh"

note 'Exercise identity setup with a real controlling terminal and private password entry'
python3 "$repo_root/tests/identity.py"
python3 "$repo_root/tests/editor.py"
python3 "$repo_root/tests/sudo-suggestions.py"
printf '\nAll Ubuntu integration checks passed.\n'
