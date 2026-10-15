---
name: push-pr
description: "Push changes and create a GitHub pull request"
---
name: push-pr

Push my changes.

# If there is not an open PR:

Create a draft pull request. Follow this workflow:

## 1. Review Current State

Check the current state:

- Run `git status` to see uncommitted changes
- Run `git log -1` to view the latest commit
- Run `git diff` to examine modifications (if uncommitted changes exist)

## 2. Branch Handling

**If not on a feature branch:**

- Pick a branch name from the commit/changes (branch off `origin/main`, not tracking it)
- Create and switch to the branch: `git checkout -b <branch-name>`
- Push to origin: `git push -u origin <branch-name>`

**If already on a feature branch:**

- Push changes: `git push`

## 3. Create Pull Request

If there isn't already an open PR:

Use `gh pr create --draft` with:

- Appropriate title
- Description including:
  - Summary of what changed and why
  - Testing information
  - Any notes for reviewers

Then add `copilot` as a reviewer and `open` the PR for me in the browser.

## 4. Error Handling

Halt and report any issues encountered during execution.

# If there is already an open PR:

Push my changes to the existing PR branch. Check the title and description are
still accurate; edit specific sections only, never overwrite what I wrote.

# After pushing

Follow the `landing-a-pr` skill (background watch, one push per review round).
Do not block the foreground on CI.
