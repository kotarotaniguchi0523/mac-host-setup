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
# Personal skills kept outside every repository (~/.apm-private/skills/<name>/SKILL.md) -> ~/.claude/skills/<name>
# (Claude Code) and ~/.agents/skills/<name> (Codex, OpenCode and other agents that read the shared directory).
# APM's user scope (~/.apm) is rebuilt from skills/ above and cannot hold them: a frozen install refuses skill
# files it did not lock, and APM has no second user scope. They are copied here instead, outside the lock and
# `apm audit`. Each copy carries a .private-skill marker: an unmarked directory is never overwritten, and a
# marked copy whose source is gone is removed.
private="$HOME/.apm-private/skills"
for dest in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  mkdir -p "$dest"
  for d in "$dest"/*/; do
    [[ -f "$d/.private-skill" ]] || continue
    name="$(basename "$d")"
    if [[ ! -f "$private/$name/SKILL.md" ]]; then
      rm -rf "${dest:?}/${name:?}"
      echo "[ok] removed $dest/$name (private skill, source gone)"
    fi
  done
  [[ -d "$private" ]] || continue
  for d in "$private"/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    name="$(basename "$d")"
    if [[ -e "$dest/$name" && ! -f "$dest/$name/.private-skill" ]]; then
      die "$dest/$name exists and is not a private skill; rename ~/.apm-private/skills/$name" 4
    fi
    rm -rf "${dest:?}/${name:?}"
    cp -R "$d" "$dest/$name"
    touch "$dest/$name/.private-skill"
    echo "[ok] $dest/$name (private)"
  done
done
echo "[ok] Skills deployed (apm.lock.yaml, audit clean)"
