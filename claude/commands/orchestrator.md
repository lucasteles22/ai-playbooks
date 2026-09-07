---
description: Run the full issue-to-PR pipeline for one issue (fetch, brainstorm, plan, implement, review, PR), or merge/close/cleanup an already-delivered one
disable-model-invocation: true
---

Run the issue-to-PR pipeline described below for the issue given in
$ARGUMENTS. Parse $ARGUMENTS first:

- A bare number (e.g. `31`) → issue number, resolve repo from `git remote
  get-url origin` in the current directory.
- A full issue URL (e.g. `https://github.com/org/repo/issues/31` or
  `https://gitlab.com/org/repo/-/issues/31`) → parse platform, repo, and
  issue number from the URL directly; ignore cwd.
- `--repo org/repo` → overrides the repo resolved above.
- `--platform github|gitlab` → overrides platform detection.
- `--merge` → switches to Flow 2 (Approval) instead of Flow 1 (Delivery).
- `--validate` → switches to Flow 3 (Validation): runs the
  `regression-validation` skill against the issue's existing branch/PR and
  reports a pass/fail verdict. Combinable with `--merge`
  (`--validate --merge`): validate first, and only continue into Flow 2
  (merge) if the verdict is clean — if not, stop and show the findings
  instead of merging. `--validate` alone never merges, regardless of
  verdict.

If the issue number can't be parsed from $ARGUMENTS, stop and ask for it.

**Flow precedence:** `--validate` (Flow 3) takes priority over `--merge`
(Flow 2) when both are present — see Flow 3 below for how it hands off
into Flow 2. `--merge` alone (no `--validate`) runs Flow 2 directly, as
today. Neither flag runs Flow 1 (Delivery), the default.

## Step 0: Detect platform

Resolve the host from `git remote get-url origin` (or from the issue URL,
or from `--repo`/`--platform` if passed). `github.com` → use `gh`.
`gitlab.com`, or any other host when `--platform gitlab` was passed →
use `glab`. Verify the CLI is installed and authenticated:
`gh auth status` / `glab auth status`.

If the CLI is missing or not authenticated, stop:
"`<cli>` is not installed or not authenticated. Run `<cli> auth login`
and retry." Do not attempt to install or authenticate anything yourself.

If the platform can't be inferred and `--platform` wasn't passed, stop:
"Couldn't determine the forge platform from origin remote '<url>'. Pass
--platform github or --platform gitlab explicitly."

## Flow 3: Validation (--validate)

Handle this flow first if `--validate` is present in $ARGUMENTS, before
Flow 2 or Flow 1 — see Flow precedence above.

1. Find the branch/worktree and PR/MR for the issue, using exactly Flow
   2's Steps 1-2 below (same lookup, same stop conditions). Do not repeat
   this lookup again later if continuing into Flow 2 for a merge (see
   step 3 here).

2. Invoke the `regression-validation` skill against that branch/worktree.
   Let it fully determine and report scope, run its checks, clean up
   after itself, and produce its structured report ending in a
   `✅ Safe to merge` or `❌ Do not merge — <reason>` verdict line.

3. Branch on whether `--merge` was also passed:
   - **`--validate` alone:** print the skill's full report and stop here.
     Do not merge, do not touch the worktree beyond what the skill itself
     did.
   - **`--validate --merge` together:**
     - If the verdict is `✅ Safe to merge`: continue directly into Flow 2
       starting at **its Step 3** (merge) — the branch/PR are already
       known from this flow's Step 1, don't re-look them up.
     - If the verdict is `❌ Do not merge`: print the skill's full report
       and stop. Do not merge, do not touch the worktree.

## Flow 2: Approval (--merge)

Handle this flow first if `--merge` is present in $ARGUMENTS (and
`--validate` is not — see Flow 3 above for the combined case), instead of
Flow 1.

1. Find the branch/worktree matching `issue-<n>-*`:
   `git worktree list --porcelain` (look for a worktree whose branch
   matches) and `git branch --list "issue-<n>-*"` (in case the worktree
   was already removed but the branch remains). If zero matches, stop:
   "No branch or worktree found for issue <n>. Was it delivered with
   /orchestrator?" If more than one matches, list them and ask which one.

2. Find the PR/MR for that branch:
   `gh pr list --head <branch> --state open --json number,url,isDraft,mergeable`
   / `glab mr list --source-branch <branch>`. If none found, stop and
   report. If draft or not mergeable (conflicts), report the exact
   blocking state and stop — do not try to resolve conflicts
   automatically.

