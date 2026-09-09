---
name: orchestrator
description: Execute the Codex-native issue-to-PR workflow for a GitHub or GitLab issue, including delivery, approval/merge, and explicit regression-validation handoff. Use only when the user supplies an issue identifier and asks to run this workflow.
---

# Codex Orchestrator

Run this workflow when the user explicitly asks to use the orchestrator with
an issue number or issue URL. The documented invocation is:

```text
Use the orchestrator skill with: 31 --validate --merge
```

Treat the text after `with:` as the argument string. Parse it before taking
any repository action.

This is the Codex-native implementation. Do not reference or emulate Claude
Code tools or `superpowers:*`. The Claude implementation in
`claude/commands/orchestrator.md` is independent and must not be modified by
this workflow.

## Argument contract

Accept a bare issue number, a full GitHub or GitLab issue URL, and these flags:

- `--repo org/repo` overrides the repository;
- `--platform github|gitlab` overrides platform detection;
- `--merge` selects Approval;
- `--validate` selects Validation.

With no flag, select Delivery. Validation takes precedence over merge when
both flags are present. If no issue number can be parsed, stop and ask for it.

For a bare number, resolve the repository from `git remote get-url origin`.
For a full issue URL, parse platform, repository, and issue number from the
URL and ignore the current directory's repository. Apply `--repo` and
`--platform` overrides after parsing the other inputs.

## Step 0: Resolve the forge

Resolve the host from the issue URL, repository, or origin remote.

- GitHub uses `gh`.
- GitLab uses `glab`.
- An unknown host requires `--platform gitlab`; otherwise stop and report
  that the platform cannot be determined.

Before any issue or PR lookup, verify the selected CLI exists and is
authenticated with `gh auth status` or `glab auth status`. If it is missing or
unauthenticated, stop and tell the user to install or authenticate it. Never
install tools or authenticate on the user's behalf.

## Flow 1: Delivery

Run this flow when neither `--merge` nor `--validate` is present.

1. Fetch the issue with the selected forge CLI and capture its title and body.
   Fetch comments only when the body refers to prior discussion, links a
   comment, or is ambiguous without the discussion.
2. Check the current worktree for user changes and discover the remote's
   default branch. Do not discard or overwrite existing work.
3. Use Git worktrees through the shell. Create or resume the branch
   `issue-<number>-<slug>`, where the slug is the lowercased issue title with
   runs of non-alphanumeric characters replaced by one hyphen, edge hyphens
   removed, and length truncated to 40 characters. Use the freshly fetched
   remote default branch as the base.
4. If one existing worktree or branch matches `issue-<number>-*`, resume it.
   If multiple match, list them and ask which to use. If it already contains
   commits beyond the base, inspect and resume it instead of recreating it.
5. Never use a forceful worktree or branch operation. Stop if creating or
   resuming the worktree would overwrite uncommitted user work.
6. Inspect the issue and repository. Classify the change as exploratory,
   bounded, or architectural. For an architectural change, produce a
   concrete design and task plan, present it to the user, and wait for
   explicit approval before implementation.
7. Run relevant baseline tests before editing. If baseline tests fail, stop
   and report the failures.
8. Implement the approved change. Prefer sequential execution. Delegate
   only genuinely independent tasks to Codex subagents when available, state
   each task's files, and require summaries. Never let two agents edit the
   same files concurrently. If subagents are unavailable, continue
   sequentially.
9. Run tests appropriate to the changed behavior and review the complete
   diff against the base branch. Fix real findings and review again, up to
   five total review rounds. At the fifth unsuccessful round, stop and show
   unresolved findings; do not open a PR silently.
10. Commit locally at meaningful task boundaries. Push only after
    implementation is complete and tests pass, and push again only when a
    post-push correction changes committed code.
11. Open the PR/MR. Its body must contain `Closes #<issue-number>`.
12. Report the PR/MR URL and worktree path, then stop. Delivery must not
    merge, manually close the issue, delete branches, or remove the worktree.

## Flow 2: Approval (`--merge`)

Run this flow when `--merge` is present without `--validate`.

1. Find branches and worktrees matching `issue-<number>-*` using
   `git worktree list --porcelain` and `git branch --list`. Stop when there
   are zero or multiple matches; never guess.
2. Find the open PR/MR for the selected branch. Stop if none exists.
3. Stop and report the exact state if the PR/MR is draft, conflicted, or not
   mergeable. Do not resolve conflicts automatically.
4. On GitHub, inspect allowed merge methods and choose squash, then merge,
   then rebase. Do not force remote branch deletion. On GitLab, use the
   project's configured default strategy.
5. Verify that the issue is closed. If `Closes #<number>` did not close it,
   close it explicitly with a comment linking the PR/MR.
6. Remove the local worktree only if it is clean. If removal is refused due
   to uncommitted files, show the files and ask the user. Never use `--force`.
7. Preserve local and remote branches unless the user separately requests
   their deletion. Report the merged PR/MR, issue state, and removed worktree.

## Flow 3: Validation (`--validate`)

Run this flow before Approval when both flags are present.

1. Perform the same unique branch/worktree and PR/MR lookup as Approval.
2. Tell the user the exact branch, worktree, and PR/MR found.
3. Stop and ask the user to invoke `regression-validation` explicitly in a
   separate interaction. Do not invoke that skill from this skill, even if
   its metadata appears to permit it. Do not read its procedure and replay it
   manually; that would bypass its explicit-invocation guardrail.
4. When the user reports a verdict, relay it and stop for `--validate` alone.
   With both flags, continue at Approval step 3 only for the exact positive
   verdict `✅ Safe to merge`. For any failure, ambiguity, or inability to
   validate cleanly, stop without merging.

## Stop conditions and safety rules

Always stop and ask or report instead of guessing when the forge CLI is
missing or unauthenticated, the platform or issue is ambiguous, the base
branch is unexpected, a worktree cannot be identified uniquely, baseline
tests fail, the design gate is declined, five review rounds remain unresolved,
the PR/MR is missing/draft/conflicted/not mergeable, or an operation would
discard, overwrite, force-delete, or otherwise irreversibly change user work.

`--merge` is the only flow allowed to merge or close an issue. Delivery never
performs merge or cleanup as a side effect. This skill never invokes
`regression-validation` automatically. Remove worktrees only after checking
cleanliness, never force removal, and preserve branches by default. Report
commands and outcomes actually observed, not inferred success.
