#!/bin/bash
# pii-check.sh - fail if personal data would be committed / pushed (public repository).
#
# Usage: tools/pii-check.sh [files...]   (no args: every tracked file)
#
# Patterns come from the live environment, so no real value is written into the repository:
#   - $USER, $HOME, the global git user.email, the GitHub login (gh, when available)
#   - extra literals, one per line, in .agent/pii-patterns.txt (local only, .gitignore'd)
# Also checks that commits in this repository are authored with the GitHub noreply address.
# In the repository, write placeholders instead: $HOME / ~ / %GITHUB_USER% / %EMAIL%.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo" || exit 4

patterns=("/Users/$USER" "$HOME")
[[ -n "${USER:-}" ]] && patterns+=("$USER")
global_email="$(git config --global user.email 2>/dev/null || true)"
[[ -n "$global_email" ]] && patterns+=("$global_email")
if command -v gh >/dev/null 2>&1; then
  login="$(gh api user --jq .login 2>/dev/null || true)"
  [[ -n "$login" ]] && patterns+=("$login")
fi
if [[ -f .agent/pii-patterns.txt ]]; then
  while IFS= read -r line; do [[ -n "$line" && "$line" != \#* ]] && patterns+=("$line"); done < .agent/pii-patterns.txt
fi

if [[ $# -gt 0 ]]; then files=("$@"); else files=(); while IFS= read -r f; do files+=("$f"); done < <(git ls-files); fi
status=0
for p in "${patterns[@]}"; do
  hits="$(grep -nHIF -- "$p" "${files[@]}" 2>/dev/null | grep -v '^tools/pii-check.sh:' || true)"
  if [[ -n "$hits" ]]; then
    echo "[pii] found a personal value (pattern hidden) in:" >&2
    echo "$hits" | cut -d: -f1,2 | sed 's/^/  /' >&2
    status=1
  fi
done

repo_email="$(git config user.email || true)"
if [[ "$repo_email" != *@users.noreply.github.com ]]; then
  echo "[pii] commits here must use the GitHub noreply address:" >&2
  echo "  git config user.email '<id>+<login>@users.noreply.github.com'" >&2
  status=1
fi
bad_authors="$(git log --format='%ae%n%ce' 2>/dev/null | sort -u | grep -v '@users.noreply.github.com$' | grep -v '^noreply@anthropic.com$' || true)"
if [[ -n "$bad_authors" ]]; then
  echo "[pii] history has non-noreply author/committer emails (rewrite before pushing)" >&2
  status=1
fi

[[ $status -eq 0 ]] && echo "[ok] no PII"
exit $status