3. Determine merge method and merge:
   - GitHub: run
     `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`.
     Pick the first allowed method in this priority order: squash → merge
     → rebase. Run `gh pr merge <number> --squash` (or `--merge` /
     `--rebase`, matching the pick) `--delete-branch=false` (worktree
     cleanup in step 5 handles the local branch; leave the remote
     branch-deletion setting to the repo's own default).
   - GitLab: run `glab mr merge <id>` with no strategy flag — `glab`
     respects the project's configured default merge method.

4. Verify the issue closed: `gh issue view <n> --json state` / `glab
   issue view <n>`. If it's still open (the `Closes #<n>` keyword didn't
   register), close it explicitly as a fallback:
   `gh issue close <n> --comment "Closed via <pr-url>"` / `glab issue
   close <n>`.

5. Clean up the worktree: follow
   `superpowers:finishing-a-development-branch` Step 6 (remove via
   `git worktree remove`; if removal is refused because the worktree
   holds uncommitted files, show them to the user and ask — never force).

Report: "Merged <pr-url>, closed #<n>, removed worktree at <path>." Stop
here — do not continue to Flow 1.

## Flow 1: Delivery (default)

### Step 1: Fetch the issue

`gh issue view <n>` / `glab issue view <n>`. Capture the title and body
as the seed for brainstorming. Only fetch comments too
(`--comments` / `-c`) if the body references prior discussion, links a
comment, or reads as ambiguous without it — most issues don't need them.

### Step 2: Isolate workspace

Invoke `superpowers:using-git-worktrees`. Use branch name
`issue-<n>-<slug>`, where `<slug>` is generated from the issue title:
lowercase it, replace every run of non-alphanumeric characters with a
single hyphen, trim leading/trailing hyphens, truncate to 40 characters.
Base branch: the remote's default branch, freshly pulled.

If a branch or worktree matching `issue-<n>-*` already exists (a prior
run left it in place), resume in it instead of creating a new one —
report "Resuming existing worktree at <path>." If it already has commits
beyond the base branch, skip to Step 4 (Size gate); otherwise continue
at Step 3.

### Step 3: Requirements

Invoke `superpowers:brainstorming` with the fetched issue title, body,
and comments (if fetched) as the seed material. Follow that skill's own
path classification and approval gate as normal — do not shortcut it.
Do not invoke `superpowers:writing-plans` yourself: the architectural
path invokes it as its own terminal step; spike and bounded paths never
produce a plan document at all.

### Step 4: Size gate

- **Spike or bounded** → no plan document exists. Brainstorming's own
  approval gate was the only gate needed. Continue inline at Step 5a.
- **Architectural** → a plan document now exists (written by
  writing-plans, invoked from within brainstorming). Count its tasks and
  distinct files touched:
  - **≤3 tasks and 1 file/subsystem** → continue inline at Step 5a.
  - **>3 tasks, or multiple files/subsystems** → dispatch a background
    `general-purpose` Agent to run Step 5b through Step 8 inside the
    worktree created in Step 2, and report back with the PR URL once it
    reaches Step 8. Do not block waiting on it.

### Step 5a: Implement inline (small plans)

Implement the approved design (plan document, if one exists, or the
in-chat bounded design otherwise) directly in this session. When
complete, run one review pass via `superpowers:requesting-code-review`.
If it returns findings, fix them and request review again. Cap at 5
rounds total; if still unresolved at the cap, stop and show the user the
outstanding finding instead of opening a PR with it silently.

### Step 5b: Implement via subagent (medium+ plans)

Invoke `superpowers:subagent-driven-development` to execute the plan. It
already dispatches a fresh implementer subagent per task with its own
per-task review loop (capped at 5 rounds, escalating model on rounds
4–5) — do not add a second review loop on top of it.

### Step 6: Commit/push cadence

Commit locally at the end of each task/step, per the plan's own
granularity — no additional rule needed here. Push only twice per
delivery: once after implementation is complete and tests are green, and
again after any post-push fix round that changed committed code. Never
push on every individual edit.

### Step 7: Open the PR/MR

Invoke `superpowers:finishing-a-development-branch`, option "push + PR".
The PR/MR body **must** include `Closes #<n>` — this is what makes Flow
2's merge auto-close the issue on both GitHub and GitLab.

### Step 8: Report and stop

Print the PR/MR URL. Do not merge, close the issue, or delete the
worktree — that only happens via a later, explicit `/orchestrator <n>
--merge`.

## Stop conditions (always halt and ask, never guess)

- Forge CLI missing or not authenticated
- Platform can't be inferred and wasn't passed explicitly
- Any destructive or irreversible git operation
- Base branch conflicts with the assumed default
- Brainstorming or planning judged unworkable
- Baseline tests failing before implementation starts
- A review loop (Step 5a, or within subagent-driven-development) hits its
  5-round cap without resolution
- Flow 2 or Flow 3 can't uniquely locate a worktree/branch/PR for the
  issue number
- The PR/MR is a draft or has merge conflicts at merge time
- The regression-validation skill (Flow 3) reports a real regression, or
  can't establish a clean environment to validate in
