# lib.sh - shared helpers for tools/*.sh and tools/ci/*.sh. Source it, do not run it:
#   . "$(dirname "$0")/lib.sh"        (tools/)
#   . "$(dirname "$0")/../lib.sh"     (tools/ci/)
# shellcheck shell=bash

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "error: $1" >&2; exit "${2:-1}"; }

# Nix on PATH (the daemon profile is not loaded in every shell, e.g. CI steps and launchd)
# and the flake commands enabled even before nix-darwin manages nix.conf.
nix_env() {
  # shellcheck disable=SC1091
  [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] &&
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  export NIX_CONFIG="extra-experimental-features = nix-command flakes"
}

# The declared tools first, in the same order as the activated shell: user profile, then system.
# Needed by scripts started from a shell that predates the activation, and by launchd.
host_path() {
  export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
}

# GitHub API auth for mise (release lookups, checksum / attestation checks): unauthenticated
# requests share a 60/h per-IP limit. The gh token is short-lived (expiring OAuth), so it is read
# fresh for this process only and never stored. No-op when gh is missing or logged out.
github_auth() {
  [[ -n "${GITHUB_TOKEN:-}" ]] && return 0
  local token
  token="$(gh auth token 2>/dev/null)" || return 0
  export GITHUB_TOKEN="$token"
}

# mise for the global lane only (run from $HOME so this repository's mise.toml does not apply).
mise_global() { (cd "$HOME" && mise "$@"); }

# The global mise lane: mise/mise.toml -> <dir>/config.toml, mise/mise.lock -> <dir>/mise.lock,
# mise/locks/ -> <dir>/locks/ (aube's npm dependency graphs; mise.lock pins them by digest)
install_global_mise_config() {
  mkdir -p "$1"
  cp "$repo/mise/mise.toml" "$1/config.toml"
  cp "$repo/mise/mise.lock" "$1/mise.lock"
  rm -rf "$1/locks"
  [[ -d "$repo/mise/locks" ]] && cp -R "$repo/mise/locks" "$1/locks"
  return 0
}

# The system the host activates and CI builds.
build_system() {
  nix build --no-link --print-out-paths --impure ".#darwinConfigurations.default.system"
}

# APM (Skills): the build pinned by flake.lock (.#apm = nixpkgs apm-cli), the same one the host has
# on PATH. Resolved through the flake so CI and scripts started before activation use that version.
apm_bin() {
  local out
  out="$(nix build --no-link --print-out-paths ".#apm")" || return 1
  echo "$out/bin/apm"
}

# Run apm with <home> as HOME (user scope = <home>/.apm, Claude target = <home>/.claude/skills).
# GITHUB_TOKEN (github_auth) is passed for this process only, against the GitHub API rate limit.
apm_in() { # <home> <apm> <args...>
  local h="$1" bin="$2"
  shift 2
  (cd "$h/.apm" && HOME="$h" GITHUB_APM_PAT="${GITHUB_TOKEN:-}" COLUMNS=200 "$bin" "$@")
}
