#!/bin/bash
# flake-lock-update.sh - move flake.lock to the newest commit of each input that is at least
# MIN_AGE_DAYS old (AGENTS.md: adopt releases only after 2 days). Never uses `nix flake update`.
#
# Usage: tools/ci/flake-lock-update.sh        (needs nix, gh with a token, GNU or BSD date)
# Prints "changed=true|false" (also to $GITHUB_OUTPUT when set).
# Limit: the age is the commit date on the branch, not the time the channel branch advanced.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"
export NIX_CONFIG="extra-experimental-features = nix-command flakes"
MIN_AGE_DAYS="${MIN_AGE_DAYS:-2}"

if until="$(date -u -d "-${MIN_AGE_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"; then :; else
  until="$(date -u -v-"${MIN_AGE_DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"
fi

# input name -> owner/repo and branch, read from flake.lock "original" (the branch we follow)
args=()
for input in nixpkgs nix-darwin home-manager; do
  read -r owner name ref < <(nix eval --raw --impure --expr "
    let l = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.\"$input\".original;
    in \"\${l.owner} \${l.repo} \${l.ref}\""; echo)
  sha="$(gh api -X GET "repos/$owner/$name/commits" -f "sha=refs/heads/$ref" -f "until=$until" -f per_page=1 --jq '.[0].sha')"
  [[ -n "$sha" ]] || { echo "error: no commit on $owner/$name@$ref before $until" >&2; exit 1; }
  echo "[i] $input: $owner/$name@$ref -> ${sha:0:12} (<= $until)"
  args+=(--override-input "$input" "github:$owner/$name/$sha")
done

nix flake lock "${args[@]}"

changed=false
git diff --quiet -- flake.lock || changed=true
echo "changed=$changed"
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "changed=$changed" >> "$GITHUB_OUTPUT"
exit 0
