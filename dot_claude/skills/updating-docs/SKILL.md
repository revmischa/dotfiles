---
name: updating-docs
description: "Use when creating or updating documentation, READMEs, AGENTS.md or CLAUDE.md files, skills, runbooks, or any prose that describes how a system works. Trigger whenever a change touches documented behavior, even if the user only asked for the code change."
---

# Updating Docs

## Evergreen, not archaeological

Write what is true now. Remove on sight:

- PR or issue-number breadcrumbs ("as of #1234...")
- Migration trails ("previously we did X, now we do Y")
- Deprecation lists ("don't use the old JSON format") once the old way is gone; describe
  the correct way instead
- "NEW:" / "UPDATED:" markers and dated notes

If a reader needs to know the old way existed, that's what `git log` is for.

## A cutover sweeps the whole owning tree

When a change makes prose false, enumerate every file in the owning tree by tree walk
(`rg --files <dir>`, `git ls-files <dir>`), never by a hand-written glob: a glob for
`*/references/*.md` cannot see `references/phases/`. Cover every file type, not `.md`
alone: a script or config inside a skill tree is the doc of record for what actually runs.

- **Sweep from the claim, not from a fragment.** Grep the intersection of the claim's
  terms rather than a remembered phrase, and read every hit in full. A brief scoped to a
  file list finds the next copy and stops; a brief with a completeness criterion ("this
  overturned claim, in all its rewordings, appears nowhere") closes in one pass.
- **When the claim matters, have a second agent sweep independently** and merge the hits.
  Independent searchers false-negative in different ways.
- **A copy that shares no words with the claim is invisible to grep.** Enumerate what
  depended on the overturned state: a status, a flag, a downstream step, an acceptance row,
  a test docstring. Then read the whole file back.
- **Correct the heading, title or first sentence in place.** An appended correction is read
  by the person who already doubts; the heading is read by everyone who skims.
- **Write what you observed; label separately what you infer.** A correction inherits the
  authority of what it corrects, so its overreach spreads faster than the original error.
  Before characterising a format or a tool's output, print one instance verbatim.

## A rule broken by people who can quote it wants a mechanism

When agents who know a standing instruction keep violating it and the honest answer to
"why" is "they forgot", stop rewording it. Build a refusal or an automatic step at the
moment of action (a git hook, a shim, a CI check, a tool default), then count how many
attempts it refused against how many got past.

## Integrate, don't accrete

Before adding a section, check whether an existing one covers the topic. If it mostly
does, rewrite that section; don't append a near-duplicate. Symptoms of accretion:

- The doc gets longer on every edit, even when the change simplified things
- Two sections disagree slightly about the same behavior
- Per-case sections (per-provider, per-version) that share most of their content

Same test as code: an update whose purpose is consolidation leaves the doc shorter.

## Structure

- One doc per audience or purpose; a new file needs a reason an existing one can't serve.
- Match the tone and formatting of the doc you're editing.
- Prefer rewriting a section over patching sentences into it.
- Review a doc change as **rendered**, not only as source. A `|` inside a table cell splits
  the row even inside backticks; write `\|`. Check with
  `sed 's/\\|//g' FILE | awk -F'|' '{print NR": "NF}'` against the header's cell count.
