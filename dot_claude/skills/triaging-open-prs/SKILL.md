---
name: triaging-open-prs
description: Use when the user wants to go through their open PRs to see which are ready to merge, fix merge conflicts, rebase stale branches, address review feedback, or otherwise drive a backlog of PRs toward merge. Triggers like "go through my open PRs", "which of my PRs are ready", "get my PRs merged", "clean up my open PRs".
---

# Triaging Open PRs Toward Merge

## Overview

Drive a backlog of the user's open PRs to merge, one by one. The core loop: **identify the right repo → pull true status → triage into buckets → process each → checkpoint before any outward action.**

The user's global `CLAUDE.md` already sets standing conventions (draft PRs by default, **never merge without explicit OK**, squash merges, mark addressed review threads RESOLVED, read ALL comments before acting). This skill is the *procedure*; those conventions still bind.

## Step 0: Identify the canonical repo FIRST

Do not assume the worktree's `origin` is where the PRs live, and do not assume one repo.

- `git remote -v` — there may be multiple remotes, some deprecated.
- `gh pr list --repo <owner/repo> --author "@me" --state open` — try the obvious repo, but **confirm with the user which repo is canonical** if `origin` and the PR host differ, or if a repo looks deprecated. Acting on PRs in a dead repo wastes the whole session.

## Step 1: Pull true status for every PR

One GraphQL call gets status + CI rollup for the whole backlog (much faster than per-PR `gh pr view` + `gh pr checks` loops):

```bash
gh api graphql -f query='query{repository(owner:"OWNER",name:"REPO"){pullRequests(states:OPEN,first:50,orderBy:{field:CREATED_AT,direction:DESC}){nodes{number title isDraft mergeable mergeStateStatus reviewDecision baseRefName author{login} commits(last:1){nodes{commit{statusCheckRollup{state}}}}}}}}' \
  --jq '.data.repository.pullRequests.nodes[]|select(.author.login=="MYLOGIN")|[.number,.isDraft,.mergeable,.mergeStateStatus,.reviewDecision,(.commits.nodes[0].commit.statusCheckRollup.state//"NONE"),.baseRefName]|@tsv'
```

`statusCheckRollup.state` = SUCCESS/FAILURE/PENDING; only drill into `gh pr checks <n>` for PRs whose rollup isn't SUCCESS.

`mergeable`/`mergeStateStatus` are computed **lazily** — a query can return `UNKNOWN`. Re-query those PRs until resolved. Also re-pull at the start of every session: states drift, PRs merge/close, **new PRs appear**. GitHub API 5xx flakes happen; retry before concluding anything (for `gh pr diff` 503s, `git fetch origin refs/pull/N/head:refs/remotes/origin/pr-N` and diff locally).

## Step 2: Triage into buckets

| State | Bucket | Action |
|-------|--------|--------|
| APPROVED + CLEAN + MERGEABLE | ready | verify not-redundant + CI green → merge |
| APPROVED + CONFLICTING | rebase-then-merge | rebase, force-push, merge |
| MERGEABLE + CHANGES_REQUESTED | address-review | fix items, resolve threads, re-request |
| MERGEABLE + REVIEW_REQUIRED | needs-reviewer | request a reviewer (confirm who) |
| CONFLICTING/DIRTY | rebase | rebase onto main, regenerate locks |
| DRAFT | decide | confirm whether to mark ready |

Stacked PRs (base = another feature branch, not main) must be processed bottom-up.

**APPROVED review yet `reviewDecision: REVIEW_REQUIRED`?** Branch protection "require approval of the most recent reviewable push": an approval doesn't count if the approver pushed the latest commits (common when the user approves their own follow-up push to someone else's PR). Fix is a different reviewer's approval — not a rebase, which only dismisses what's there.

## Step 3: Process each — key judgment calls

**Before merging a "ready" PR:** confirm it's not already superseded. Check whether the fix landed on main or in a sibling PR (`git show origin/main:<file>`, search merged PRs). A green+approved PR can still be redundant.

**Read every comment before merging — including the approval's own body.** An APPROVED review often carries conditions ("LGTM once X is fixed", "approving to unblock, but please address Y"). Pull review bodies, issue comments, AND inline threads (`gh pr view <n> --json reviews,comments` + the reviewThreads GraphQL query); treat any unaddressed condition as a blocker even though `reviewDecision` says APPROVED.

**Rebasing (use a dedicated worktree, never the shared checkout):**
```bash
git worktree add -f /tmp/_prNNN <branch>
git -C /tmp/_prNNN rebase origin/main
```
- Lockfile conflicts (`uv.lock`, etc.): take main's side (`git checkout --ours`) then **regenerate** (`scripts/dev/uv-lock-all.sh` or `uv lock`). Don't hand-merge locks.
- Re-run tests + pre-commit before pushing.
- Force-push with `--force-with-lease`. Warn the user it **may dismiss approvals** (often survives — verify after).
- Clean up the worktree after merge.

**Addressing review feedback:** if the PR has outstanding (unresolved) comments, run the `/feedback` skill on it — that is the standard workflow for working through PR comments. Each addressed item becomes a real commit, then reply + resolve the thread (GraphQL `resolveReviewThread`). For change-requests where all threads are already resolved, the only blocker is a stale review — re-request the reviewer.

**Same check failing on several PRs → suspect main, not the PRs.** Check the workflow's runs on main (`gh run list --branch main --json conclusion,headSha,createdAt`, filter by workflow). If main is red (classic: a dep bump landed without relocking a sibling package's `uv.lock`), fix main with one small PR instead of debugging each victim.

**Stale CI:** re-run failed jobs with `gh run rerun <run-id> --failed` before assuming a real failure. **But a rerun reuses the run's original merge commit** — it does NOT re-merge with current base, so a failure caused by broken main still fails after main is fixed. To test against current main use `gh pr update-branch <n>` (triggers a fresh run on a new merge ref).

**Real CI failures — reproduce before fixing.** Run the exact failing command/hook locally. If you **cannot reproduce** (e.g. platform-specific, Linux-only inference), say so and ask — do **not** guess at a fix. State the root cause and the proposed fix, and let CI be the final verification if local repro is impossible.

## Step 4: Checkpoint before outward actions

Merging, force-pushing, requesting reviewers, and closing PRs are outward-facing. Confirm each with the user (a batched `AskUserQuestion` per PR or per phase works well). Merge = `gh pr merge <n> --squash --delete-branch`, only on explicit OK. Track progress with TaskCreate (one task per PR) for a long backlog.

## Common mistakes

- **Assuming `origin` is the PR repo.** Verify; repos get renamed/deprecated.
- **Trusting a single status query.** `UNKNOWN` ≠ clean; re-query.
- **Merging a redundant PR** because it's green+approved. Check for supersession first.
- **Hand-merging lockfile conflicts.** Regenerate instead.
- **Guessing at a CI fix you can't reproduce.** Reproduce or ask.
- **Working in the shared worktree** during rebases. Use a throwaway worktree.
- **Force-pushing without re-checking** whether approval survived.
- **Rerunning a failed job to pick up a fixed base.** Reruns keep the old merge ref; use `gh pr update-branch`.
- **Debugging each PR when the same check is red everywhere.** Check main first.
