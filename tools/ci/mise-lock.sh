#!/bin/bash
# mise-lock.sh - regenerate / verify the mise lockfiles (global lane + this repository's dev tools).
#
# Usage: tools/ci/mise-lock.sh --check   exit 1 when a lockfile is missing entries or out of date
#        tools/ci/mise-lock.sh --write   update the lockfiles in place (used by mise-relock.yml)
#
# The global lane (mise/mise.toml) is locked in an isolated config dir so the host's real
# ~/.config/mise is never touched. Platforms: the host (macos-arm64) and CI (linux-x64).
set -euo pipefail
mode="${1:?usage: mise-lock.sh --check|--write}"
repo="$(cd "$(dirname "$0")/../.." && pwd)"
platforms="macos-arm64,linux-x64"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- global lane ------------------------------------------------------------------------
mkdir -p "$work/cfg"
cp "$repo/mise/mise.toml" "$work/cfg/config.toml"
[[ -f "$repo/mise/mise.lock" ]] && cp "$repo/mise/mise.lock" "$work/cfg/mise.lock"
(cd "$work" && MISE_CONFIG_DIR="$work/cfg" MISE_GLOBAL_CONFIG_FILE="$work/cfg/config.toml" \
  MISE_DATA_DIR="$work/data" MISE_CACHE_DIR="$work/cache" \
  mise lock --global --platform "$platforms")

# --- repository dev tools ---------------------------------------------------------------
(cd "$repo" && mise trust --quiet . && mise lock --platform "$platforms")

status=0
if [[ "$mode" == "--check" ]]; then
  if ! cmp -s "$work/cfg/mise.lock" "$repo/mise/mise.lock"; then
    echo "::error file=mise/mise.lock::mise/mise.lock is out of date (run tools/ci/mise-lock.sh --write)"
    diff -u "$repo/mise/mise.lock" "$work/cfg/mise.lock" || true
    status=1
  fi
  if ! git -C "$repo" diff --quiet -- mise.lock; then
    echo "::error file=mise.lock::mise.lock is out of date (run tools/ci/mise-lock.sh --write)"
    git -C "$repo" diff -- mise.lock
    git -C "$repo" checkout -- mise.lock
    status=1
  fi
  [[ $status -eq 0 ]] && echo "[ok] mise lockfiles are up to date"
elif [[ "$mode" == "--write" ]]; then
  cp "$work/cfg/mise.lock" "$repo/mise/mise.lock"
  echo "[ok] wrote mise/mise.lock and mise.lock"
else
  echo "unknown mode: $mode" >&2; exit 2
fi
exit $status
