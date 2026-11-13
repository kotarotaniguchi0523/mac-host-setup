#!/bin/bash
# nix-build.sh - build the whole nix-darwin system (what tools/update.sh activates) in CI, with a
# binary cache of what cache.nixos.org does not have (build.yml keeps <cache-dir> in the Actions
# cache: actions/cache/restore before, actions/cache/save after).
#
# Usage: tools/ci/nix-build.sh <cache-dir>     (CI only: it changes /etc/nix/nix.conf)
#   NIX_CACHE_PUBLIC_KEY  the key <cache-dir> is signed with; trusted for this run only
#   NIX_CACHE_SECRET_KEY  signs what this run builds into <cache-dir> (unset: nothing is added)
#
# The host never uses this cache (AGENTS.md: cache.nixos.org only). What is added is exactly the
# outputs this run had to build itself, signed, so the next run substitutes them instead.
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
nix_env
cache="${1:?usage: nix-build.sh <cache-dir>}"
[[ -n "${CI:-}" ]] || die "CI only (changes /etc/nix/nix.conf and restarts the daemon)" 2
target=".#darwinConfigurations.default.system"

# 1. trust the restored cache (its own key, next to cache.nixos.org) and restart the daemon
if [[ -f "$cache/nix-cache-info" && -n "${NIX_CACHE_PUBLIC_KEY:-}" ]]; then
  printf 'extra-substituters = file://%s\nextra-trusted-public-keys = %s\n' "$cache" "$NIX_CACHE_PUBLIC_KEY" |
    sudo tee -a /etc/nix/nix.conf >/dev/null
  sudo launchctl kickstart -k system/org.nixos.nix-daemon
  for _ in $(seq 60); do nix store info >/dev/null 2>&1 && break; sleep 1; done
  echo "[ok] using the restored cache ($(find "$cache" -name '*.narinfo' | wc -l | tr -d ' ') paths)"
else
  echo "[i] no restored cache: everything missing from cache.nixos.org is built"
fi

# 2. what this run has to build (not substitutable from cache.nixos.org or the restored cache)
plan="$(nix build --dry-run --impure "$target" 2>&1)"
built="$(awk '/will be built:$/ {f = 1; next} /^(these|this) / {f = 0} f && $1 ~ /^\/nix\/store\// {print $1}' <<<"$plan")"
echo "[i] derivations to build: $(grep -c . <<<"$built" || true)"

# 3. add whatever got built to the cache, also when the build fails or times out part way
#    (the outputs that exist are complete: Nix registers a path only after it is built)
save() {
  [[ -n "${NIX_CACHE_SECRET_KEY:-}" && -n "$built" ]] || return 0
  local key outs=()
  key="$(mktemp)"
  printf '%s' "$NIX_CACHE_SECRET_KEY" > "$key"
  while IFS= read -r p; do [[ -e "$p" ]] && outs+=("$p"); done < <(xargs nix-store -q --outputs <<<"$built")
  if [[ ${#outs[@]} -gt 0 ]]; then
    nix copy --no-recursive --to "file://$cache?compression=zstd&secret-key=$key" "${outs[@]}" &&
      echo "[ok] added ${#outs[@]} built paths to the cache"
  fi
  rm -f "$key"
}
trap save EXIT

echo "[ok] built $(build_system)"
