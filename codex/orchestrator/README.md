# Codex-native orchestrator

This directory contains the Codex-native implementation of the issue-to-PR
workflow. It intentionally does not reuse
`claude/commands/orchestrator.md`; the Claude pipeline keeps its own
`superpowers:*` workflow and remains unchanged. See
[docs/orchestrator-portability-gaps.md](../../docs/orchestrator-portability-gaps.md)
for why a shared generic implementation was rejected in favor of separate
native ones that share only the external contract (flags, flows, stop
conditions).

## Invocation

Use the skill explicitly in a Codex chat or CLI session:

```text
Use the orchestrator skill with: 31
Use the orchestrator skill with: https://github.com/org/repo/issues/31 --validate
Use the orchestrator skill with: 31 --merge
```

The skill accepts `--repo`, `--platform`, `--merge`, and `--validate`. It uses
Git worktrees created through the shell, optionally delegates independent work
to Codex subagents, and falls back to sequential execution when subagents are
unavailable.

`regression-validation` is never invoked by this skill. For Validation, the
skill reports the discovered branch/worktree/PR and asks the user to invoke
`regression-validation` explicitly in a separate interaction.

`install.sh` installs this directory as `$CODEX_HOME/skills/orchestrator` once
`SKILL.md` exists.
