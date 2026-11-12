#!/bin/bash
# pii-check.sh - fail if personal data would be committed / pushed (public repository).
#
# Usage: tools/pii-check.sh [files...]   (no args: every tracked file)
#
# Patterns come from the live environment, so no real value is written into the repository:
#   - $USER, the global git user.email, the GitHub login (from gh's config, offline)
#   - extra literals, one per line, in .agent/pii-patterns.txt (local only, .gitignore'd)
#   - any macOS home path (/Users/<name>/), which also catches names this host does not know
# Also checks that commits are authored with a GitHub noreply address.
# In the repository, write placeholders instead: $HOME / ~ / %GITHUB_USER% / %EMAIL%.
set -uo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
cd "$repo" || exit 4

patterns="$(mktemp)"
trap 'rm -f "$patterns"' EXIT
{
  [[ -n "${USER:-}" ]] && echo "$USER"
  git config --global user.email 2>/dev/null
  command -v gh >/dev/null && gh config get -h github.com user 2>/dev/null
  [[ -f .agent/pii-patterns.txt ]] && grep -vE '^(#|$)' .agent/pii-patterns.txt
} | grep -v '^$' > "$patterns"

if [[ $# -gt 0 ]]; then files=("$@"); else files=(); while IFS= read -r f; do files+=("$f"); done < <(git ls-files); fi

status=0
report() { # <message> <grep output>
  [[ -z "$2" ]] && return
  echo "[pii] $1 (value hidden) in:" >&2
  cut -d: -f1,2 <<<"$2" | sed 's/^/  /' >&2
  status=1
}
not_self() { grep -v '^tools/pii-check.sh:' || true; }
[[ -s "$patterns" ]] && report "found a personal value" "$(grep -nHIF -f "$patterns" -- "${files[@]}" 2>/dev/null | not_self)"
report "found a macOS home path" \
  "$(grep -nHIE -- '/Users/[A-Za-z0-9._-]+/' "${files[@]}" 2>/dev/null | not_self | grep -vE '/Users/(Shared|runner)/')"

# CI has no local identity: only the history check applies there.
if [[ -z "${CI:-}" && "$(git config user.email || true)" != *@users.noreply.github.com ]]; then
  echo "[pii] commits here must use the GitHub noreply address:" >&2
  echo "  git config user.email '<id>+<login>@users.noreply.github.com'" >&2
  status=1
fi
# Locally only the commits not pushed yet matter; CI checks the whole history once.
range=(); [[ -z "${CI:-}" ]] && git rev-parse -q --verify '@{upstream}' >/dev/null && range=('@{upstream}..HEAD')
if git log --format='%ae%n%ce' "${range[@]+"${range[@]}"}" | sort -u |
  grep -v '@users.noreply.github.com$' | grep -qvxE 'noreply@(anthropic|github)\.com'; then
  echo "[pii] history has non-noreply author/committer emails (rewrite before pushing)" >&2
  status=1
fi

[[ $status -eq 0 ]] && echo "[ok] no PII"
exit $status
