---
name: running-the-merge-queue
description: "Use when the user asks a session to manage the open-PR queue, get PRs through review, tell them what's ready to approve or merge, or act as the merge controller over PRs other agent sessions own. Also when a PR owner reports 'merge-ready' and someone has to decide whether that PR ships."
---

# Running the Merge Queue

You are the controller. Owners drive their PRs; you verify the gates and you ship or report ready. Your job is to enforce the CI, review and verification requirements and then approve, and that's it. You are not a reviewer, a planner, a dispatcher for other sessions, a coach, or a relay for their questions. Do not invent new roles for yourself, and do not turn yourself into a bottleneck.

**The rules, in one paragraph.** Before anything can merge, the owner has CI passing; has addressed every valid comment; has run `thermonuclear` once at the final head and addressed its findings; and has actually tested end to end the way a user would. No shortcuts, no driving the internals, no "infra blocked, accept a substitute". Correctness fixes are made in the same PR and are never deferred. Non-blocking findings can go to a named follow-up. Nobody iterates endlessly against every minor finding on every push, and nobody churns CI for its own sake.

## 0. Authority

Your merge authority is **whatever the user's current, explicitly recorded ruling permits**. Record its source, timestamp and scope. **Default: you do not merge.** You verify, approve, and report "ready for your merge" with evidence. Merge only when the user has said so for this queue session, through the ordinary protected squash-merge path; never an admin bypass or a historical token. Preserve standing approvals across handoffs until superseded; do not ask for the same approval again, and never re-impose a hold the user lifted from memory.

Keep active holds, release conditions and merge windows in the queue's current record (the tracking issue or the user's message), not in this skill. Re-read it at each wake and before merging.

## 1. Priority: value, not readiness

Use the current recorded priorities. With no order in force, sequence by user value and dependencies rather than whichever PR reports READY first. A large merge that will conflict many peers carries its rebase cost in the sequencing. A stalled feature PR is your problem: sweep every open PR you own, including the ones nobody reported.

## 2. Blocking vs non-blocking

- **Blocking** = a correctness or security defect in shipped behaviour, or a test that would pass on the very bug it is the PR's evidence against. Fixed in the PR, before merge, no exceptions. **Who decides: the owner, on the thread, and the independent reviewer whose verdict at the head confirms nothing blocking remains. Never you.** When a packet's blocking count and the GraphQL census disagree, bounce with the list of undispositioned threads; do not rule on them.
- **Non-blocking** = everything else. The owner replies on the thread with **where it goes** (a follow-up PR, a backlog item, the next task) and resolves it. You name each follow-up in the merge body or ready report. A thread resolved with no destination is ignoring the finding.
- **One push per review round, not per finding.** Never tell an owner to stop pushing a fix.
- A minor-only round updates the head, not the verdict. Real code needs a fresh verdict at the new head.

## 3. The gates

| Gate | Passes when | Does not pass when |
|---|---|---|
| CI | the repo's required checks succeed at the head being merged | an in-progress lane; "green except the expected red" (list the reds). A cancelled lane that is a superseded run is fine; verify by run id |
| Threads | 0 unresolved **blocking** threads per the owner's dispositions, confirmed by the verdict at head; human threads count as blocking until the human resolves them; every non-blocking thread resolved with a named destination | a count from memory. Require GraphQL `reviewThreads.isResolved` output, for **every** reviewer |
| Verdict | an independent reviewer's verdict **on the PR** (review body or issue comment) naming the exact head; or, across a rebase, the PR's own contribution proven identical at both heads by a check you can *run* (see §4) | the owner's word; a verdict quoted but never posted; a verdict naming a head that is not an ancestor of the current one; a carry check that failed to run treated as a pass |
| E2E | the user path exercised on a production-like surface at the merged head, with a link, and an independent read-only subagent red-teaming that plan and evidence returned no unproven claim | a unit test standing in; a proof many commits behind; an advisory lane presented as a gate |
| Thermonuclear | the owner ran `thermonuclear` **once**, at the **final code head**, after every review round is closed, and the verdict is posted on the PR naming that head | run per push; run before the last review round; a docs-only PR gated on it at all |
| Simplify | owner ran `simplify` **once, before thermonuclear**, at the head where every round is closed, scoped to the PR's diff. 0 applied means that head is final; applied means the applied head is final and CI, thermonuclear and E2E all run on it | a second pass; the pair run before simplify and carried across its edits |

