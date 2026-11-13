#!/bin/bash
# skills-lock.sh - verify / regenerate skills/apm.lock.yaml with the pinned APM (.#apm).
#
# Usage: tools/ci/skills-lock.sh --check [<sarif>]   lock matches apm.yml, a cold frozen install
#                                                      deploys everything, and `apm audit` is clean
#        tools/ci/skills-lock.sh --write             regenerate the lock (used by skills-relock.yml)
#
# Runs in a temporary HOME, so the host's ~/.apm and ~/.claude are never touched. The lock is
# regenerated with `apm lock` + `apm install` (never `apm update`, which can move a SHA pin to an
# older annotated tag; AUDIT.md).
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
nix_env
mode="${1:-}" sarif="${2:-}"
case "$mode" in --check | --write) ;; *) die "usage: skills-lock.sh --check [<sarif>] | --write" 2 ;; esac
github_auth
apm="$(apm_bin)" || die "could not build .#apm" 4
"$apm" --version | head -n 1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. resolve from apm.yml alone, then record the deployment inventory (install completes the lock)
mkdir -p "$work/new/.apm"
cp skills/apm.yml "$work/new/.apm/apm.yml"
apm_in "$work/new" "$apm" lock --global
apm_in "$work/new" "$apm" install --global
new="$work/new/.apm/apm.lock.yaml"

if [[ "$mode" == --write ]]; then
  if cmp -s "$new" skills/apm.lock.yaml; then echo "[ok] skills/apm.lock.yaml already up to date"
  else cp "$new" skills/apm.lock.yaml; echo "[ok] wrote skills/apm.lock.yaml"; fi
  exit 0
fi

status=0
if ! cmp -s "$new" skills/apm.lock.yaml; then
  echo "::error file=skills/apm.lock.yaml::skills/apm.lock.yaml is out of date (run tools/ci/skills-lock.sh --write)"
  diff -u skills/apm.lock.yaml "$new" || true
  status=1
fi

# 2. what the host does: a cold frozen install from the committed lock, then the audit
mkdir -p "$work/cold/.apm"
cp skills/apm.yml skills/apm.lock.yaml "$work/cold/.apm/"
apm_in "$work/cold" "$apm" install --global --frozen || status=1
if [[ -n "$sarif" ]]; then
  apm_in "$work/cold" "$apm" audit --ci --format sarif --output "$sarif" || status=1
else
  apm_in "$work/cold" "$apm" audit --ci || status=1
fi
[[ $status -eq 0 ]] && echo "[ok] skills: lock up to date, frozen install and audit clean"
exit $status
