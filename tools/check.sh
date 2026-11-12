#!/bin/bash
# check.sh - read-only host check. Never installs, removes or uses sudo.
#
# Usage: tools/check.sh [--notify]
#   --notify  post a macOS notification when something needs attention (used by the launchd agent)
#
# Checks:
#   remote   : origin/main has commits this checkout has not applied yet
#   system   : the active nix-darwin generation was built from the current HEAD
#   mise     : ~/.config/mise matches mise/ and every locked tool is installed
#   strays   : global installs outside the declarations (~/.local/bin, npm -g, uv tool, nix profile)
#   exception: approved self-updating installs (exceptions.tsv) are still at their expected path and
#              signed with a Developer ID of the expected team (instead of being reported as strays)
# Writes .agent/update-report.json. Exit 0 = clean, 5 = needs attention.
set -uo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
cd "$repo" || exit 4
notify=0; [[ "${1:-}" == "--notify" ]] && notify=1
host_path

findings=()
add() { findings+=("$1"); echo "[!] $1"; }

# --- remote ---------------------------------------------------------------------------
if git fetch --quiet --prune origin 2>/dev/null; then
  behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
  [[ "$behind" != "0" ]] && add "remote: origin/main is $behind commit(s) ahead; run tools/update.sh"
else
  add "remote: git fetch failed (offline or no origin)"
fi
head_rev="$(git rev-parse HEAD)"

# --- system (nix-darwin) ----------------------------------------------------------------
if command -v darwin-version >/dev/null 2>&1; then
  sys_rev="$(darwin-version --configuration-revision 2>/dev/null || true)"
  [[ "$sys_rev" != "$head_rev" ]] && add "system: active generation is ${sys_rev:-unknown}, HEAD is ${head_rev:0:12}"
else
  add "system: nix-darwin is not activated yet (run tools/update.sh --bootstrap)"
fi

# --- mise -------------------------------------------------------------------------------
if command -v mise >/dev/null 2>&1; then
  cmp -s "$repo/mise/mise.toml" "$HOME/.config/mise/config.toml" || add "mise: ~/.config/mise/config.toml differs from mise/mise.toml"
  cmp -s "$repo/mise/mise.lock" "$HOME/.config/mise/mise.lock" || add "mise: ~/.config/mise/mise.lock differs from mise/mise.lock"
  missing="$(mise_global ls --missing --no-header 2>/dev/null | awk '{print $1"@"$2}' | paste -sd' ' -)"
  [[ -n "$missing" ]] && add "mise: not installed: $missing"
else
  add "mise: not found"
fi

# --- strays -----------------------------------------------------------------------------
# Approved exceptions (exceptions.tsv): self-updating vendor installs. Instead of reporting them as
# strays, verify every run that they still resolve to their expected location and are signed with an
# Apple-issued Developer ID certificate of the expected team (one codesign requirement covers both).
exception() { # <name> -> "team<TAB>path" from exceptions.tsv (exit 1 when not listed)
  awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3; found = 1 } END { exit !found }' "$repo/exceptions.tsv"
}
verify_vendor() { # <name> <entry in ~/.local/bin> <team> <expected path glob>
  local real req want="${4/#\~/$HOME}"
  real="$(readlink -f "$2" 2>/dev/null || echo "$2")"
  # shellcheck disable=SC2053 # glob match is intended
  [[ "$real" == $want ]] || { add "exception: $1 resolves to $real, expected $want"; return; }
  req="anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] and certificate leaf[field.1.2.840.113635.100.6.1.13] and certificate leaf[subject.OU] = \"$3\""
  codesign --verify --strict -R="$req" "$real" 2>/dev/null ||
    add "exception: $1 ($real) is not signed with a Developer ID of team $3"
}
if [[ -d "$HOME/.local/bin" ]]; then
  strays=()
  while IFS= read -r f; do
    name="$(basename "$f")"
    if exc="$(exception "$name")"; then
      verify_vendor "$name" "$f" "${exc%%$'\t'*}" "${exc#*$'\t'}"
    else
      strays+=("$name")
    fi
  done < <(find "$HOME/.local/bin" -mindepth 1 -maxdepth 1 \( -type f -o -type l \))
  [[ ${#strays[@]} -gt 0 ]] && add "stray: ~/.local/bin has ${strays[*]}"
fi
if command -v npm >/dev/null 2>&1; then
  npm_g="$(npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -n1 basename 2>/dev/null | grep -vE '^(npm|corepack)$' | paste -sd' ' -)"
  [[ -n "$npm_g" ]] && add "stray: npm -g has $npm_g"
fi
if command -v uv >/dev/null 2>&1; then
  uv_t="$(uv tool list 2>/dev/null | grep -vE '^(-|No tools)' | awk '{print $1}' | paste -sd' ' -)"
  [[ -n "$uv_t" ]] && add "stray: uv tool has $uv_t"
fi
if [[ -e "$HOME/.nix-profile/manifest.json" ]]; then
  np="$(nix profile list 2>/dev/null | awk '/^Name:/{print $2}' | paste -sd' ' -)"
  [[ -n "$np" ]] && add "stray: nix profile has $np"
fi

# --- report -----------------------------------------------------------------------------
mkdir -p "$repo/.agent"
jq -n --arg checkedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg head "$head_rev" \
  '{checkedAt: $checkedAt, head: $head, ok: ($ARGS.positional | length == 0), findings: $ARGS.positional}' \
  --args "${findings[@]+"${findings[@]}"}" > "$repo/.agent/update-report.json"

if [[ ${#findings[@]} -eq 0 ]]; then
  echo "[ok] host matches origin/main ${head_rev:0:12}"
  exit 0
fi
if [[ $notify -eq 1 ]]; then
  /usr/bin/osascript -e "display notification \"${#findings[@]} item(s). See .agent/update-report.json\" with title \"mac-host-setup\"" || true
fi
exit 5
