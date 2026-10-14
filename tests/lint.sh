#!/usr/bin/env bash
# Check the maintained installer and tests; archived migration tools are excluded.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

shell_files=(init_env.sh)
while IFS= read -r -d '' file; do
    case "$file" in
        scripts/audit_payload.sh | scripts/collect_teacher_config.sh) continue ;;
    esac
    if [[ $(head -n 1 "$file") == '#!'*bash* ]]; then
        shell_files+=("$file")
    fi
done < <(find scripts tests -type f -print0)

for file in "${shell_files[@]}"; do
    bash -n "$file"
done
if LC_ALL=C grep -n $'\r' "${shell_files[@]}"; then
    printf 'Shell scripts must use LF line endings.\n' >&2
    exit 1
fi
command -v shellcheck >/dev/null || {
    printf 'Install shellcheck before running tests/lint.sh.\n' >&2
    exit 1
}
shellcheck --external-sources "${shell_files[@]}"
printf 'Bash syntax and ShellCheck passed (%s files).\n' "${#shell_files[@]}"
