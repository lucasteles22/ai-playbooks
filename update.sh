#!/usr/bin/env bash
# Checks whether this repo's remote has commits this machine doesn't, and
# if so, pulls them and re-syncs into every tool's config directory.
#
# Usage:
#   ./update.sh          # check, and if there's an update, pull + sync
#   ./update.sh -n        # check only — report, change nothing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ONLY=false

if [[ "${1:-}" == "-n" ]]; then
  CHECK_ONLY=true
fi

cd "$REPO_DIR"

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree has uncommitted changes — commit or stash before updating." >&2
  exit 1
fi

git fetch origin --quiet

BRANCH="$(git symbolic-ref --short HEAD)"
UPSTREAM="origin/$BRANCH"

if [[ -z "$(git log "HEAD..$UPSTREAM" --oneline)" ]]; then
  echo "Already up to date with $UPSTREAM."
  exit 0
fi

echo "Update available on $UPSTREAM:"
git log "HEAD..$UPSTREAM" --oneline

if $CHECK_ONLY; then
  echo "(check only — run ./update.sh without -n to pull and sync)"
  exit 0
fi

git pull --ff-only origin "$BRANCH"
"$REPO_DIR/install.sh"
echo "Updated and installed."
