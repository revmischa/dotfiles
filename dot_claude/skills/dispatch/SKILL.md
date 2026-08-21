---
name: dispatch
description: Use when the user (inside herdr) wants a ticket, issue, or task worked on in its own isolated worktree by a background Claude worker — "dispatch this", "take a look at this ticket", "go fix SEN-193 in a worktree", "spin up a worker on this". Creates the herdr workspace, optionally runs the repo's dev servers in sibling panes, and starts a Claude worker on a self-contained brief.
---

# Dispatch: ticket → herdr worktree with a Claude worker

You are the **coordinator**. You do not do the work — you set up somewhere for it to
happen and hand it off:

1. a git worktree opened as its own herdr workspace,
2. (only if the repo needs it) dev servers in sibling panes,
3. a Claude worker in the root pane, started on a self-contained brief.

Keep the user's focus where it is (`--no-focus` throughout) until the last step.

## 0. Preconditions

```bash
test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_SOCKET_PATH:-}"
```

If that fails, say you're not running inside herdr and stop. Worktrees land at
`~/.forest/<repo>/<name>` — shared between herdr (`[worktrees] directory` in
`~/.config/herdr/config.toml`) and Claude Code (`~/.claude/hooks/forest-worktree.sh`).
Let herdr choose the path; don't pass `--path`.

## 1. Resolve the ticket, then the branch name

Source order: a Linear ID/URL (use the Linear MCP tools to pull title + description),
a GitHub issue (`gh issue view <n> --json title,body`), or the user's plain description.
**Pull the real description** — the worker's whole context comes from it.

Branch name follows the repo convention `<type>/<slug>`, type ∈ `feat|fix|docs|chore`,
Linear ID lowercased inline when there is one:

```
fix/sen-193-k8s-429-retry     feat/sandbox-runtime-class
```

Confirm the branch name with the user before creating anything. If the ticket is vague,
ask — a worker with a vague brief burns a whole session.

## 2. Create the worktree

Base on latest `origin/main` unless the work sits on top of an existing PR branch (then base on
that branch, and say so).

```bash
herdr worktree create --branch "$BRANCH" --base origin/main --no-focus --json
```

Read the **workspace id**, **root pane id**, and **path** out of the JSON. Never guess
IDs — re-read them after every split.

Branch names contain slashes, so keep a filename-safe slug for the temp files below:

```bash
SLUG="${BRANCH//\//-}"
```

Then enforce the standing rule that new branches don't track `origin/main`:

```bash
git -C "$WT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null \
  && git -C "$WT" branch --unset-upstream
```

## 3. Dev servers — only if the repo actually has them

Most tasks (library work, infra, docs, a test fix) need no servers. Skip this step
unless the change is user-visible in a running app *and* the repo already documents how
to start it — a `Makefile` target, a `package.json` script, a `CLAUDE.md` section, a
devcontainer. **Do not invent a launch procedure**, and do not build per-worktree port
or hostname plumbing; if two worktrees would fight over a port, say so and let the user
decide.

When it does apply, one pane per server, to the right of the worker, labelled:

```bash
herdr pane split <root-pane> --direction right --no-focus   # -> <srv-top>
herdr pane rename <srv-top> "server"
herdr pane run <srv-top> "cd $WT && <the repo's documented command> 2>&1 | tee -a /tmp/dispatch-$SLUG.log"
```

Split again `--direction down` from `<srv-top>` for a second server. The `tee` is the
point: it gives you a file to grep later without needing the pane.

`pane run` submits correctly here because these panes are at a shell prompt. Prompts
typed into an agent's TUI are the exception — see step 4.

## 4. Start the worker

### Pick the executable FIRST — it decides the command you run

Default to the Fable model; Opus 5 fast mode is acceptable for trivial tasks. Check what
is actually available before launching, don't assume:

```bash
command -v cc-fable            # Fable launcher
zsh -ic 'whence -w cyber'      # `cyber` is a shell FUNCTION, so `command -v` won't find it
```

- **cybersecurity / CVP task and `cyber` is available → you MUST use `cyber`.** CVP work
  is cybersecurity work; treat any mention of CVP as the trigger.
