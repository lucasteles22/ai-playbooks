# ai-playbooks

Personal AI-coding-assistant skills and command playbooks, versioned in one
place and installed out to each tool's own config directory.

## What's here

```
ai-playbooks/
├── skills/
│   └── regression-validation/
│       └── SKILL.md          # portable — Agent Skills format
├── claude/
│   └── commands/
│       └── orchestrator.md   # Claude Code only — see docs/orchestrator-portability-gaps.md
├── codex/
│   └── orchestrator/         # pending — Codex-native implementation, see its README
├── docs/
│   └── orchestrator-portability-gaps.md
├── install.sh                # installs the above into each tool's config dir
└── update.sh                 # git pull + install.sh, but only if there's actually an update
```

## Portability status

| Artifact | Format | Portable to | Notes |
|---|---|---|---|
| `skills/regression-validation` | [Agent Skills](https://agentskills.io) `SKILL.md` | Claude Code, Cursor, Codex CLI/ChatGPT, opencode | Same open format, same frontmatter, read natively by each tool from its own `skills/` directory. No tool-specific tricks needed. |
| `claude/commands/orchestrator.md` | Claude Code slash-command | Claude Code only | Depends on Claude-Code-only mechanics (background agent dispatch, native worktree tools, the `superpowers` skill library). Kept as-is, not generalized — see [docs/orchestrator-portability-gaps.md](docs/orchestrator-portability-gaps.md). |
| `codex/orchestrator` | TBD (Codex-native) | Codex only | Pending — a native reimplementation sharing only the external contract (flags/flows/stop conditions) with the Claude Code version, not its internal mechanics. See `codex/orchestrator/README.md`. |

## Installing on a tool/machine

Each AI tool reads skills from its own personal config directory:

- Claude Code: `~/.claude/skills/`, `~/.claude/commands/`
- Cursor: `~/.cursor/skills/`
- Codex CLI: `~/.codex/skills/` (or `$CODEX_HOME/skills` if set)
- opencode: `~/.config/opencode/skills/` (it also reads `~/.claude/skills/`
  natively, but this repo installs explicitly rather than relying on that)

This repo is the source of truth.

**New machine** — clone and install once:

```bash
git clone https://github.com/lucasteles22/ai-playbooks.git ~/dev/ai-playbooks
~/dev/ai-playbooks/install.sh
```

**After editing something here** — install again to push the change out:

```bash
./install.sh
```

**Existing machine, checking for updates made elsewhere:**

```bash
./update.sh       # pulls and installs only if the remote has new commits
./update.sh -n    # check only, print what's new, change nothing
```

`install.sh` copies `skills/*` into every tool's skill directory,
`claude/commands/orchestrator.md` into Claude Code's commands directory,
and `codex/orchestrator` into Codex's skills directory once that
implementation actually exists (it's a no-op until then). `update.sh`
refuses to run if the working tree has uncommitted changes, and only
pulls with `--ff-only` (never rewrites local history).

## Usage note

`regression-validation` is deliberately expensive (spins up local infra,
drives a real browser) and ships with `disable-model-invocation: true` —
it never auto-triggers from conversation context. Invoke it explicitly,
either directly (`/regression-validation`) or from a caller pipeline that
exposes it as a step/flag.
