#!/usr/bin/env bash
# Test the standalone downloaded-file path without relying on a published branch.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID -eq 0 ]] || { printf 'Run bootstrap.sh in the integration container as root.\n' >&2; exit 1; }
[[ -f /.dockerenv || ${LINUX_ENV_TEST_ALLOW_HOST:-0} == 1 ]] || {
    printf 'Use a disposable container for the bootstrap installation test.\n' >&2
    exit 1
}
work_dir=$(mktemp -d /tmp/linux-env-bootstrap-test.XXXXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT
fixture="$work_dir/source"
mkdir -p "$fixture" "$work_dir/download" "$work_dir/bin"
cp "$repo_root/init_env.sh" "$work_dir/download/init_env.sh"
cp "$repo_root/init_env.sh" "$fixture/init_env.sh"
cp -R "$repo_root/scripts" "$repo_root/config" "$repo_root/examples" "$fixture/"
# These sentinels must remain outside the sparse working tree.
mkdir -p "$fixture/archive/legacy" "$fixture/payload/home"
printf 'must stay archived\n' >"$fixture/archive/legacy/sentinel"
printf 'must stay archived\n' >"$fixture/payload/home/sentinel"
git init -q --initial-branch=main "$fixture"
git -C "$fixture" config uploadpack.allowFilter true
git -C "$fixture" add .
git -C "$fixture" -c user.name=linux-env-test -c user.email=test@example.invalid commit -qm 'Fixture for standalone bootstrap'
fixture_revision=$(git -C "$fixture" rev-parse HEAD)

# Record real Git operations and inspect checkout before bootstrap cleans up.
export LINUX_ENV_REAL_GIT
LINUX_ENV_REAL_GIT=$(command -v git)
export LINUX_ENV_GIT_LOG="$work_dir/git.log"
export LINUX_ENV_CHECKOUT_RECORD="$work_dir/checkout.txt"
export LINUX_ENV_FIXTURE="$fixture"
export LINUX_ENV_ARCHIVE_BLOB
LINUX_ENV_ARCHIVE_BLOB=$(git -C "$fixture" hash-object archive/legacy/sentinel)
cat >"$work_dir/bin/git" <<'SPY'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s ' "$@" >>"$LINUX_ENV_GIT_LOG"
printf '\n' >>"$LINUX_ENV_GIT_LOG"
# Keep real fetch/checkout behavior while routing both public source choices to
# the same fixture. Inspect the original URL in the log instead of using network.
arguments=("$@")
if [[ $# -eq 6 && $1 == -C && $3 == remote && $4 == add && $5 == origin ]]; then
    case "$6" in
        https://gitee.com/peacecdt/linux-env.git | https://github.com/cdtcontact/linux-env.git)
            arguments[5]="file://$LINUX_ENV_FIXTURE"
            ;;
        "file://$LINUX_ENV_FIXTURE") ;;
        *) printf 'Unexpected bootstrap remote: %s\n' "$6" >&2; exit 1 ;;
    esac
fi
"$LINUX_ENV_REAL_GIT" "${arguments[@]}"
checkout=0
directory=.
next_directory=0
for argument in "$@"; do
    if (( next_directory )); then directory=$argument; next_directory=0; fi
    case "$argument" in
        -C) next_directory=1 ;;
        checkout) checkout=1 ;;
    esac
done
if (( checkout )); then
    for entry in config scripts examples archive payload; do
        if [[ -e "$directory/$entry" ]]; then
            printf '%s\n' "$entry" >>"$LINUX_ENV_CHECKOUT_RECORD"
        fi
    done
    # Sparse working files alone do not prove that filtering saved bandwidth.
    # Enumerating existing objects does not trigger a lazy fetch of missing ones.
    objects=$("$LINUX_ENV_REAL_GIT" -C "$directory" cat-file --batch-all-objects --batch-check='%(objectname)')
    if grep -Fxq "$LINUX_ENV_ARCHIVE_BLOB" <<<"$objects"; then
        printf 'An archived blob was downloaded despite partial fetch.\n' >&2
        exit 1
    fi
fi
SPY
chmod 0755 "$work_dir/bin/git"
! getent passwd bootlearner >/dev/null || { printf 'Use a fresh container; bootlearner already exists.\n' >&2; exit 1; }
useradd --create-home --shell /bin/bash bootlearner

run_bootstrap() {
    local expected_remote=$1
    shift
    : >"$LINUX_ENV_GIT_LOG"
    : >"$LINUX_ENV_CHECKOUT_RECORD"
    env -u LINUX_ENV_SOURCE -u LINUX_ENV_REPO_URL \
        PATH="$work_dir/bin:$PATH" LINUX_ENV_REF="$fixture_revision" \
        "$@" bash "$work_dir/download/init_env.sh" \
        --user bootlearner --skip-packages --skip-checks --no-change-shell
    [[ -f /home/bootlearner/.config/linux-env/gitconfig ]]
    grep -Fq "remote add origin $expected_remote " "$LINUX_ENV_GIT_LOG"
    grep -Fq "origin $fixture_revision " "$LINUX_ENV_GIT_LOG"
    grep -Eq 'fetch .*--filter=blob:none' "$LINUX_ENV_GIT_LOG"
    grep -Eq 'fetch .*--depth[= ]1' "$LINUX_ENV_GIT_LOG"
    grep -Fq 'sparse-checkout set config scripts examples' "$LINUX_ENV_GIT_LOG"
    [[ $(LC_ALL=C sort "$LINUX_ENV_CHECKOUT_RECORD") == $'config\nexamples\nscripts' ]]
}

# A helper supplies CLI arguments after Bash's script argument, while env sets
# source preferences without leaking the caller's environment into each case.
cat >"$work_dir/bin/bootstrap-with-source" <<'SOURCE'
#!/usr/bin/env bash
set -Eeuo pipefail
source_name=$1
shift
exec "$@" --source "$source_name"
SOURCE
chmod 0755 "$work_dir/bin/bootstrap-with-source"

run_bootstrap https://gitee.com/peacecdt/linux-env.git
run_bootstrap https://github.com/cdtcontact/linux-env.git env LINUX_ENV_SOURCE=github
run_bootstrap https://gitee.com/peacecdt/linux-env.git \
    env LINUX_ENV_SOURCE=github bootstrap-with-source gitee
run_bootstrap "file://$fixture" \
    env LINUX_ENV_SOURCE=gitee LINUX_ENV_REPO_URL="file://$fixture" bootstrap-with-source github

printf 'Standalone bootstrap passed: Gitee default, source precedence, exact revision, partial fetch, sparse checkout.\n'
