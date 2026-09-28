---
name: post-merge
description: "Use after a PR is merged: when the user says 'merged', 'PR is merged', 'any cleanup or follow-up?', or a merge notification arrives for work from this session."
---

# Post-Merge Sweep

A PR just merged. Run the closing sweep. Execute each item; don't present a list of
suggestions.

1. **Confirm the merge.** Verify the PR is merged and post-merge CI on the target branch
   is green. If still running, start a background watcher and continue.
2. **Clean up local state.** `git fetch --prune`, confirm the remote branch is gone,
   remove the worktree you created for this work by path (`git worktree remove <path>`,
   then `git branch -d <branch>`). Never run a bare `git worktree prune` in a checkout
   other agents share; it can delete admin entries for worktrees this shell cannot see.
   The `disk-hygiene` skill owns broader cleanup.
3. **Tracking state.** Close or update the linked Linear or GitHub issues, tracking docs,
   and roadmap items, with a comment naming the merge SHA and where it is and is not yet
   deployed (main, staging, production). Plan or spec content belongs in the issue body,
   not as file-path references.
4. **Deploy and verify live.** If the repo has a deployment step (check AGENTS.md or
   CLAUDE.md), follow it under the standing rules: staging needs confirmation, production
   needs explicit recent authorization. Live means observed on the NEW version: evidence
   that postdates the deploy (a deployed image digest, a pod or task created after the
   apply, a squash SHA read back from the service), never a workflow badge. A squash merge
   lands a different SHA than the PR head, so never key a check to the PR head SHA. Deploy
   queues coalesce: a "cancelled" pending run was replaced by a newer chain and is not a
   failure; find the newest run, that one carries your merge. The only deploy event worth
   reporting is a failed chain that carries your merge, and that one is yours to fix. A
   merged skill, plugin or dotfiles change is live only once the checkout sessions load it
   from has advanced (`chezmoi apply`, or a pull in the plugin checkout); read the served
   file back.
5. **Announce, if the change moved someone's workflow.** Name who the merge affects
   (people authoring against a changed convention, users of a changed page, anyone
   invoking a changed CLI or following a changed doc) and draft the message for the user
   to send, with the attribution marker. Read the merged PR's own text for consumers
   outside the repository before recording "no one"; a repo grep cannot see them.
6. **Report.** The short list of items you handled (or "nothing left"), then clearly state
   any remaining follow-ups in full sentences with context, never bare issue numbers.

The bar is "pristine clean."