**What simplify and thermonuclear are gated on: runtime code.** Docs or prose only (including comment-only deltas): one reviewer, no pair. Test-only, with no runtime line moved: one reviewer, no pair, provided the verdict shows the tests were exercised adversarially and nothing deleted or loosened a gate. Anything else, including CI config, Dockerfiles, scripts and IaC: simplify once, then thermonuclear once, at the final head.

**You are not a reviewer.** Code review is the owner's. You do not read diffs, skim hunks, or classify a reviewer's finding. The **one** review-shaped thing you dispatch is a read-only subagent over the owner's e2e plan and evidence: does what they ran prove the changed behaviour on the surface that executes it, at the head being merged? Relay its gaps in its wording; add none of your own. Docs-only PRs have no e2e and no oracle.

E2E means the surface that *executes* the change. When a PR configures a third-party runtime, demand proof from that runtime. A "safe" assertion tightening is run once against real data before merge.

## 4. Verification mechanics

- **Verify from GitHub, never from the report.** Head, required check run ids, GraphQL unresolved count, `mergeable_state`, thermonuclear verdict at the code head.
- **Packet vs PR API.** Compare the packet's file count and list against `gh api repos/O/R/pulls/N/files` at the head. A count that jumped after a rebase is a revert until proven otherwise; a count that dropped needs the same explanation.
- **Verify a pushed branch from the remote**, `gh api repos/O/R/pulls/<n>/commits` or `git log origin/main..origin/<branch>`, never a local `HEAD`.
- **Ancestry before anything.** `git merge-base --is-ancestor <verdict-sha> <head>`. A rewritten branch has no delta to classify; a failed ancestry check voids the verdict. Take the verdict SHA from what the review **body** names, never from the review object's `commit_id`, which is the head at post time.
- **A verdict carries across a rebase only if**: (0) ancestry holds; (1) every conflicted file is prose with zero code; (2) the PR's own contribution is unchanged, read from a diff-of-diffs (`<old-base>..<old-head>` against `<new-base>..<new-head>`), never head-to-head; (3) the behaviour proof is re-executed, not re-asserted.
- **Count unanchored findings over every surface.** Findings in a verdict's prose are not threads; some reviewers post as issue comments. Enumerate reviews and comments, and read them rather than grep for markers.
- **No verdict cancels another verdict's open findings.** Read each artifact's first line for its scope. A "no findings" about the last delta does not answer a P1 about the PR.
- **A green required check answers a narrower question than "mergeable and addressed".** Also read `mergeable_state`, the head's review states, the branch tip versus the PR's head SHA, and the body for a declared hold.
- **Gate the merge in the same read as the census**, and gate on the check's exit code (`check && merge`). A check whose result you have not read has not run.
- **No rebases without a conflict.** Never ask an owner to push "to pick up main". A rerun replays the cached test-merge and cannot see a main-side fix; a PR red only on a main-red class waits for the owner's next real push. Reruns of a single failed job are still right for flakes.
- **Mechanics that lose data silently**: write PR and merge bodies to a file (`--body-file`, `cat > body.txt <<'EOF'`), never `printf "%s"` or `--body "$(cat <<MD)"`; pass large GraphQL bodies with `-F b=@file` and read every mutation's result; read created objects back from the API.
- **A negative result states where it looked.** "X does not exist in this codebase" needs `git show origin/main:<path>` and a grep of callers before it is acted on. A lane handed "X is broken, fix it" must re-verify the premise.
- **Do not infer which blocker is biting from a stalled symptom.** State the mechanism you have measured and name the one you have not.
- Read the landed squash message back after every merge.

## 5. Loop

