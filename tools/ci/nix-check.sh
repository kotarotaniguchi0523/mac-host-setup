#!/bin/bash
# nix-check.sh - format check, flake check and a full build of the nix-darwin system (no activation).
# Usage: tools/ci/nix-check.sh   (host or CI; needs Nix)
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
nix_env

git ls-files -z '*.nix' | xargs -0 nix fmt -- --check
echo "[ok] nixfmt"
nix flake check --impure --no-build
echo "[ok] flake check"
echo "[ok] built $(build_system)"
