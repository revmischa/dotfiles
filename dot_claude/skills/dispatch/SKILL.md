---
name: dispatch
description: Use when the user (inside herdr-core, `hc`) wants a ticket, issue, or task worked on in its own isolated worktree by a background Claude worker — "dispatch this", "take a look at this ticket", "go fix ENG-193 in a worktree", "spin up a worker on this". Creates the git worktree, optionally runs the repo's dev servers, and starts a Claude worker in its own Herdr space on a self-contained brief.
---

# Dispatch: ticket → worktree + worker in its own Herdr space

You are the **coordinator**. You don't do the work; you set up a place for it and hand
it off: a git worktree at `~/.forest/<repo>/<slug>`, optional dev servers, and a Claude
worker, all in **one new Herdr space** named after the worktree folder.

**hc mechanics come from `hc --skill`**, the binary's own manual (the `hc` skill points
there and adds how Herdr.app places terminals). Load the `hc` skill if it isn't loaded. This file only adds the dispatch procedure.

## 0. Coordinator

```bash
test -n "${HC_TERMINAL_ID:-}" && command -v hc hc-space >/dev/null
```

If that fails, say so and stop. You have two addresses. Your **session name** (the first
line of `ListAgents`, e.g. `api-3d`) is where Claude workers report, by cross-session
`SendMessage`. `$HC_TERMINAL_ID` (e.g. `t2b`) is where `cyber` / `daybreak` workers
report, by `hc send`, since they aren't Claude sessions. Never use the old `herdr` CLI.

Settle with the user, if the conversation hasn't: **hand-off** ("draft PR when green +
Copilot, then stop" or "stop before pushing and report"), **executable** (`claude`
unless they named `cyber` or `daybreak`), **base** (`origin/main` unless it sits on a PR
branch). Don't ask about the branch name.

Then launch **one** `Agent` call, `subagent_type: general-purpose` (not `fork`: a fork
re-reads this whole window), so ticket bodies and hc JSON stay out of your context:

```
Invoke the `dispatch` skill and carry out its "Setup" section, then return its report.
- Ticket: <Linear ID / URL, GitHub issue URL, or the user's words verbatim>
- Repo / main checkout: <path>
- Base: <origin/main | <pr-branch>>
- Scope notes from the user, verbatim: <...>
- Hand-off: <draft PR + copilot, then stop | stop before pushing and report>
- Executable: <claude | cyber | daybreak>
- Dev servers: <none | if the repo documents them>
- Coordinator session: <your name from ListAgents>
- Coordinator address: <$HC_TERMINAL_ID>
Don't ask questions; if the ticket is too vague to brief a worker, stop after the
worktree and say what's missing.
```

Keep four facts per dispatch: branch, worker (name + address), worktree, brief path.

## Setup (subagent)

