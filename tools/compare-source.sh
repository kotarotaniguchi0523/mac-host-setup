#!/bin/bash
# compare-source.sh - collect the facts for "Nix or mise?" (AGENTS.md, verification levels A-E).
#
# Usage: tools/compare-source.sh <nixpkgs-attr> [<mise-tool>]
#   e.g. tools/compare-source.sh gh gh
#        tools/compare-source.sh ripgrep aqua:BurntSushi/ripgrep
# Read-only: evaluates the pinned nixpkgs from flake.lock and asks mise for its Security line.
# The decision itself is written to AUDIT.md by a human (or agent) from this output.
set -uo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
attr="${1:?usage: compare-source.sh <nixpkgs-attr> [<mise-tool>]}"
tool="${2:-$1}"
nix_env

echo "== Nix (nixpkgs pinned by flake.lock) : $attr"
# One evaluation for every field (each `nix eval --impure` re-evaluates the whole flake).
info="$(nix eval --impure --json "$repo#darwinConfigurations.default.pkgs" --apply "pkgs:
  let p = pkgs.\"$attr\" or null; t = e: (builtins.tryEval e).value or null; in
  if p == null then null else {
    version = t p.version;
    provenance = t (map (s: s.shortName) (p.meta.sourceProvenance or [ ]));
    srcUrl = t (p.src.url or p.src.gitRepoUrl or null);
    srcHash = t (p.src.outputHash or null);
    broken = t (p.meta.broken or false);
    darwin = t (builtins.elem \"aarch64-darwin\" (p.meta.platforms or [ ]));
    out = t p.outPath;
  }" 2>/dev/null)"
if [[ -z "$info" || "$info" == null ]]; then
  echo "  not in nixpkgs"
else
  jq -r '"  version          : \(.version)",
         "  sourceProvenance : \(.provenance)   (empty/fromSource -> B, binary* -> C)",
         "  src.url          : \(.srcUrl)",
         "  src.outputHash   : \(.srcHash)",
         "  broken/darwin    : broken=\(.broken) aarch64-darwin=\(.darwin)"' <<<"$info"
  out="$(jq -r .out <<<"$info")"
  if sigs="$(nix path-info --store https://cache.nixos.org --sigs "$out" 2>/dev/null)"; then
    echo "  cache.nixos.org  : present, $(grep -o 'cache.nixos.org-1:[^ ]*' <<<"$sigs" | head -1 | cut -c1-40)..."
  else
    echo "  cache.nixos.org  : NOT in cache (would build locally)"
  fi
fi

echo
echo "== mise : $tool"
if command -v mise >/dev/null 2>&1; then
  mise_global tool "$tool" 2>&1 | grep -E '^(Backend|Security|Description)' | sed 's/^/  /' || echo "  mise tool failed"
  echo "  latest (>= 2d)   : $(mise_global latest "$tool" 2>/dev/null || echo '?')"
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
