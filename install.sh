#!/usr/bin/env bash
# Installs/syncs this repo's canonical artifacts into each AI tool's own
# config directory (Claude Code, Cursor, Codex CLI, opencode). This repo
# is the source of truth; the tool directories are just the destinations
# each tool actually reads from. Same script for a first install on a new
# machine and for re-syncing after an edit — running it is always safe
# and idempotent.
#
# Usage:
#   ./install.sh          # copy for real
#   ./install.sh -n        # dry run — print what would be copied, change nothing

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
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
  echo "installed: $dest"
}

copy_file() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    echo "[dry-run] would copy $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "installed: $dest"
}

# Skills: portable across every tool that reads the Agent Skills format.
for skill_dir in "$REPO_DIR"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  copy_dir "$skill_dir" "$HOME/.claude/skills/$name"
  copy_dir "$skill_dir" "$HOME/.cursor/skills/$name"
  copy_dir "$skill_dir" "$CODEX_HOME/skills/$name"
  # opencode also reads ~/.claude/skills/ natively, but install explicitly
  # into its own directory too so this doesn't depend on that fallback.
  copy_dir "$skill_dir" "$HOME/.config/opencode/skills/$name"
done

# Claude Code commands: no portable equivalent elsewhere yet.
if [[ -f "$REPO_DIR/claude/commands/orchestrator.md" ]]; then
  copy_file "$REPO_DIR/claude/commands/orchestrator.md" "$HOME/.claude/commands/orchestrator.md"
fi

# Codex-native orchestrator: only once it actually exists (the directory
# starts with just a README placeholder — see
# docs/orchestrator-portability-gaps.md — so gate on the real artifact,
# not on the directory being non-empty).
if [[ -f "$REPO_DIR/codex/orchestrator/SKILL.md" ]]; then
  copy_dir "$REPO_DIR/codex/orchestrator" "$CODEX_HOME/skills/orchestrator"
fi

if $DRY_RUN; then
  echo "(dry run — nothing was actually copied)"
fi
