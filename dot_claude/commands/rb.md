---
name: rb
description: "Rebase current branch onto main, resolving conflicts if necessary"
---
name: rb

Fetch latest changes from the remote repository, then rebase the current branch onto the latest main branch. If there are any merge conflicts during the rebase, resolve them with the `resolve-conflicts` skill and continue until the rebase is complete, then push with `--force-with-lease`.

Goal is just to be working on top of the latest version of origin.

If this project is based on a fork, then rebase onto the latest version of the upstream main branch instead.
