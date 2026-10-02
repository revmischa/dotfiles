---
description: "Panel review of a PR: dispatch cyber + daybreak reviewers, grade the existing bot/human reviews, verify, and synthesize one review"
argument-hint: "<PR URL> [--post]"
---

Run a **panel review** of the PR in `$ARGUMENTS`: two independent model reviewers
(`cyber` = Claude Code on the cyber-permissive model, `daybreak` = Codex on the
cyber-permissive model), graded against whatever reviews already exist on the PR
(Copilot, Greptile, CodeRabbit, humans), then one synthesized, verified review.

You are the **coordinator**. Follow the `dispatch` skill's layout: main keeps only
branch / workspace / pane / brief per worker; setup, waiting, and pane reading all go
through `general-purpose` subagents so worker output never floods this window.

Nothing is posted unless `--post` is in the arguments. Without it, end with a draft.

## 1. Snapshot the PR

One subagent fetches, and writes to `/tmp/panel-<repo>-<n>/`:

- PR title, body, author, head/base refs, **head SHA**, draft state, CI rollup.
- Every review, inline comment, conversation comment, and review thread
  (`gh api .../pulls/<n>/reviews`, `.../pulls/<n>/comments`, `.../issues/<n>/comments`,
  GraphQL `reviewThreads` with isResolved/isOutdated/path/line), grouped by reviewer.
  Note which **commit** each bot reviewed; bots often review an older head.

Main keeps only: head SHA, reviewer list with comment counts, snapshot path.

## 2. Dispatch two reviewers in parallel

Two `dispatch` setup subagents in the **same message**, one per executable:
`daybreak` and `cyber`. Base = the PR head; name the branches
`panel-daybreak-<n>` and `panel-cyber-<n>`. Review-only, no dev servers.

Both briefs are identical apart from the executable. Each worker must:

1. **Grade every existing review comment** from the snapshot: true positive /
   false positive / partially right / noise. Give claimed vs real severity, and
   whether it's fixed at the current head. Verify against the code, not the bot's
   reasoning. Bots commonly stop tracing one call early, so check upstream guards.
2. **Do its own review** of `git diff origin/<base>...origin/<head>`. Cover
   correctness, security (auth, input handling, secrets, privilege, isolation),
   migrations/infra safety, and tests. Each finding needs file:line, severity, and
   *confirmed* (repro or precise trace) vs *worth checking*.
3. Print a scorecard per existing reviewer (TP/FP/partial/noise, useful precision).
4. **Write everything to a file** (`/tmp/panel-<repo>-<n>/<executable>.md`) *and* print it.
   Drafts that live only in a worker's context are lost.

Read-only: no edits, commits, pushes, posts, reactions, or thread resolution. No
pulumi, no full test suite; targeted tests and scratch containers are fine.

If `cyber` fails with a model-not-found error, report it and ask. Don't silently
swap models, because the point of the panel is two different model families.

## 3. Wait, recover, collect

Watcher subagents per worker. Treat these as **errored, not done**: "Quota exceeded",
"Conversation interrupted" / "Reconnected", "Baked for 0s", or a model error.
For an interrupted Codex session, re-prompt the same pane to continue (its context
survives). For quota, report and ask.

Collect each worker's file. Don't reconstruct findings from pane scrollback.

## 4. Verify before synthesizing

Re-check the PR head. If it moved since the snapshot, or any high-severity finding
comes from only **one** source, dispatch a `claude` verifier worker. It checks each
such finding at the current head: *still real* (repro/trace), *fixed* (cite commit),
or *not an issue*. Findings the two reviewers disagree on always go to the verifier.

## 5. Synthesize

Apply the `review-judgment` skill across **all** sources: both panel reviewers, the
verifier, and the existing bot/human reviews. Buckets: **Act on / Consider / Noted /
Dismissed**. Deduplicate across reviewers and record who found each item. Something
found independently by two sources is stronger evidence. Something found by one
source and confirmed by the verifier is still Act on.

Produce:

- **Findings table:** item, severity, file:line at current head, found by, verified?
- **Existing-review scorecard:** per bot/human, with a one-paragraph read on
  whether that reviewer is pulling its weight on this PR.
- **Draft PR review:** only Act on / Consider items, most severe first, each with
  file:line and the repro or trace. Include one line for already-addressed items.
  Don't restate existing open threads; reply on them instead if there's something new.
  Attribute it (e.g. `*[Drafted by <model>, per <user>]*`). Keep it public-safe if
  the repo is public.

## 6. Post (only with `--post`) and tear down

With `--post`: confirm the head SHA is unchanged, then post one review via
`gh api -X POST repos/<o>/<r>/pulls/<n>/reviews` with `event=COMMENT`
(never approve or request changes on your own authority). Post replies to existing
threads only where the finding adds something. Print the URLs.

Without `--post`: print the draft and stop.

Tear down each review workspace once its output file is saved and relayed:
close the herdr workspace, remove the worktree, delete the review branch.
Keep a branch whose commits exist nowhere else and say why.

Final message: verdict in one line, the findings table, the scorecard, the draft
(or posted URLs), and anything left unverified.
