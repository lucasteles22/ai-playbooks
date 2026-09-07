# ai-playbooks

Personal AI-coding-assistant skills and command playbooks, versioned in one
place and synced out to each tool's own config directory.

## What's here

```
ai-playbooks/
├── skills/
│   └── regression-validation/
│       └── SKILL.md          # portable — Agent Skills format
├── claude/
│   └── commands/
│       └── orchestrator.md   # Claude Code only — see docs/orchestrator-portability-gaps.md
├── docs/
│   └── orchestrator-portability-gaps.md
└── sync.sh                   # copies the above into each tool's config dir
```

## Portability status

| Artifact | Format | Portable to | Notes |
|---|---|---|---|
| `skills/regression-validation` | [Agent Skills](https://agentskills.io) `SKILL.md` | Claude Code, Cursor, Codex CLI/ChatGPT | Same open format, same frontmatter, read natively by each tool from its own `skills/` directory. No tool-specific tricks needed. |
| `claude/commands/orchestrator.md` | Claude Code slash-command | Claude Code only | Depends on Claude-Code-only mechanics (background agent dispatch, native worktree tools, the `superpowers` skill library). See [docs/orchestrator-portability-gaps.md](docs/orchestrator-portability-gaps.md) for what a Cursor/Codex-native port would need. |

## Syncing to each tool

Each AI tool reads skills from its own personal config directory:

- Claude Code: `~/.claude/skills/`, `~/.claude/commands/`
- Cursor: `~/.cursor/skills/`
- Codex CLI: `~/.codex/skills/` (`$CODEX_HOME/skills`)

This repo is the source of truth. After editing anything here, run:

```bash
./sync.sh
```

It copies `skills/*` into all three tools' skill directories, and
`claude/commands/orchestrator.md` into Claude Code's commands directory
only (it has no portable equivalent elsewhere yet).

## Usage note

`regression-validation` is deliberately expensive (spins up local infra,
drives a real browser) and ships with `disable-model-invocation: true` —
it never auto-triggers from conversation context. Invoke it explicitly,
either directly (`/regression-validation`) or from a caller pipeline that
exposes it as a step/flag.
