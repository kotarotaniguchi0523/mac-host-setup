#!/bin/bash
# mise-bin-update.sh - pin the official mise release binary (pkgs/mise-bin.json) to the newest
# release that is at least MIN_AGE_DAYS old, after verifying it the way mise's docs describe:
#   1. GitHub artifact attestation (SLSA provenance from jdx/mise's release workflow)
#   2. SHASUMS256.asc: GPG clear-signed by mise's release key (fingerprint pinned below),
#      and the tarball's sha256 equals the signed line
# Only then is the version + sha256 written; Nix (pkgs/mise-bin.nix) re-checks the hash on install.
#
# Usage: tools/ci/mise-bin-update.sh [<version>]   (default: newest release >= MIN_AGE_DAYS old)
# Needs: gh (token), gpg, jq. Prints "changed=true|false" (also to $GITHUB_OUTPUT).
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/../lib.sh"
cd "$repo"
MIN_AGE_DAYS="${MIN_AGE_DAYS:-2}"
# Public fingerprint of mise's release signing key (docs: installing-mise.md); not a secret.
SIGNER_FPR="24853EC9F655CE80B48E6C3A8B81C9D17413A06D" # gitleaks:allow
pin="pkgs/mise-bin.json"
asset_for() { echo "mise-v$1-macos-arm64.tar.gz"; }

if [[ -n "${1:-}" ]]; then
  version="${1#v}"
else
  until="$(date -u -d "-${MIN_AGE_DAYS} days" +%s 2>/dev/null || date -u -v-"${MIN_AGE_DAYS}"d +%s)"
  version="$(gh api 'repos/jdx/mise/releases?per_page=30' --jq "[.[] | select(.draft | not) | select(.prerelease | not)
    | select((.published_at | fromdateiso8601) <= $until)][0].tag_name" | sed 's/^v//')"
fi
[[ -n "$version" ]] || die "no mise release older than $MIN_AGE_DAYS days"
current="$(jq -r .version "$pin" 2>/dev/null || true)"
if [[ "$version" == "$current" ]]; then
  echo "[i] mise $version already pinned"; echo "changed=false"
  [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "changed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
asset="$(asset_for "$version")"
gh release download "v$version" -R jdx/mise -D "$work" -p "$asset" -p SHASUMS256.asc

# 1. provenance: built by jdx/mise's own release workflow
gh attestation verify "$work/$asset" --repo jdx/mise >/dev/null
echo "[ok] attestation: $asset was built by jdx/mise"

# 2. GPG: SHASUMS256.asc signed by the pinned key, and the tarball matches the signed line
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --keyserver hkps://keys.openpgp.org --recv-keys "$SIGNER_FPR"
status="$(gpg --batch --status-fd 1 --output "$work/SHASUMS256.txt" --decrypt "$work/SHASUMS256.asc" 2>/dev/null)"
grep -q "^\[GNUPG:\] VALIDSIG $SIGNER_FPR " <<<"$status" || die "SHASUMS256.asc is not signed by $SIGNER_FPR"
signed="$(awk -v a="./$asset" '$2 == a { print $1 }' "$work/SHASUMS256.txt")"
actual="$(shasum -a 256 "$work/$asset" | cut -d' ' -f1)"
[[ -n "$signed" && "$signed" == "$actual" ]] || die "sha256 of $asset ($actual) does not match the signed SHASUMS256 ($signed)"
echo "[ok] gpg: SHASUMS256 signed by $SIGNER_FPR; $asset sha256 $actual"

jq -n --arg version "$version" --arg sha256 "$actual" \
  --arg url "https://github.com/jdx/mise/releases/download/v$version/$asset" \
  '{version: $version, url: $url, sha256: $sha256}' > "$pin"
echo "[ok] pinned mise $current -> $version"
echo "changed=true"
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "changed=true" >> "$GITHUB_OUTPUT"
exit 0
