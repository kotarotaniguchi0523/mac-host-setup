#!/bin/bash
# push-and-dispatch.sh - commit <files> as github-actions[bot], push to <branch>, then start ci.yml
# there (pushes made with GITHUB_TOKEN do not trigger workflows by themselves).
# Usage: tools/ci/push-and-dispatch.sh <branch> <message> <file>...   (needs GH_TOKEN)
set -euo pipefail
branch="${1:?branch}" message="${2:?message}"
shift 2
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git switch -C "$branch"
git commit -m "$message" -- "$@"
git push --force origin "$branch"
gh workflow run ci.yml --ref "$branch"
