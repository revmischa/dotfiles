---
name: opening-a-pr
description: "Use before opening a pull request, and before telling the user that any work is merge-ready, done, or blocked on their merge. Also use when an open PR has changed enough that its verification is stale, and when tempted to leave anything for later or after the merge. Owns every PR-opening flow; other shipping skills (push-pr, ready) supply mechanics inside step 8 and never replace this gate."
---

# Opening a PR

A green PR means nothing on its own. What matters is that the intent is implemented, the architecture the user asked for is respected, and the thing actually runs. This gate stands between "I believe it works" and spending a human's attention on it.

Shortcuts on the way here were fine; that is what the hardening ledger is for. **Nothing in the ledger survives to the PR.** "Later" means after end-to-end proof and before human review; it never means after merge.

Work the steps in order. Each produces evidence; step 8 assembles it. **Every step runs on every change.** The depth of evidence scales with the diff, not the number of steps. A two-line fix still gets a completeness check, a real run of the affected surface, a targeted doc grep, and a brief independent review. "This change is too small for the gate" is how the gate dies.

1. **Empty the hardening ledger.** Every shortcut logged during implementation is now either done or explicitly blocked with the blocker named (missing access, or a decision only the user can make). "I'll follow up" is not a legal state, and neither is a GitHub issue the user did not ask for. Then reconcile scope: diff the change against the authorized plan or issue (`git diff origin/main...HEAD`) and finish anything promised but absent. **If there is no ledger because the work started as an interactive request, write one now** from the session: what the user asked for, which decisions got settled along the way, every shortcut you took, and every part of the request you are unsure you covered. An absent ledger means nothing was written down, not that there was nothing to audit.
2. **Have a fresh agent check completeness.** Dispatch a subagent (Fable or latest Opus) with the diff, the ledger, and the authorization: the plan or issue if one exists, otherwise the user's original request and the decisions settled in this session, quoted. Its mandate: *"You did not do this work. List everything the authorization promised that this diff does not deliver, and every hack that is still in it."* Fix what it returns and re-dispatch until it comes back clean. You cannot audit your own scope because you already believe you finished.
3. **Run the `analyze` skill and fix what it finds.** Critical and high severity get fixed, not noted. Re-run after fixing. If the same finding survives three rounds, stop hammering it: checkpoint what you tried, what failed, and what you learned, then either switch to a materially different approach or bring the user the options with your recommendation. Do not hand them a bare "stuck."
4. **Have a fresh agent prove it works.** Dispatch a subagent: *"You did not write this code. Boot the actual artifact and use it through its real surface: TUI in a terminal, web in a real browser (Claude Chrome MCP), API via curl, or library via a driver script, against the user-facing workflows this change is supposed to serve. Tests passing is not evidence; you have to run the thing. Report what you ran, what you saw, and every defect."* Fix every defect it reports and re-dispatch until it is clean.

   **Every artifact has a consumer surface. Find it.** No conventional runtime is not an exemption: work out who or what actually consumes the thing, and exercise that. A skill or prompt gets loaded and walked by a fresh agent. A config change gets applied and the dependent service observed. A CI workflow gets triggered. A doc gets followed literally, start to finish, by someone who has not read the diff. If you genuinely cannot reach the surface because the environment or credential is unavailable, the honest report is **not merge-ready, verification blocked on X**, never "verified by inspection."

   **The surface means the user's own access path.** A minted session cookie is not the real login, `kubectl exec` is not the user's path, an admin API call is not the customer's API call. If the real path is awkward to drive, that awkwardness is missing test tooling and building it is in scope.

   **The surface is production-like, and the proof is attached to the PR before merge.** Production-like means a dev stack, staging, or a local stack with real migrations: a surface that has the resource the change touches. For infra (Pulumi), merging often IS the deploy trigger, so the proof is a `pulumi preview` plus a dev/staging apply where one exists, never a first apply in production. Merge-ready requires a **link in the PR** to that pre-merge proof (a run, a screenshot, an e2e); a green unit suite is not it. A code path that only executes after merge (a deploy workflow's inline step, a production-only resource) is untested until you have executed it against a non-production surface yourself.

   **Never deploy to staging without confirmation, and never to production without explicit recent authorization.** If proving the change needs a deploy, ask for that one deploy; do not substitute inspection for it.

   **The proof is a walk-through as the user, not a run.** For anything with a page or a workflow, the fresh agent walks the changed surface the way each affected user would, clicks every element on the pages the diff touched, reads the data a user would read, and reports every defect. Findings are fixed in this change. Walking the change includes its consumers: grep the e2e and spec suites for the locators, labels and DOM the change invalidates, and update them in the same PR.

   **Producer contracts need a consumer-visible delta.** When a change alters a producer's schema, publish path, log level, status code, metric name, or the conditions under which a field may be null, the PR body names every known downstream consumer (including monitors and dashboards) and what it will show differently. If no consumer is known, record the search that established it.

   **A contract tightening carries a `## Contract change census` section.** When a PR adds a refusal, makes a field required, removes or renames a field, or changes a signature at a process or package boundary, its body holds: the search commands and their scope (whole repo, every language, fixtures, sibling repos that produce or consume it); every hit and its disposition (updated here / covered by test X / unaffected because Y); and the rollout, as exactly one of `Rollout: warn-first; refuses in <follow-up>` or `Rollout: immediate refusal; security: <what the old input allowed>`.

5. **Sweep the docs.** Search the repo for anything the diff invalidated: renamed commands, changed flags, moved paths, config keys, or altered behavior across READMEs, `docs/`, skills, CLAUDE.md and AGENTS.md files. Update them here, in this change. Do not trust memory for which docs exist; grep.
6. **Get an independent review.** Give a fresh subagent the final diff and the QA report. Its findings get fixed, not acknowledged. For anything non-trivial, run `thermonuclear` once at the final head.
7. **Capture the learning, if there is one.** Did this work involve a gotcha that cost more than half an hour, or contradicted the documentation? If yes, write it into the repo's docs or the memory directory. If no, say so in one line and move on.
8. **Structure the review and draft the PR body before opening or updating it.** Multi-commit PRs are allowed when they improve the review narrative; group in dependency order (schema, core logic, wiring, UI, tests). Do not hide behavior changes as "cleanup"; split an unclear scope.

   Read the repository PR template first. Write in short paragraphs for a technically capable reader who missed the work, roughly 150 to 250 words. Open with the actor or task, its failure or limitation, and why it matters. State the changed behavior and only the mechanism needed for a credible causal claim. In `## Verification`, name who drove the end-to-end scenario, the observed result, and the evidence artifact or link. If acceptance is blocked, name the scenario that cannot run and why. Never invent a user report, baseline, measurement, screenshot, or successful run.

   **Public-safe.** hawk and the inspect forks are open source. No METR incidents, security details, run counts, GPU counts or other non-public information in the body, commits, or comments.

   **A figure or outcome in a PR body is pasted from the command that produced it, never transcribed.** Paste the command and its output verbatim, or cite the artifact path and paste the lines that carry the numbers. Every factual claim about what a suite, gate, or library does names the executing source you read (the script, the installed module, the lockfile), never a code comment, a docstring, or another PR's body.

   **If the change touches a user-visible surface, the body must SHOW it, not describe it.** Embed a screenshot, before/after pair, or recording. Name what the image is evidence of: a component in a harness proves the component, not the API wiring behind it.

   **A PR that claims to unify, dedupe, or consolidate must show a net reduction of source lines in the files it unifies, or explain precisely why not.**

9. **Preserve the final tree across history-only rewrites.** Before reordering, splitting, or squashing commits, record `before=$(git rev-parse HEAD^{tree})`. After the rewrite, compare with `git rev-parse HEAD^{tree}`. A different tree is allowed only for an intentional, separately explained content change; inspect it with `git diff <old-head> HEAD --stat`. Do not push if the tree changed unintentionally.
10. **Resolve the PR target.** New work branches off `origin/main` unless it builds on an open PR, in which case branch off that PR's branch; never let the branch track `origin/main`. For `inspect_ai`, `inspect_scout` or `ts-mono`, the PR targets the **upstream** repository and the branch is cut from the latest upstream main, never from our fork; follow the upstream repo's own contribution policy (inspect_ai's AGENTS.md wants an accepted issue for non-trivial PRs and an agent-review disclosure). Think through, in writing in the PR body, whether the change belongs upstream at all: a fork-specific workaround or an unproven fix is not upstream material; a defect any user would hit, fixed with a reproduction or red-to-green test, is.
11. **Open or update the PR, and default to NOT opening a new one.** One line of work gets one PR. Before creating, check `gh pr list --author @me` and the current branch's PR (`gh pr view 2>/dev/null`): fold same-line work into the existing PR. If none exists, `gh pr create --draft --body-file body.md`. **Always draft.** Write the body to a file; `--body "$(cat <<MD ...)"` can truncate and still exit 0. Read the body back from the API before treating the PR as described. Then `gh pr edit --add-reviewer copilot` (Copilot is added on every PR, draft included). End the body with the attribution line.

    **Never overwrite a PR description the user may have edited.** When updating, edit specific sections or append; ask before replacing the body.

    **Before every push, run the repository's fast local checks scoped to what the diff touches**: lint, type check, and the unit tests that import a changed module (`grep -rl '<module>' tests | xargs pytest -q`), not the files the diff edited. Never run the full suite locally; that is what CI is for. Red locally means the wave is not ready. Cite the green output lines in the push's report.

    **The unit is a reviewable slice of one line of work, sized before review.** A diff in the thousands of lines should have been split where its pieces could each be verified alone; ship those in dependency order. Splitting is not sibling PRs for the same line of work; it is the same line landing as verifiable pieces.

Merging does not end your responsibility: after it lands, **you** verify it in production (reads only, and only through the user's own access path) and record what you observed on the PR. See `landing-a-pr` §6.

Then hand off to `landing-a-pr` immediately. Copilot posts within minutes of open; do not run one manual `gh pr view` and leave.

## The excuses, and why none of them work

| The excuse | The reality |
|---|---|
| "The mechanism says this should work." | You watched a mechanism, not a result. The gap is a single command away. |
| "Tests pass, CI is green." | Green CI means the code did not crash the way you anticipated. It says nothing about whether the feature does what was asked. |
| "It gets live-verified after the merge / on the next deploy." | Then it is unverified now, and you are asking a human to merge on faith. |
| "I disclosed the gap honestly in the PR body, so opening it is fine." | Honesty about an unverified change does not verify it. A `## Verification` that says "blocked on X" means NOT merge-ready. State the exact failed command, then build or repair the surface and run the scenario. |
| "Want me to run the smoke test first?" | Do not ask. Running it is the job, and it was authorized the moment the work was. |
| "The rest should follow in a separate PR." | Separate PR = deferral. If you can describe it precisely enough to defer it, you can do it now. |
| "Want that as a follow-up issue?" | Filing is not fixing. Do not open an issue the user did not ask for. |
| "This change is too small to boot." | Booting a small change is fast. That is an argument for doing it. |
| "I verified it earlier, before the last few fixes." | Those fixes are the diff now. Stale verification is a false claim. |
| "This is docs / config / a skill only: nothing to run." | Find its consumer and exercise that. Every artifact has a surface. |
| "The environment for testing isn't available here." | Say so as a blocker and report not merge-ready. Missing tooling is a finding, not a pass. |
| "The unit tests exercise the same code path." | They exercise it with your assumptions wired in. The surface is where the assumptions get tested. |
| "The user wanted this fast." | They want it working. |
| "Verified by inspection" / "by reading the code". | Inspection establishes syntax or intent, not the user-observable result. |
| "I described what it renders as, which is clearer than an image." | Clearer to you, who has seen it. A table of cell contents is a claim about a render, not the render. |
| "I drove it in a browser and read the DOM back, so it is verified." | That is verification. It is not evidence a reviewer can see. Capture the frame. |

Catch yourself writing any excuse above, then go run step 4.
