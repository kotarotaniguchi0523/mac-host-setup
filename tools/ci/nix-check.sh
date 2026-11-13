#!/bin/bash
# nix-check.sh - the fast Nix checks (the required `nix` job): format, flake check, and evaluation
# of the whole nix-darwin system down to its derivation. The full build is tools/ci/nix-build.sh
# (build.yml, not required), because packages missing from cache.nixos.org can take an hour.
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
drv="$(nix eval --raw --impure ".#darwinConfigurations.default.system.drvPath")"
echo "[ok] evaluated $drv"
