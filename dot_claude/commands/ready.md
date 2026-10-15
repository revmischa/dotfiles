---
name: ready
description: "Get the current PR merge-ready, then mark it ready for review"
---
name: ready

Get the current PR merge-ready and mark it ready for review.

1. Run the `opening-a-pr` gate against the current head.
2. Then follow the `landing-a-pr` skill until it reports merge-ready: conflicts,
   then review threads (`/cmt`), then CI (`/ci`). Rebase only when needed.
3. Invoking this command is my authorization to mark the draft ready for review
   (`gh pr ready`) once that bar is met. It is **not** authorization to merge or to
   arm auto-merge; I do those.

If `copilot` is not a reviewer, add it. Copilot reviews take a few minutes after a
push; wait for them per `landing-a-pr` (background watch, never foreground polling).
