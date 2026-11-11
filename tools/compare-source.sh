#!/bin/bash
# compare-source.sh - collect the facts for "Nix or mise?" (AGENTS.md, verification levels A-E).
#
# Usage: tools/compare-source.sh <nixpkgs-attr> [<mise-tool>]
#   e.g. tools/compare-source.sh gh gh
#        tools/compare-source.sh ripgrep aqua:BurntSushi/ripgrep
# Read-only: evaluates the pinned nixpkgs from flake.lock and asks mise for its Security line.
# The decision itself is written to AUDIT.md by a human (or agent) from this output.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
attr="${1:?usage: compare-source.sh <nixpkgs-attr> [<mise-tool>]}"
tool="${2:-$1}"
export NIX_CONFIG="extra-experimental-features = nix-command flakes"
pkgs="$repo#darwinConfigurations.default.pkgs"

echo "== Nix (nixpkgs pinned by flake.lock) : $attr"
ev() { nix eval --impure "$@" 2>/dev/null; }
version="$(ev --raw "$pkgs.$attr.version")" || { echo "  not in nixpkgs"; version=""; }
if [[ -n "$version" ]]; then
  echo "  version          : $version"
  prov="$(ev --json "$pkgs.$attr.meta.sourceProvenance" || echo 'unset')"
  echo "  sourceProvenance : $prov   (fromSource -> B, binary* -> C, unset -> check src below)"
  echo "  src.url          : $(ev --raw "$pkgs.$attr.src.url" || ev --raw "$pkgs.$attr.src.gitRepoUrl" || echo '?')"
  echo "  src.outputHash   : $(ev --raw "$pkgs.$attr.src.outputHash" || echo '?')"
  echo "  broken/darwin    : broken=$(ev --json "$pkgs.$attr.meta.broken" || echo '?') platforms-ok=$(ev --json --apply 'ps: builtins.elem "aarch64-darwin" ps' "$pkgs.$attr.meta.platforms" || echo '?')"
  out="$(ev --raw "$pkgs.$attr.outPath")"
  if [[ -n "$out" ]] && nix path-info --store https://cache.nixos.org --sigs "$out" >/tmp/.cs.$$ 2>/dev/null; then
    echo "  cache.nixos.org  : present, $(grep -o 'cache.nixos.org-1:[^ ]*' /tmp/.cs.$$ | head -1 | cut -c1-40)..."
  else
    echo "  cache.nixos.org  : NOT in cache (would build locally)"
  fi
  rm -f /tmp/.cs.$$
fi

echo
echo "== mise : $tool"
if command -v mise >/dev/null 2>&1; then
  (cd "$HOME" && mise tool "$tool" 2>&1 | grep -E '^(Backend|Security|Latest|Description)' | sed 's/^/  /') || echo "  mise tool failed"
  echo "  latest (>= 2d)   : $(cd "$HOME" && mise latest "$tool" 2>/dev/null || echo '?')"
else
  echo "  mise not installed"
fi

cat <<'EOF'

== Decide (AGENTS.md)
  same level, or A(mise) vs B(nix)   -> Nix
  mise clearly higher (e.g. C vs A)  -> mise
  nix version has an unfixed CVE     -> mise (if fixed there)
  Record the result in AUDIT.md.
EOF
