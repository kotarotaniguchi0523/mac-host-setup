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
# Writes .agent/update-report.json. Exit 0 = clean, 5 = needs attention.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
notify=0; [[ "${1:-}" == "--notify" ]] && notify=1
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

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
  if [[ -f "$repo/mise/mise.lock" ]]; then
    cmp -s "$repo/mise/mise.lock" "$HOME/.config/mise/mise.lock" || add "mise: ~/.config/mise/mise.lock differs from mise/mise.lock"
  fi
  missing="$(cd "$HOME" && mise ls --missing --no-header 2>/dev/null | awk '{print $1"@"$2}' | paste -sd' ' -)"
  [[ -n "$missing" ]] && add "mise: not installed: $missing"
else
  add "mise: not found"
fi

# --- strays -----------------------------------------------------------------------------
if [[ -d "$HOME/.local/bin" ]]; then
  local_bins="$(find "$HOME/.local/bin" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -exec basename {} \; | paste -sd' ' -)"
  [[ -n "$local_bins" ]] && add "stray: ~/.local/bin has $local_bins"
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
{
  printf '{\n  "checkedAt": "%s",\n  "head": "%s",\n  "ok": %s,\n  "findings": [' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$head_rev" "$([[ ${#findings[@]} -eq 0 ]] && echo true || echo false)"
  sep=""
  for f in "${findings[@]+"${findings[@]}"}"; do
    esc="${f//\\/\\\\}"; esc="${esc//\"/\\\"}"
    printf '%s\n    "%s"' "$sep" "$esc"; sep=","
  done
  printf '\n  ]\n}\n'
} > "$repo/.agent/update-report.json"

if [[ ${#findings[@]} -eq 0 ]]; then
  echo "[ok] host matches origin/main ${head_rev:0:12}"
  exit 0
fi
if [[ $notify -eq 1 ]]; then
  /usr/bin/osascript -e "display notification \"${#findings[@]} item(s). See .agent/update-report.json\" with title \"mac-host-setup\"" || true
fi
exit 5
