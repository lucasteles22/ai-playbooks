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

Use the skill explicitly in a Codex chat or CLI session. In Codex CLI or the
IDE extension, mention it with `$orchestrator`; in the desktop app, select the
skill from the Skills UI:

```text
$orchestrator 31
$orchestrator https://github.com/org/repo/issues/31 --validate
$orchestrator 31 --merge
```

The skill accepts `--repo`, `--platform`, `--merge`, and `--validate`. It uses
Git worktrees created through the shell, optionally delegates independent work
to Codex subagents, and falls back to sequential execution when subagents are
unavailable.

`regression-validation` is never invoked by this skill. For Validation, the
skill reports the discovered branch/worktree/PR and commit SHA, then asks the
user to invoke `regression-validation` explicitly in a separate interaction.
With `--validate --merge`, it requires the same branch, PR/MR, and SHA after
validation and rechecks mergeability immediately before merging.

`install.sh` installs this directory as `$CODEX_HOME/skills/orchestrator` once
`SKILL.md` exists, including its `agents/openai.yaml` invocation policy.
