#!/bin/bash
# install-nix.sh - install upstream Nix (official installer from releases.nixos.org), pinned and verified.
#
# Usage: tools/install-nix.sh            (run as your user; the installer asks for sudo itself)
#
# Verification chain:
#   1. NIX_VERSION is pinned exactly (no "latest", no redirect from nixos.org/nix/install).
#   2. The installer script is checked against INSTALL_SHA256 pinned in this file
#      (and against the .sha256 published next to it).
#   3. The installer itself embeds the sha256 of the binary tarball for each platform and
#      verifies the download before unpacking it.
# Limits (recorded in AUDIT.md): releases.nixos.org publishes no GPG signature (.asc) for
# 2.35.x, so the pinned hash is trust-on-first-use from the official origin.
set -euo pipefail

NIX_VERSION="2.35.6"
INSTALL_SHA256="6f7bf206efb54cd4941fb274930dbc74fdfc16fcb06757ef261c8d7d69cfd60e"
TARBALL_SHA256_AARCH64_DARWIN="75e6c8f3f488313a074aad454483b0ec8d23b3316e1af75f2762215942729690"
BASE="https://releases.nixos.org/nix/nix-${NIX_VERSION}"

if [[ "$(uname -s)-$(uname -m)" != "Darwin-arm64" ]]; then
  echo "error: this script supports macOS arm64 only" >&2; exit 2
fi
if command -v nix >/dev/null 2>&1 || [[ -d /nix/store ]]; then
  echo "[i] Nix is already installed: $(nix --version 2>/dev/null || echo '/nix exists')"; exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$work/install" "$BASE/install"
published="$(curl --proto '=https' --tlsv1.2 -fsSL "$BASE/install.sha256")"
actual="$(shasum -a 256 "$work/install" | cut -d' ' -f1)"

if [[ "$actual" != "$INSTALL_SHA256" || "$published" != "$INSTALL_SHA256" ]]; then
  echo "error: installer hash mismatch" >&2
  echo "  pinned   : $INSTALL_SHA256" >&2
  echo "  published: $published" >&2
  echo "  actual   : $actual" >&2
  exit 5
fi
if ! grep -q "hash=${TARBALL_SHA256_AARCH64_DARWIN}" "$work/install"; then
  echo "error: installer does not embed the pinned aarch64-darwin tarball hash" >&2; exit 5
fi
echo "[ok] installer verified (nix ${NIX_VERSION}, sha256 ${actual})"

# Multi-user (daemon) install, the only supported mode on macOS. --no-modify-profile is NOT
# used: the installer adds the nix-daemon profile hook to /etc/zshrc etc.
# --no-channel-add: no nix-channel; everything is pinned through flake.lock.
sh "$work/install" --daemon --yes --no-channel-add

# CI: later steps run in fresh shells that do not load the daemon profile.
[[ -n "${GITHUB_PATH:-}" ]] && echo "/nix/var/nix/profiles/default/bin" >> "$GITHUB_PATH"

echo
echo "[ok] Nix ${NIX_VERSION} installed. Open a new terminal, then run: tools/update.sh --bootstrap"
