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

## Decision (2026-09-08): separate native implementations, not a shared core

A first attempt at a Codex port proposed the opposite approach: a single
generic "canonical skill" that both Claude Code and Codex would use,
with the `superpowers:*` references rewritten as generic concrete
instructions. That was rejected — it would have replaced Claude Code's
sophisticated, working pipeline (brainstorming's approval-gated path
classification, subagent-driven-development's task ledger and escalating
review rounds, etc.) with a simplified reimplementation, just to gain
portability. `claude/commands/orchestrator.md` stays untouched.

The actual direction: `codex/orchestrator/` gets its own from-scratch
implementation, sharing only the *external contract* with the Claude Code
version — same flags, same three flows (Delivery/Approval/Validation),
same stop conditions, same rule that `regression-validation` is only ever
user-invoked, never called programmatically. The internal mechanism for
each responsibility (workspace isolation, requirements/planning gate,
reviewed implementation, branch integration) is Codex's own to choose,
using whatever it actually has available — not a translation of Claude
Code's tool names. The full spec handed to Codex for this is not
committed here (it was sent directly), but `codex/orchestrator/README.md`
tracks its status.

If a similar Cursor-native version is ever worth building, follow the
same principle: separate implementation, shared contract only, starting
from the "Cursor equivalent" column above.
