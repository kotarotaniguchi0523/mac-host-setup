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
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
cd "$repo"
nix_env
bootstrap=0; [[ "${1:-}" == "--bootstrap" ]] && bootstrap=1

# --- 1. remote only ---------------------------------------------------------------------
[[ -z "$(git status --porcelain)" ]] || die "uncommitted changes in $repo (commit via PR, or discard)" 4
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main" 4
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --prune origin
  ahead="$(git rev-list --count origin/main..HEAD)"
  [[ "$ahead" == "0" ]] || die "$ahead local commit(s) not on origin/main; push them through a PR first" 4
  git merge --ff-only origin/main
  echo "[ok] at origin/main $(git rev-parse --short=12 HEAD)"
elif [[ $bootstrap -eq 1 ]]; then
  # Only the very first install of a brand-new repository may run before it is pushed
  # (the repository is published after the install is verified). Still committed + clean.
  echo "[!] no origin yet: bootstrapping from the committed HEAD $(git rev-parse --short=12 HEAD)"
else
  die "no origin remote; only --bootstrap may run before the first push" 4
fi

# --- 2. Nix: nix-darwin + home-manager --------------------------------------------------
# Build as the user (the flake reads USER/HOME via --impure), then activate with sudo.
# This is what darwin-rebuild switch does, without evaluating the flake as root.
sys="$(build_system)"
echo "[ok] built $sys"
if [[ $bootstrap -eq 1 ]]; then
  # nix-darwin refuses to overwrite /etc files it did not create. The Nix installer wrote these,
  # so move them aside once, only after a successful build (nix-darwin generates equivalents).
  for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
    if [[ -e "$f" && ! -L "$f" ]]; then sudo mv "$f" "$f.before-nix-darwin"; echo "[i] moved $f aside"; fi
  done
fi
sudo nix-env -p /nix/var/nix/profiles/system --set "$sys"
sudo "$sys/activate"
echo "[ok] nix-darwin activated"

# --- 3. mise (global lane) --------------------------------------------------------------
# Copy, not symlink: mise writes its lock next to the config (same as the Windows host).
install_global_mise_config "$HOME/.config/mise"
host_path # mise and the runtimes it needs (node / pnpm, python / uv) come from the new profiles
command -v mise >/dev/null || die "mise not found after activation" 4
# install, then drop versions no tracked config uses any more (e.g. a tool moved from mise to
# Nix) and rebuild the shims, so a removed tool cannot shadow its Nix replacement.
mise_global install --locked
mise_global prune --yes
mise_global reshim
echo "[ok] mise tools installed (locked)"

# --- 4. verify --------------------------------------------------------------------------
"$repo/tools/check.sh"
