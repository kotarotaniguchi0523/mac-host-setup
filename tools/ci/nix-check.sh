#!/bin/bash
# nix-check.sh - format check, flake check and a full build of the nix-darwin system (no activation).
# Usage: tools/ci/nix-check.sh   (host or CI; needs Nix)
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"
# shellcheck disable=SC1091
[[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

mapfile_nix() { git ls-files '*.nix'; }
# shellcheck disable=SC2046
nix fmt -- --check $(mapfile_nix)
echo "[ok] nixfmt"
nix flake check --impure --no-build
echo "[ok] flake check"
out="$(nix build --no-link --print-out-paths --impure .#darwinConfigurations.default.system)"
echo "[ok] built $out"
