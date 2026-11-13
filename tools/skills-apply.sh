#!/bin/bash
# skills-apply.sh - deploy the Skills declared in skills/apm.yml (pinned by skills/apm.lock.yaml)
# to this host: ~/.apm/ <- skills/, then `apm install --global --frozen` (targets in apm.yml:
# claude -> ~/.claude/skills/). Called by tools/update.sh; also safe to run on its own.
#
# Never runs `apm update` / `apm lock` here: refs and the lock change only through PRs
# (Renovate + skills-relock.yml). `apm update` also picks wrong targets for SHA pins (AUDIT.md).
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
cd "$repo"
nix_env
github_auth

[[ -f skills/apm.yml && -f skills/apm.lock.yaml ]] || die "skills/apm.yml and skills/apm.lock.yaml are required" 4
apm="$(apm_bin)" || die "could not build .#apm" 4

mkdir -p "$HOME/.apm"
cp skills/apm.yml "$HOME/.apm/apm.yml"
cp skills/apm.lock.yaml "$HOME/.apm/apm.lock.yaml"

# Every path the lock records as deployed must exist afterwards. A first install can integrate a
# package only partly, so it is re-run once before failing.
missing() {
  awk '/^  deployed_files:/{f=1; next} /^  [a-z_]+:/{f=0} f && /^  - /{print $2}' "$HOME/.apm/apm.lock.yaml" |
    while IFS= read -r p; do [[ -e "$HOME/$p" ]] || echo "$p"; done
}
apm_in "$HOME" "$apm" install --global --frozen
if [[ -n "$(missing)" ]]; then
  echo "[i] not deployed yet: $(missing | paste -sd' ' -); running install again"
  apm_in "$HOME" "$apm" install --global --frozen
  [[ -z "$(missing)" ]] || die "still missing after two installs: $(missing | paste -sd' ' -)" 4
fi
apm_in "$HOME" "$apm" audit --ci >/dev/null || die "apm audit --ci failed (run it in ~/.apm for details)" 4

# Skills written in this repository (skills/local/<name>/SKILL.md) -> ~/.claude/skills/<name>
if [[ -d skills/local ]]; then
  for d in skills/local/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    name="$(basename "$d")"
    rm -rf "$HOME/.claude/skills/$name"
    mkdir -p "$HOME/.claude/skills"
    cp -R "$d" "$HOME/.claude/skills/$name"
    echo "[ok] ~/.claude/skills/$name (local)"
  done
fi
echo "[ok] Skills deployed (apm.lock.yaml, audit clean)"
