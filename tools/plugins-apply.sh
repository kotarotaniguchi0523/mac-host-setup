#!/bin/bash
# plugins-apply.sh - install the Claude Code plugins declared in claude-plugins/ (a local marketplace
# whose entries pin a full commit SHA) for this user. Called by tools/update.sh; safe to run alone.
#
# Claude Code fetches each plugin at the pinned commit (git-subdir + sha) and records it in
# ~/.claude/plugins/installed_plugins.json (gitCommitSha), which tools/check.sh compares.
# Never run `claude plugin marketplace add <owner>/<repo>` or `/plugin install` by hand: a plugin
# outside this marketplace is a stray, and the version changes only through a PR to marketplace.json.
set -euo pipefail
# shellcheck source=tools/lib.sh
. "$(dirname "$0")/lib.sh"
cd "$repo"
host_path

mkt="$repo/claude-plugins"
json="$mkt/.claude-plugin/marketplace.json"
command -v claude >/dev/null || { echo "[!] claude not found; Claude Code plugins not applied"; exit 0; }
name="$(jq -r .name "$json")"

claude plugin validate "$mkt" >/dev/null || die "claude plugin validate failed for $mkt" 4
# Registers the marketplace, or re-points it when the repository has moved (same name, new path).
claude plugin marketplace add "$mkt"
claude plugin marketplace update "$name"
jq -r '.plugins[].name' "$json" | while IFS= read -r p; do
  claude plugin install "$p@$name" # no-op when already installed
  claude plugin update "$p@$name"  # moves to the commit pinned now
  claude plugin enable "$p@$name" 2>/dev/null || true
done
echo "[ok] Claude Code plugins applied ($name)"
