#!/bin/bash
# flake-lock-update.sh - move flake.lock to the newest commit of each input that is at least
# MIN_AGE_DAYS old (AGENTS.md: adopt releases only after 2 days). Never uses `nix flake update`.
#
# Usage: tools/ci/flake-lock-update.sh        (needs nix, jq, gh with a token)
# Prints "changed=true|false" (also to $GITHUB_OUTPUT when set).
# Limit: the age is the commit date on the branch, not the time the channel branch advanced.
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
nix_env
MIN_AGE_DAYS="${MIN_AGE_DAYS:-2}"
until="$(date -u -d "-${MIN_AGE_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
  date -u -v-"${MIN_AGE_DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"

# Every direct input of the flake, with the branch it follows (flake.lock "original").
args=()
while read -r input owner name ref; do
  sha="$(gh api -X GET "repos/$owner/$name/commits" -f "sha=refs/heads/$ref" -f "until=$until" -f per_page=1 --jq '.[0].sha')"
  [[ -n "$sha" ]] || die "no commit on $owner/$name@$ref before $until"
  echo "[i] $input: $owner/$name@$ref -> ${sha:0:12} (<= $until)"
  args+=(--override-input "$input" "github:$owner/$name/$sha")
done < <(jq -r '.nodes as $n | $n.root.inputs | to_entries[]
  | "\(.key) \($n[.value].original | "\(.owner) \(.repo) \(.ref)")"' flake.lock)

nix flake lock "${args[@]}"

changed=false
git diff --quiet -- flake.lock || changed=true
echo "changed=$changed"
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "changed=$changed" >> "$GITHUB_OUTPUT"
exit 0
