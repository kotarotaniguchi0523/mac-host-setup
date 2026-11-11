#!/bin/bash
# update.sh - apply ONLY what was updated on the remote (origin/main) to this host.
#
# Usage:
#   tools/update.sh               fetch origin -> fast-forward to origin/main -> apply -> verify
#   tools/update.sh --bootstrap   first run on a new host (no darwin-rebuild yet); same checks
#
# Refuses to run when the worktree has uncommitted changes or local commits that are not on
# origin/main: the host never applies declarations that did not go through the remote (PR + CI).
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

die() { echo "error: $*" >&2; exit "${2:-1}"; }

# --- 1. remote only ---------------------------------------------------------------------
[[ -z "$(git status --porcelain)" ]] || die "uncommitted changes in $repo (commit via PR, or discard)" 4
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main" 4
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --prune origin
  ahead="$(git rev-list --count origin/main..HEAD)"
  [[ "$ahead" == "0" ]] || die "$ahead local commit(s) not on origin/main; push them through a PR first" 4
  git merge --ff-only origin/main
  rev="$(git rev-parse HEAD)"
  echo "[ok] at origin/main ${rev:0:12}"
elif [[ "${1:-}" == "--bootstrap" ]]; then
  # Only the very first install of a brand-new repository may run before it is pushed
  # (the repository is published after the install is verified). Still committed + clean.
  rev="$(git rev-parse HEAD)"
  echo "[!] no origin yet: bootstrapping from the committed HEAD ${rev:0:12}"
else
  die "no origin remote; only --bootstrap may run before the first push" 4
fi

# --- 2. Nix: nix-darwin + home-manager --------------------------------------------------
# Build as the user (the flake reads USER/HOME via --impure), then activate with sudo.
# This is what darwin-rebuild switch does, without evaluating the flake as root.
sys="$(nix build --no-link --print-out-paths --impure ".#darwinConfigurations.default.system")"
echo "[ok] built $sys"
if [[ "${1:-}" == "--bootstrap" ]]; then
  # nix-darwin refuses to overwrite /etc files it did not create. The Nix installer wrote
  # these, so move them aside once (only after a successful build) (nix-darwin generates equivalents, incl. the Nix env hook).
  for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
    if [[ -e "$f" && ! -L "$f" ]]; then sudo mv "$f" "$f.before-nix-darwin"; echo "[i] moved $f aside"; fi
  done
fi
sudo nix-env -p /nix/var/nix/profiles/system --set "$sys"
sudo "$sys/activate"
echo "[ok] nix-darwin activated"

# --- 3. mise (global lane) --------------------------------------------------------------
# Copy, not symlink: mise writes its lock next to the config (same as the Windows host).
mise_dst="$HOME/.config/mise"
mkdir -p "$mise_dst"
cp "$repo/mise/mise.toml" "$mise_dst/config.toml"
[[ -f "$repo/mise/mise.lock" ]] && cp "$repo/mise/mise.lock" "$mise_dst/mise.lock"
# The running shell predates the activation: put the new profiles first so mise finds the
# Nix-provided runtimes (node / pnpm for npm: tools, python / uv for pypi: tools).
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
mise="/etc/profiles/per-user/$USER/bin/mise"
[[ -x "$mise" ]] || mise="$(command -v mise)" || die "mise not found after activation" 4
# Run from $HOME so only the global config applies (not this repository's dev-tool config).
(cd "$HOME" && "$mise" install --locked)
echo "[ok] mise tools installed (locked)"

# --- 4. verify --------------------------------------------------------------------------
"$repo/tools/check.sh"
