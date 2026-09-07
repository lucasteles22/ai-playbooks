# orchestrator.md — portability gaps

`claude/commands/orchestrator.md` is a Claude Code slash-command that runs
a full issue→PR→merge pipeline. It's kept here versioned as-is, but it is
**not** portable to other tools without a real rewrite — it isn't a
reformatting job, it's a from-scratch reimplementation on top of each
tool's own primitives.

This table exists so that work doesn't start from zero if/when a
Cursor-native or Codex-native version is worth building.

| Mechanism (Claude Code) | Used in | Cursor equivalent | Codex CLI status |
|---|---|---|---|
| Background `Agent` tool dispatch | Flow 1 Step 4 (>3 tasks) | Subagents / Background Agents (`.cursor/agents/`) | Not researched — investigate |
| `EnterWorktree`/`ExitWorktree` native tools | Step 2, Flow 2 Step 5 | No named equivalent tool found; likely plain `git worktree` via shell | Not researched |
| `superpowers:using-git-worktrees` | Step 2 | Doesn't exist — would need to be written from scratch | Doesn't exist |
| `superpowers:brainstorming` / `writing-plans` | Step 3 | Doesn't exist — would need to be written from scratch | Doesn't exist |
| `superpowers:requesting-code-review` | Step 5a | Cursor ships built-in `review`/`review-bugbot`/`review-security` skills — closest real equivalent found so far | Not researched |
| `superpowers:subagent-driven-development` | Step 5b | Composable from Cursor's own Subagents, but nothing pre-built | Doesn't exist |
| `superpowers:finishing-a-development-branch` | Step 7, Flow 2 Step 5 | Doesn't exist — would need to be written from scratch | Doesn't exist |
| `regression-validation` skill | Flow 3 | **Already portable** — same `SKILL.md`, just copy | **Already portable** — same `SKILL.md`, just copy |
| `$ARGUMENTS` slash-command parsing | Top of file | Cursor commands (`.cursor/commands/*.md`) accept args similarly, no frontmatter required; Cursor Skills also support an `arguments` field | Codex Skills also support an `arguments` field (same shape) |

## Why this matters

The `superpowers` plugin (Anthropic's own bundled methodology library —
brainstorming, plan-writing, subagent-driven implementation, code review,
branch finishing) is the single biggest blocker. It's not just missing in
Cursor/Codex — it's a whole opinionated workflow that would need to be
redesigned per tool, not translated. `regression-validation`, by contrast,
was written without any dependency on it (aside from one dropped
reference during generalization), which is exactly why it ported cleanly
and `orchestrator.md` didn't.

## Not a task yet

This is reference material for a future, separate effort — not something
to build reactively. If it becomes worth doing, start from the "Cursor
equivalent" column above and treat each row as its own small task.