- Otherwise, **`cc-fable` present → you MUST use it** (that's how you get Fable).
- Only if neither is present, fall back to plain `claude`.

Getting this wrong is silent — the worker runs fine on the wrong model and nothing warns
you. Decide before you type the launch line.

```bash
herdr pane rename <root-pane> "claude"
herdr pane run <root-pane> "<cyber|cc-fable|claude> --permission-mode ${CLAUDE_PERMISSION_MODE:-auto}"
herdr wait agent-status <root-pane> --status idle --timeout 60000
```

**Put the brief in a file and point the worker at it.** Do not paste a long brief into
the pane — see the gotchas below.

```bash
cat > "/tmp/dispatch-brief-$SLUG.md" <<'BRIEF'
<the whole brief, markdown, heredoc-quoted so nothing expands>
BRIEF

herdr pane run <root-pane> "Read /tmp/dispatch-brief-$SLUG.md and carry out the task it describes, following it exactly."
herdr pane read <root-pane> --source visible --lines 6          # the line is in the input buffer, unsubmitted
herdr pane send-keys <root-pane> enter                          # this is what actually submits it
herdr wait agent-status <root-pane> --status working --timeout 20000
```

If the `wait` times out, the prompt never went in. Re-read the pane: text still sitting
at the `❯` means send another `enter`; an empty buffer means the text was dropped, so
send it again from `pane run`.

### herdr gotchas

- **`herdr pane run` does not submit into an agent's TUI.** Its help says "command text
  plus Enter", and that holds at a shell prompt — which is why launching the agent with
  it works. Text typed into Claude's own input box just sits there. Always follow with
  `herdr pane send-keys <pane> enter`.
- **Verify before you submit, and verify after.** Fire-and-forget loses briefs silently:
  a `pane run` immediately after the agent first reaches `idle` can be dropped entirely,
  leaving an empty buffer and no error. `pane read` on both sides costs nothing.
- **Long multi-line text arrives as several separate `[Pasted text #N]` chunks**, which
  is unverifiable at a glance and concatenates with whatever a failed earlier attempt
  left behind. The brief-in-a-file trick sidesteps all of it: one short line, one
  readable buffer. It also survives a worker that gets compacted or restarted — the
  brief is still on disk.
- **Clear a dirty buffer** with `herdr pane send-keys <pane> ctrl+u` before retrying.
- `herdr agent send <target> <text>` is the documented "type literal text, no Enter"
  primitive, and `herdr agent ...` accepts agent names rather than pane ids. Either
  works; both still need the explicit `enter`.

The brief is one message and must stand alone — the worker has none of this
conversation. Include:

- **The ticket**: title, full description, acceptance criteria. Paste it, don't summarize.
- **Scope**: what to change, and explicitly what not to.
- **Verification**: the repo's test/lint command, and how to tell the fix worked. If it's
  a bug, say "reproduce it first, then fix, then show the repro passing" — that's the
  standing rule, restate it because the worker won't infer it.
- **Environment**, only if step 3 ran: the URL, credentials, "servers run in sibling
  herdr panes labelled 'server'; restart one by re-running its command there", and the
  `/tmp/dispatch-<slug>.log` path.
- **Hand-off**: "open a **draft** PR when the work is green, add copilot as a reviewer,
  then stop" — or "stop before pushing and report back", if the user prefers to look first.
  Ask which if you don't know.

## 5. Report

Tell the user: branch, workspace id, what the worker was told to do, which executable it
is running on (`cyber` / `cc-fable` / `claude`), and where it ends (draft PR vs.
stop-and-report).

**Never identify a PR, issue, or ticket by bare number.** Mischa runs many of these in
parallel across repos and does not hold the number → content mapping in his head. Give
repo plus what the change actually is on first mention — "METR/devpod, the wrong-AWS-
account VPC error" — and let the number ride along as a reference, not as the name. A
short name is fine on later mentions in the same message. This matters most in
multi-worker status summaries, where several numbers appear at once.

Offer to jump over:

```bash
herdr workspace focus <workspace-id>
```

You are not finished at the report. When the worker lands, relay its result and then
**tear the workspace down in the same turn** — see Teardown.

## Checking on it

Don't busy-wait:

```bash
herdr wait agent-status <pane> --status done --timeout 600000
herdr pane read <pane> --source recent-unwrapped --lines 120
```

`done` and `idle` both mean finished. `blocked` means it needs input — read the pane and
relay the actual question to the user; don't answer on their behalf unless it's trivial.

Lost the pane ids? `herdr pane list --workspace <ws>` and match on the labels.

## Teardown

**Tear down automatically once the work is done and safely landed.** Don't leave dead
workspaces for the user to notice and ask about — relay the worker's result, then clean
up in the same turn and say you did.

"Done and safely landed" means all of these, checked and not assumed:

```bash
git -C "$WT" status --porcelain          # empty — nothing uncommitted
git -C "$WT" log --oneline @{u}..HEAD    # empty — nothing unpushed
                                         # and the PR is merged, or the branch is pushed
                                         # and the user has seen the report
```

If any check fails, **stop and tell the user what's unlanded** instead of deleting it.
Same if the worker ended `blocked`, errored, or you never relayed its findings — the
pane is the only copy of that context. Also leave it up if the user has typed something
into the pane that hasn't been submitted yet.

For a review-only dispatch there is nothing to land: once you've relayed the verdict,
tear down.

```bash
herdr workspace close <workspace-id>    # stops panes, servers, and the agent
git -C <main-checkout> worktree remove ~/.forest/<repo>/<slug>
git -C <main-checkout> branch -d <branch>
```

Close the workspace **first** — panes holding the checkout open will defeat
`worktree remove` and the directory reappears. Never do this to a main checkout.

Notes from doing it for real:

- `branch -d` **succeeds on a squash-merged branch** as long as the local branch matches
  its own upstream — it warns "merged to refs/remotes/origin/<branch>, but not yet merged
  to HEAD" and deletes. You rarely need `-D`; if `-d` genuinely refuses, that means work
  exists nowhere else, so stop and ask rather than reaching for `-D`.
- Before deleting a squash-merged branch, confirm the content actually landed:
  `git diff --quiet origin/main <branch> -- <the files it touched>`.
- `git stash list` inside a linked worktree shows the **whole repo's** stashes, not that
  worktree's. A stash there is not a reason to keep the worktree, and removing the
  worktree won't touch it.
- Leave the `/tmp/dispatch-brief-<slug>.md` file; /tmp cleans itself and it's the record
  of what the worker was told.

## Editing this skill

This file is **managed by chezmoi**. The source of truth is
`~/.local/share/chezmoi/dot_claude/skills/dispatch/SKILL.md`, not the applied copy at
`~/.claude/skills/dispatch/SKILL.md`. Edit the source and run `chezmoi apply`; edits made
directly to the target get clobbered, and worse, the target can be *stale* relative to
the source, so reading it can hide instructions that actually exist. Check with
`chezmoi status ~/.claude/skills/dispatch/SKILL.md` before assuming the applied copy is
current.
