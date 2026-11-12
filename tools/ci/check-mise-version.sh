#!/bin/bash
# check-mise-version.sh - the mise used in CI (.github/actions/setup-mise) must be the host's mise
# (nixpkgs in flake.lock), otherwise CI and the host write different lockfiles.
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
nix_env
want="$(nix eval --impure --raw .#darwinConfigurations.default.pkgs.mise.version)"
have="$(sed -n 's/^ *version: *//p' .github/actions/setup-mise/action.yml)"
[[ "$have" == "$want" ]] ||
  die "::error file=.github/actions/setup-mise/action.yml::mise $have in CI, $want in flake.lock (update the action)"
echo "[ok] CI mise $have = flake.lock mise"
