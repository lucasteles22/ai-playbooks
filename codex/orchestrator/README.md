# codex/orchestrator — pending

This directory is where the Codex-native implementation of the
`/orchestrator` pipeline will live once it's built. It intentionally
does **not** reuse `claude/commands/orchestrator.md` — see
[docs/orchestrator-portability-gaps.md](../../docs/orchestrator-portability-gaps.md)
for why a shared generic implementation was rejected in favor of separate
native ones that share only the external contract (flags, flows, stop
conditions).

The spec for this work was handed to Codex directly (not committed here)
on 2026-09-08. `install.sh` already knows to pick this directory up and
install it to `$CODEX_HOME/skills/orchestrator` as soon as it's
non-empty — no script changes needed once the implementation lands here.
