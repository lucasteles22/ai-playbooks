---
name: regression-validation
description: Use when you need to validate a feature branch/PR end-to-end before merging it — checking for regressions via live API, integration, and usability testing, real database migrations, and deploy-build readiness, scoped to what actually changed. Expensive and slow (spins up local infra, drives a real browser) — only run when explicitly asked, never opportunistically.
disable-model-invocation: true
---

# Regression Validation

## Overview

Answers one question with real evidence, not assumptions: **"Is this
branch/PR actually safe to merge?"** It goes beyond unit tests — it spins
up the real dependencies (database, backend server, frontend dev server),
exercises the actual changed behavior live, and verifies outcomes directly
in the system of record (database, HTTP responses), not just through the
UI or through mocks.

This is expensive (minutes, real infrastructure, a real browser). Only run
it when explicitly asked — directly (`/regression-validation`) or via
another caller that exposes it as a flag/step (e.g. a personal pipeline
command that has a `--validate` option, if the caller has one). Never
trigger it opportunistically just because a request sounds
validation-adjacent.

**Announce at start:** "I'm using the regression-validation skill to check
this branch for regressions before it's considered safe to merge."

## Non-negotiable ground rules

- **Never touch infrastructure you didn't start.** Before starting any
  local service (Postgres, a dev server, anything with a port), check
  what's already running (`docker ps`, `lsof -i :<port>`) and never
  stop/reuse/reconfigure something you didn't launch yourself. If a
  default port is taken by something else, use an alternate port for your
  own throwaway instance instead of touching the existing one.
- **Never perform a real deploy.** Deploy/infra validation in this skill
  means confirming the project's own build artifacts succeed locally
  (`docker build`, a production frontend build, etc.) — it never pushes to
  a real registry, staging environment, or production. An actual deploy is
  a separate, high-risk action that needs its own explicit human
  confirmation, every time.
- **Never fabricate results.** Every claim in the final report must trace
  to a command you actually ran and output you actually read in this
  session — don't claim something works, passes, or is fixed without
  having just verified it directly. If something couldn't be tested (e.g.
  no reachable database, Docker not running), say so explicitly instead of
  assuming it's fine.
- **Always clean up**, even on failure: stop/remove every process and
  container this run started, confirm `git status` is unchanged, confirm
  no scratch env files got staged or committed.

## Step 0: Determine the target

- If invoked with a branch, PR reference, or worktree path (e.g. from a
  caller pipeline), make sure that branch is checked out — reuse whatever
  worktree/branch resolution the caller already did rather than
  re-deriving it.
- If invoked standalone with no target, validate the current working
  tree as-is.
- Either way, confirm `git status --short` is clean before starting. If
  it isn't, stop and ask — don't validate a dirty tree and don't discard
  uncommitted work to make it clean.

## Step 1: Detect scope

Diff against the merge-base with the repo's default branch:

```bash
git merge-base HEAD origin/<default-branch>
git diff --name-only <merge-base>...HEAD
```

Classify each changed path by locating the nearest project manifest above
it, walking up from the changed file:

- `go.mod`, `requirements.txt`/`pyproject.toml`, a `Gemfile`, etc. →
  **backend**
- `package.json` whose dependencies include a UI framework (react, vue,
  next, vite, svelte) → **frontend**
- `Dockerfile`, `docker-compose.yml`, a migrations directory, CI config
  (`.github/workflows`, `.gitlab-ci.yml`) → **infra**

If a repo has multiple backend/frontend manifests (a monorepo), classify
per top-level app directory rather than repo-wide.

If any changed path can't be confidently classified, or the change spans
ambiguous territory, **default to treating the scope as "both" (backend +
frontend)** — the more complete validation path. Never narrow the scope
to save time when uncertain.

