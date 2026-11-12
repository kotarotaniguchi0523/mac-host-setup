#!/bin/bash
# mise-lock.sh - regenerate / verify the mise lockfiles (global lane + this repository's dev tools).
#
# Usage: tools/ci/mise-lock.sh --check   exit 1 when a lockfile is missing entries or out of date
#        tools/ci/mise-lock.sh --write   update the lockfiles in place (used by mise-relock.yml)
#
# Both lanes are locked on copies in a temp dir, so the host's ~/.config/mise and the working
# tree are never touched by --check. Platforms: the host (macos-arm64) and CI (linux-x64).
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
mode="${1:-}"
case "$mode" in --check | --write) ;; *) die "usage: mise-lock.sh --check|--write" 2 ;; esac
platforms="macos-arm64,linux-x64"
github_auth # CI passes GITHUB_TOKEN; on the host the gh token is used
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export MISE_TRUSTED_CONFIG_PATHS="$work"

# global lane (isolated config dir; the shared cache dir is reused)
install_global_mise_config "$work/global"
(cd "$work" && MISE_CONFIG_DIR="$work/global" MISE_GLOBAL_CONFIG_FILE="$work/global/config.toml" \
  MISE_DATA_DIR="$work/data" mise lock --global --platform "$platforms")
# repository dev tools
mkdir -p "$work/repo"
cp "$repo/mise.toml" "$repo/mise.lock" "$work/repo/"
(cd "$work/repo" && mise lock --platform "$platforms")

status=0
# aube's dependency graphs, referenced by digest from mise/mise.lock
if ! diff -r -q "$work/global/locks" "$repo/mise/locks" >/dev/null 2>&1; then
  if [[ "$mode" == --write ]]; then
    rm -rf "$repo/mise/locks"; cp -R "$work/global/locks" "$repo/mise/locks"; echo "[ok] wrote mise/locks/"
  else
    echo "::error file=mise/locks::mise/locks/ is out of date (run tools/ci/mise-lock.sh --write)"
    diff -r -q "$work/global/locks" "$repo/mise/locks" || true
    status=1
  fi
fi
for pair in "global/mise.lock:mise/mise.lock" "repo/mise.lock:mise.lock"; do
  new="$work/${pair%%:*}" cur="$repo/${pair#*:}"
  cmp -s "$new" "$cur" && continue
  if [[ "$mode" == --write ]]; then
    cp "$new" "$cur"; echo "[ok] wrote ${pair#*:}"
  else
    echo "::error file=${pair#*:}::${pair#*:} is out of date (run tools/ci/mise-lock.sh --write)"
    diff -u "$cur" "$new" || true
    status=1
  fi
done
[[ $status -eq 0 && "$mode" == --check ]] && echo "[ok] mise lockfiles are up to date"
exit $status
