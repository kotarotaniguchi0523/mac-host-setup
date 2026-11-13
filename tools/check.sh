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
#   skills   : ~/.apm matches skills/ and every file the APM lock deploys is present
#   plugins  : every Claude Code plugin in claude-plugins/ is installed at its pinned commit and
#              enabled, and no plugin from another marketplace is installed
#   strays   : global installs outside the declarations (~/.local/bin, npm -g, uv tool, nix profile,
#              Homebrew)
#   op       : /usr/local/bin/op (nix-darwin programs._1password) is signed by AgileBits
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

# --- skills (APM) ----------------------------------------------------------------------
# Compared with the files only (no apm run, so no network and no writes).
cmp -s "$repo/skills/apm.yml" "$HOME/.apm/apm.yml" || add "skills: ~/.apm/apm.yml differs from skills/apm.yml"
if cmp -s "$repo/skills/apm.lock.yaml" "$HOME/.apm/apm.lock.yaml"; then
  gone="$(awk '/^  deployed_files:/{f=1; next} /^  [a-z_]+:/{f=0} f && /^  - /{print $2}' "$HOME/.apm/apm.lock.yaml" |
    while IFS= read -r p; do [[ -e "$HOME/$p" ]] || echo "$p"; done | head -n 5 | paste -sd' ' -)"
  [[ -n "$gone" ]] && add "skills: deployed files missing: $gone"
else
  add "skills: ~/.apm/apm.lock.yaml differs from skills/apm.lock.yaml"
fi

# --- Claude Code plugins ----------------------------------------------------------------
# Read from the files Claude Code writes (no claude run, so no network and no writes).
mkt_json="$repo/claude-plugins/.claude-plugin/marketplace.json"
cc_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
installed="$cc_dir/plugins/installed_plugins.json"
settings="$cc_dir/settings.json"
if [[ -f "$mkt_json" ]]; then
  mkt_name="$(jq -r .name "$mkt_json")"
  [[ "$(jq -r --arg m "$mkt_name" '.extraKnownMarketplaces[$m].source.path // empty' "$settings" 2>/dev/null)" == "$repo/claude-plugins" ]] ||
    add "plugins: marketplace $mkt_name is not registered from $repo/claude-plugins (run tools/update.sh)"
  while IFS=$'\t' read -r p sha; do
    id="$p@$mkt_name"
    got="$(jq -r --arg id "$id" '.plugins[$id][]? | select(.scope == "user") | .gitCommitSha' "$installed" 2>/dev/null | head -n 1)"
    if [[ -z "$got" ]]; then add "plugins: $id is not installed"
    elif [[ "$got" != "$sha" ]]; then add "plugins: $id is at ${got:0:12}, declared ${sha:0:12}"; fi
    [[ "$(jq -r --arg id "$id" '.enabledPlugins[$id] // false' "$settings" 2>/dev/null)" == "true" ]] ||
      add "plugins: $id is not enabled"
  done < <(jq -r '.plugins[] | [.name, .source.sha] | @tsv' "$mkt_json")
  others="$(jq -r --arg m "$mkt_name" '.plugins // {} | keys[] | select(endswith("@" + $m) | not)' "$installed" 2>/dev/null | paste -sd' ' -)"
  [[ -n "$others" ]] && add "stray: Claude Code plugins outside claude-plugins/: $others"
fi

# --- strays -----------------------------------------------------------------------------
# Approved exceptions (exceptions.tsv): self-updating vendor installs. Instead of reporting them as
# strays, verify every run that they still resolve to their expected location and are signed with an
# Apple-issued Developer ID certificate of the expected team (one codesign requirement covers both).
exception() { # <name> -> "team<TAB>path" from exceptions.tsv (exit 1 when not listed)
  awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3; found = 1 } END { exit !found }' "$repo/exceptions.tsv"
}
signed_by() { # <path> <team>: Apple-issued Developer ID certificate of <team> (bundles: --deep)
  codesign --verify --deep --strict -R="anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] and certificate leaf[field.1.2.840.113635.100.6.1.13] and certificate leaf[subject.OU] = \"$2\"" "$1" 2>/dev/null
}
verify_vendor() { # <name> <entry in ~/.local/bin> <team> <expected path glob>
  local real want="${4/#\~/$HOME}"
  real="$(readlink -f "$2" 2>/dev/null || echo "$2")"
  # shellcheck disable=SC2053 # glob match is intended
  [[ "$real" == $want ]] || { add "exception: $1 resolves to $real, expected $want"; return; }
  signed_by "$real" "$3" || add "exception: $1 ($real) is not signed with a Developer ID of team $3"
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
# App bundles in exceptions.tsv (GUI apps installed from the vendor's notarized DMG)
while IFS=$'\t' read -r name team path; do
  [[ "$path" == *.app ]] || continue
  if [[ ! -d "$path" ]]; then add "exception: $name not found at $path"
  elif ! signed_by "$path" "$team"; then add "exception: $name ($path) is not signed with a Developer ID of team $team"; fi
done < <(grep -v '^#' "$repo/exceptions.tsv")
# sbx: Nix installs Docker's prebuilt, signed bundle without running it in the build (home/default.nix),
# so its signature is checked here instead.
if sbx="$(command -v sbx)"; then
  sbx_app="$(realpath "$sbx")"; sbx_app="${sbx_app%/Contents/MacOS/sbx}"
  signed_by "$sbx_app" 9BNSXJN65R || add "sbx: $sbx_app is not signed with Docker's Developer ID (team 9BNSXJN65R)"
fi
# 1Password CLI: nix-darwin copies it to /usr/local/bin/op (the app integration needs that path).
# Not in cache.nixos.org (unfree), so the vendor's signature is checked here as well.
if [[ -e /usr/local/bin/op ]]; then
  signed_by /usr/local/bin/op 2BUA8C4S2C || add "op: /usr/local/bin/op is not signed with AgileBits' Developer ID (team 2BUA8C4S2C)"
fi
# Homebrew is forbidden (AGENTS.md); an installer run leaves these behind even with nothing installed.
for p in /opt/homebrew /usr/local/Homebrew /etc/paths.d/homebrew; do
  [[ -e "$p" ]] && add "stray: Homebrew at $p"
done
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