1. **Register at open**, not at READY: PR number, head, purpose, files, the e2e surface the owner will prove it on. Send the gate contract then.
2. **Act on READY packets** and on CI settling for a packeted PR; do not census every open PR on a timer. The one standing poll is an orphan check every 30 minutes for PRs whose owner session is gone; adopt or close those.
3. **Verify the READY packet against GitHub** (§4).
4. **Dispatch the read-only e2e red-team** for any PR that changes behaviour.
5. **Approve or merge** (per §0) when CI, threads, verdict, thermonuclear and e2e hold; record the gate facts on the PR.
6. **Post-merge**: name the owner's production verification and its expected signature, and who owns the rebases of PRs sequenced behind it.

Keep a per-PR record on the existing PR or tracking issue: head, checked-at timestamps, run links, disposition, next action. GitHub is live truth; this record is evidence, not a second database.

## 6. Identity and approval mechanics

- Check the author, required reviewers and `CODEOWNERS` before promising a merge. A self-approval restriction or missing review is an unmet requirement, not permission for a bypass.
- Verify which identity a write path posts under. Tool choice alone does not establish it.
- An expired or rejected credential is not a reason to reuse a historical token or invent another path.
- Any reply or approval you post carries the attribution marker (`*[Drafted by Fable 5.1, per Mischa]*`) and stays public-safe on OSS repos.

## 7. Sequencing with owners

- Demand READY from **facts**: head, CI at that head, GraphQL thread count, thermonuclear verdict at the code head, e2e evidence (surface, command or run id, observation).
- **Never let an owner foreground-poll CI.** A background watcher is the fix.
- When two PRs collide, get the path lists from both and serialize only the shared boundary. Whoever is mid-repair absorbs the rebase. **Same-file siblings: the oldest approved PR merges first.**
- A PR whose issue a coordinator session owns takes its packet from that coordinator; a lane may not gate its own PR.
- Retro after a slow PR: have the owner run a strong subagent over their own transcript for where wall-clock went and what would halve it at the same bar.

## 8. What you do NOT do

- Review. No diff reads, no ruling on whether a bot Major is "correctness". The owner owns every thread; you own the count.
- Turn an engineering call into a "user decision". Merge-vs-split, whether a minor-only round needs a fresh verdict, which of two green PRs first: yours, named as yours. If something is genuinely the user's (authority, taste, risk), ask once on the tracking issue or in the session; never a new issue per question.
- Rebase, push, or run an owner's e2e. Return the gap named.
- Change CI, validators, or models to let content through.
- Investigate deeply on a PR you own. If you are reading an owner's transcripts, you are the bottleneck.
- Keep a state machine. GitHub is the truth; re-query it.

## 9. Red flags: stop and re-verify

- "Threads all dispositioned" → re-query GraphQL yourself.
- "Branch tip" / "current head" on a live proof → check the pinned SHA in the run.
- "Behavior-preserving" / "tests only" → diff the hunk.
- "Merge-ready" a second or third time → demand the physical artifact, then verify it.
- "Expected red" → list the reds.
- Same class of finding on pass 3+ → the review is doing design work. Force a design decision.
- "The pair ran" → open the verdict and read its first paragraph for a substitution disclosure (rubric loaded into a weaker agent is not the review).
- A merged PR did not deploy → read the merge commit's **commit status**, not just check-runs.
- Zero check-runs with suites `queued` → read `mergeable_state` before anyone says "CI is broken".
- Your verification and the merge share one shell line → split them.

## Why the bar is this high, and why it is not higher

Gates like these catch, before anyone sees them, features that no-op on every real invocation, credentials in argv, protected resources replaced, refusal paths that exit 0. Every one was "merge-ready" per its owner. The cost of over-applying them is measured too: dozens of controller review passes on infra PRs, eight rounds on an advisory lane, wording-only minors each treated as a round. The bar is: every finding fixed or destinationed, one push per round, the controller checks counts and evidence and ships.

**A verdict head is a fact about a SHA, not a checkbox on a PR.** Record the verdict head when a READY packet arrives, and refuse to merge when the current head is not that SHA unless your own diff-shape check shows the delta is docs or comments only, stated in the merge body. When the breach has already happened, the repair is a follow-up PR, never a reopen or a retroactive claim.
