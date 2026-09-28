---
name: resolve-conflicts
description: "Use when merge conflicts exist after a rebase, merge, or cherry-pick; when file moves or renames cause path-level conflicts; or when verifying a rebased branch even though no conflict markers remain."
---

# Resolve Conflicts

## Phase 1: Map both sides (do this first)

```bash
git status --short | grep '^\(UU\|AA\|DU\|UD\|AU\|UA\)'   # conflicted files and their kind
git diff --name-status ORIG_HEAD...HEAD                      # during a rebase: what the base moved
git diff --stat <base>...<ours>; git diff --stat <base>...<theirs>
git diff <base>...<ours> -- <file>; git diff <base>...<theirs> -- <file>
```

During a rebase, "ours" is the branch being rebased onto (upstream) and "theirs" is your
commit; `git rebase` swaps the usual meaning. Check `git status` for which commit is being
replayed before trusting either label.

**You must be able to answer:**
1. What did side A change? (paths AND content)
2. What did side B change? (paths AND content)
3. Do they overlap? Where?
4. Which side's version is better for each overlapping area, and why?

If you can't answer all four, keep reading. Do not proceed.

## Phase 2: Classify

| Conflict type | What it looks like | Resolution |
|---|---|---|
| **Path-only** | File moved or renamed on one side, modified on the other | Pick the correct path, keep the content changes |
| **Content-only** | Both sides modified the same lines | Read both, combine or pick the better version |
| **Path + content** | Moved AND modified differently on each side | Resolve the path first, then the content |
| **Delete vs modify** | One side deleted, the other modified | Decide whether the file should exist; if yes, keep the modifications |

`--stat` with `0 insertions, 0 deletions` on a rename means pure move; anything else is
move plus content.

## Phase 3: Resolve each file

Read the markers (`<<<<<<<`, `=======`, `>>>>>>>`; `diff3` style adds a `|||||||` base
section, enable it with `git config merge.conflictStyle zdiff3` when the two-way view is
ambiguous). Pick the right content, remove every marker, `git add` the file.

For each file, document the choice: "taking theirs because it has the grading cache
improvement", not just "taking theirs".

## Phase 4: Verify the composed tree, not only the marked conflicts

- Paths the new base deleted must stay deleted unless the branch deliberately restores
  them: `git diff --name-status <old-base> <new-base> | grep '^D'`, then check each is
  absent from the result.
- Files changed on both sides: check for lost non-conflicting hunks, including docs that
  accompany a code change. Taking one whole side can discard the other side's valid work.
- Renamed or changed interfaces: check their dynamic consumers too (string-keyed
  registries, import loaders, monkeypatch targets). Marker-free text can still be invalid.
- Confirm the branch's own contribution survived: `git diff <new-base>...HEAD --stat`
  should look like `git diff <old-base>...<old-head> --stat`, modulo files main absorbed.

Run the affected packages' syntax, type, lint and test checks with the commands CI uses,
scoped to the packages the diff touches plus every test that imports a changed module.
Compare a failure against the intended base with the same commands before attributing
it. Fix integration defects before pushing. "Pre-existing" is not a resolution; fix it
or state the remediation and get an explicit decision to exclude it.

Push with `--force-with-lease`, never `--force`.

## Red flags: stop and rethink

| About to do | Why it's wrong |
|---|---|
| Skip the conflicting commit (`git rebase --skip`) | You're avoiding the conflict; that commit's changes are lost |
| Add a "fix-up" commit to reverse changes | A new problem instead of solving the original |
| `git rebase --abort` then retry a different approach | Trial-and-error loops; make one deliberate fix |
| Say changes are "superseded" without checking | Read the actual content on both sides |
| Take one whole side without comparing the discarded changes | Valid code or docs disappear with the side you dropped |
| Chain a second fix after the first didn't fully work | You missed something. Re-read Phase 1 |

## When conflicts are complex

If a conflict is more than path plus content (architectural disagreement, mutually
exclusive approaches), explain both sides and ask the user before resolving.

**Done when:** all conflicts resolved, checks pass, branch pushed with `--force-with-lease`.
