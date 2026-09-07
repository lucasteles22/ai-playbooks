#!/usr/bin/env bash
# Syncs this repo's canonical artifacts into each AI tool's own config
# directory. This repo is the source of truth; the tool directories are
# just the destinations each tool actually reads from.
#
# Usage:
#   ./sync.sh          # copy for real
#   ./sync.sh -n        # dry run — print what would be copied, change nothing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

if [[ "${1:-}" == "-n" ]]; then
  DRY_RUN=true
fi

copy_dir() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    echo "[dry-run] would copy $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  echo "synced: $dest"
}

copy_file() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    echo "[dry-run] would copy $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "synced: $dest"
}

# Skills: portable across every tool that reads the Agent Skills format.
for skill_dir in "$REPO_DIR"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  copy_dir "$skill_dir" "$HOME/.claude/skills/$name"
  copy_dir "$skill_dir" "$HOME/.cursor/skills/$name"
  copy_dir "$skill_dir" "$HOME/.codex/skills/$name"
done

# Claude Code commands: no portable equivalent elsewhere yet.
if [[ -f "$REPO_DIR/claude/commands/orchestrator.md" ]]; then
  copy_file "$REPO_DIR/claude/commands/orchestrator.md" "$HOME/.claude/commands/orchestrator.md"
fi

if $DRY_RUN; then
  echo "(dry run — nothing was actually copied)"
fi
