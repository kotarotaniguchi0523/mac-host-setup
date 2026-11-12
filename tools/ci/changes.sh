#!/bin/bash
# changes.sh - which CI areas does this change touch? Writes `<area>=true|false` to $GITHUB_OUTPUT
# (and stdout), so ci.yml can skip whole jobs with `if:`. A job skipped by `if:` still satisfies a
# required status check, unlike a workflow skipped by `paths:` (which stays pending forever).
#
# Usage: tools/ci/changes.sh <base-sha> <head-sha>
#   An empty / all-zero base (new branch, workflow_dispatch, schedule) selects every area.
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
base="${1:-}" head="${2:-HEAD}"

# area -> extended regex over changed paths. Shared infrastructure (lib.sh, this script, ci.yml,
# the setup-mise action) belongs to every area that uses it.
shared='^(tools/lib\.sh|tools/ci/changes\.sh|\.github/workflows/ci\.yml)$'
nix_re='(\.nix$|^flake\.lock$|^tools/install-nix\.sh$|^tools/ci/(nix-check|check-mise-version)\.sh$|^\.github/actions/setup-mise/)'
mise_re='(^mise\.(toml|lock)$|^mise/|^tools/ci/mise-lock\.sh$|^\.github/actions/setup-mise/)'

if [[ -z "$base" || "$base" =~ ^0+$ ]] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  files=""; all=true
else
  files="$(git diff --name-only "$base" "$head")"; all=false
fi

out() { echo "$1=$2"; [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1=$2" >> "$GITHUB_OUTPUT"; return 0; }
touches() { $all || grep -qE "$1|$shared" <<<"$files"; }
touches "$nix_re" && out nix true || out nix false
touches "$mise_re" && out mise true || out mise false