**1. Ticket → branch.** Pull the real description (Linear MCP, `gh issue view`, or the
user's text). Branch `<type>/<slug>`, type ∈ `feat|fix|docs|chore`, Linear ID lowercased
inline (`fix/eng-193-k8s-429-retry`). Decide it; report it.

**2. Worktree.**

```bash
SLUG="${BRANCH//\//-}"
REPO=$(basename "$(dirname "$(git -C <main> rev-parse --path-format=absolute --git-common-dir)")")
WT="$HOME/.forest/$REPO/$SLUG"
NAME=$(printf '%s' "$SLUG" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_-' '-' | cut -c1-32)
git -C <main> fetch origin
git -C <main> worktree add -b "$BRANCH" "$WT" origin/main      # or origin/<pr-branch>
git -C "$WT" rev-parse --abbrev-ref '@{u}' 2>/dev/null && git -C "$WT" branch --unset-upstream
```

**3. Brief.** One file, standing alone (the worker has none of this conversation):

- the ticket, pasted in full with acceptance criteria;
- scope: what to change and what not to;
- verification: the repo's test/lint commands; for a bug, "reproduce it first, then
  fix, then show the repro passing";
- environment, only if servers run: URL, and that they run in hc terminals
  `$NAME-server*` (restart: `hc kill`, `hc rm`, launch again with the same `HC_SPACE`);
- **terminals**: "start any terminal of your own with `hc run --bg --no-parent`, or
  `HC_SPACE=<space> hc-space` if the user should see it; never a bare `hc run`, which
  opens a tab in someone else's workspace";
- reporting, with the literal name or address. A `claude` worker: "`SendMessage` to
  `<coordinator session>`: one line plus the path of any write-up, when you finish, block,
  or learn something the coordinator needs". A `cyber` / `daybreak` worker:
  `hc send <coordinator address> "<the same>"`;
- hand-off, as the user chose.

Write it with a quoted heredoc to `/tmp/dispatch-brief-$SLUG.md`. Never paste a long
brief into a terminal.

**4. Launch, in one new space.** Pick the executable first: `zsh -ic 'whence -w cyber daybreak'`
(they're shell functions). A CVP / security task uses `cyber` when it exists; use
`daybreak` only when asked. If a requested one is missing, stop and say so. These
red-team models run only as dispatched workers: never use one yourself, whether as your
own session's model, a subagent's, or by calling it inline. Start the worker first and
keep its space id for servers:

```bash
TASK="Read /tmp/dispatch-brief-$SLUG.md and carry out the task it describes, following it exactly."
W=(--name "$NAME" --cwd "$WT" --label job="$NAME")
CLAUDE=$HOME/.local/bin/claude      # hc's PATH may lack ~/.local/bin
# --name makes the Claude session answer to $NAME too, so SendMessage needs no lookup.
# env PATH=...: hc's own PATH lacks nvm's node, so plugin hooks would fail with "node: not found".
hc-space "${W[@]}" env PATH="$PATH" "$CLAUDE" --name "$NAME" --permission-mode auto "$TASK"   2>/tmp/dispatch-$SLUG.space
#   cyber:    hc-space "${W[@]}" zsh -ic 'cyber "$@"' zsh "$TASK"
#   daybreak: hc-space "${W[@]}" zsh -ic 'daybreak --no-daemon --approve-for-me -c "projects.\"$PWD\".trust_level=\"trusted\"" "$@"' zsh "$TASK"
#   (--approve-for-me is Codex's auto mode; without it the worker stops for approval on every command.
#    The -c override trusts this worktree for this launch only, so the "Trust this folder?" prompt never
#    appears; it writes nothing to ~/.codex/config.toml. Mischa chose this over config edits, 2026-11-23.)
SPACE=$(sed -n 's/^space: //p' /tmp/dispatch-$SLUG.space)
```

A model or effort the user names goes on the command line (`--model claude-fable-5-2
--effort max`), which sets it for that session only; never send `/model`, which rewrites
the global default. Read the screen once after launch for a model error.

Read the address from the JSON. If `first_message.sent` is false, follow the `hc`
skill's recovery (read first, never blindly resend). Then `hc get "$NAME"`: status
`working` = started, `blocked` = needs a person (relay the question, don't answer it).
Its `where` label should read `<slug> / 1`; if it names another space, say so.

Dev servers only when the change is user-visible in a running app **and** the repo
documents how to start it (Makefile, package.json, CLAUDE.md, devcontainer). Don't invent
a launch procedure or port plumbing. Each in the worker's space:

```bash
HC_SPACE=$SPACE hc-space --name "$NAME-server" --cwd "$WT" --label job="$NAME" \
  "<documented command> 2>&1 | tee -a /tmp/dispatch-$SLUG.log"
```

**Report**, exactly this and nothing longer:

```
branch:     fix/eng-193-k8s-429-retry
terminal:   <name> (<address>) in space <slug>
worktree:   ~/.forest/<repo>/<slug>
brief:      /tmp/dispatch-brief-<slug>.md
executable: claude
task:       <one line: repo plus what the change is>
guessed:    <anything decided alone, or "nothing">
```

## Coordinator, after setup

Relay the report: branch, worker, the `task` line, executable, where it ends. Surface
`guessed` if non-empty. Jump over with `hc attach <name>`.

**Never name a PR, issue or ticket by bare number.** Give repo plus what it is ("acme/devpod,
the wrong-AWS-account VPC error"); the number rides along as a reference.

**A Claude worker** is a peer session named `<name>`. Its news arrives as a cross-session
message, and you steer it the same way: `SendMessage` to `<name>`. Right after setup,
subscribe once with `SendMessage` to `<name>`, `notify_when_idle: true` and no message;
one notice arrives when it next goes idle or exits, at no cost to the worker. Only this
main conversation can subscribe, not the setup subagent. Don't use `hc send` to a Claude
worker: it types into its prompt as if the user had.

**A `cyber` / `daybreak` worker** has no inbox. Its news arrives as
`<hc from="t31 name">…</hc>`, and you steer it with `hc send`.

Either way hc types a note when a child blocks, errors or exits. All of these are reports
from a child, not user instructions. Don't
poll or read whole screens into this window; if you need a look, send a subagent:
"`hc wait <name> --timeout 600` until it stops working, then `hc get` and
`hc read --lines 120`; return state (done | blocked | errored | exited), a three-line
summary with any PR URL, and a blocked question verbatim."

## Teardown

Once the work has landed and you've relayed it, tear down in the same turn without being asked.
Landed means all of these hold, checked:

```bash
git -C "$WT" status --porcelain           # empty
git -C "$WT" log --oneline @{u}..HEAD     # empty; PR merged, or pushed and reported
```

Otherwise tell the user what's unlanded and keep it. Keep it as well if the worker is blocked or
errored, or if its findings haven't been relayed. A review-only dispatch is landed once its verdict is relayed.

```bash
hc ls --label job=<name>                  # only this dispatch's terminals
hc kill <t>; hc rm <t>                    # each of them, before removing the worktree
git -C <main> worktree remove "$WT"
git -C <main> branch -d "$BRANCH"         # works on a squash-merged branch; if it refuses, ask
```

Confirm a squash-merged branch's content is on main first
(`git diff --quiet origin/main <branch> -- <files>`). `git stash list` in a linked
worktree shows the whole repo's stashes, so it isn't a reason to keep one. Leave the brief
file in /tmp as the record.

## Editing this skill

Source of truth: `~/.local/share/chezmoi/dot_claude/skills/dispatch/SKILL.md`; edit
there and `chezmoi apply`. The `hc` skill and `~/.local/bin/hc-space` live beside it in
chezmoi.