State the detected scope explicitly before proceeding (e.g. "Scope:
backend + frontend — N files changed under `backend/`, M under
`frontend/`").

## Step 2: Stand up infrastructure for what's in scope

Discover the project's own tooling rather than assuming a stack — read
its `Makefile`/`package.json` scripts/`docker-compose.yml` to find the
real commands, the way you'd explore any unfamiliar repo.

- **Backend in scope:**
  - Find the project's own way to run a local database (usually
    `docker-compose.yml` near the backend, or a Makefile target). Start
    just the database service, on an alternate host port if the default
    is already occupied by something you didn't start. Wait for it to
    report healthy before continuing.
  - Point the backend at that database via a scratch env file (never
    committed — confirm it's gitignored, or use a path outside the repo).
  - Start the backend through its normal entrypoint so migrations run the
    same way they would in production (most frameworks run migrations on
    startup; if not, run the project's explicit migrate command). Capture
    startup logs and confirm migrations actually applied — don't assume.
  - Verify the server is actually listening (a health check or a
    lightweight `GET`) before treating it as ready.
- **Frontend in scope:**
  - Install dependencies if needed, matching the project's package
    manager.
  - If backend is also in scope, start the frontend dev server pointed at
    the backend instance you just started (its own scratch env var for
    the API base URL — check how the project already does this, e.g. a
    `VITE_*`/`NEXT_PUBLIC_*` env var).

## Step 3: Execute tests by scope

### Backend

1. Run the full existing backend test suite **against the real local
   database**, not against mocks — this exercises any integration tests
   that would otherwise skip without a reachable database. Capture and
   report the actual pass/fail counts; zero tolerance for silently
   ignoring a failure.
2. Read the diff to identify which endpoints/behaviors actually changed.
   Do a live functional smoke test of exactly those, via direct HTTP
   calls (curl or equivalent) against the running server — not just what
   the unit tests already cover. Cover:
   - The happy path with realistic input
   - Auth: confirm protected routes reject unauthenticated/unauthorized
     requests, and public routes that should NOT require auth don't
   - Validation: missing/invalid required fields return the expected
     error, not a 500 or a silent success
   - Not-found / edge-case IDs
   - Any new state transition the change introduces (e.g. a status field
     flipping) — verify the transition actually happened by reading it
     back, not just trusting a 200 response
3. If the change touches a database schema, inspect it directly
   (`\d <table>` or equivalent) to confirm the migration produced exactly
   what was intended.

### Frontend

1. Run the unit/component test suite fresh, plus lint, plus a production
   build — all from a clean state, not reusing stale output.
2. If lint reports any errors, diff them against what the base branch
   would report (or check if they're in files this branch didn't touch)
   before calling anything a regression — pre-existing errors elsewhere
   in the repo are not this branch's fault and must not be reported as
   such.

### Backend + frontend (both in scope)

In addition to the above: drive a real browser through the actual
user-facing flow the change introduces or modifies, end-to-end, against
the live local backend from Step 2 — not against mocks, not against a
test double. Use whatever browser-automation capability this assistant
has access to (e.g. an MCP browser tool, or the tool's own built-in
browser capability). For every meaningful state change the flow claims to
cause, verify it directly in the database or via a direct API call —
don't rely solely on what the UI displays, since a UI bug could show a
false success. This is the highest-value layer: it's the only check that
proves the frontend and backend you just validated separately actually
work together.

### Frontend only (backend unchanged)

Same browser-driven usability pass as above, but there's no need to spin
up a fresh backend if one is already reachable (a local instance already
running, or a known dev/staging API the frontend is configured to use).
Exercise the changed UI flow plus one or two adjacent pre-existing flows
the change could plausibly have affected (e.g. a shared component, a
shared hook) — a light regression check on neighbors, not a full sweep of
the whole app.

## Step 4: Deploy/infra build check

If the scope (or the repo generally) includes a `Dockerfile`, run
`docker build` on it and confirm it succeeds — this alone catches a
surprising number of "works on my machine" issues (missing files in
`.dockerignore`, build-stage dependency gaps) that unit tests never touch.
If the frontend has its own production build step, confirm it succeeds
(this may already be covered by Step 3's frontend build).

**Never deploy anywhere** — no push to a registry, no `vercel deploy`, no
`fly deploy`, nothing that touches shared/remote infrastructure. That is
always a separate, explicitly-confirmed action.

If the repo has no CI configuration at all, say so explicitly in the
final report — it means this validation run is the only safety net this
change gets before merging, which is worth knowing.

## Step 5: Clean up

- Stop and remove every process and container this run started.
- Confirm ports/services you didn't start are untouched and still
  running normally.
- Confirm `git status --short` shows no unexpected changes.
- Confirm no scratch `.env` or credential file got staged, committed, or
  left untracked-but-dirty in a way that could surprise the next person
  to touch this worktree.

## Step 6: Report

Produce a structured report:

- **Scope**: what was detected as changed (backend/frontend/both/infra)
  and why.
- **What ran**: every check actually performed, backend and frontend,
  with real pass/fail counts — not "tests were run," but "142/142 backend
  tests passed against a real Postgres; 550/550 frontend tests passed;
  lint clean; production build succeeded."
- **Live checks performed**: the specific endpoints/flows exercised live
  and what was confirmed (e.g. "submitted via the real UI → verified
  `pending` status in DB → approved via admin UI → verified `approved` in
  DB and visible on the public endpoint").
- **Findings**: anything that looks like a real regression, with enough
  detail to reproduce and fix it. Distinguish clearly between a real
  regression and a pre-existing issue unrelated to this change.
- **Verdict**, as the last line, in exactly this form so a caller (like a
  pipeline's `--validate --merge` step) can parse it reliably:
  - `✅ Safe to merge` — everything checked came back clean.
  - `❌ Do not merge — <short reason>` — at least one real regression or
    an environment that couldn't be validated cleanly.

Never soften a real finding into a "safe to merge" verdict to be
agreeable — the entire point of this skill is to be the honest check
before something ships.
