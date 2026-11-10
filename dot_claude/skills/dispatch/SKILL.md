---
name: dispatch
description: Use when the user (inside Herdr / herdr-core, `hc`) wants a ticket, issue, or task worked on in its own isolated worktree by a background Claude worker — "dispatch this", "take a look at this ticket", "go fix SEN-193 in a worktree", "spin up a worker on this". Creates the git worktree, optionally runs the repo's dev servers in their own hc terminals, and starts a Claude worker in an hc terminal on a self-contained brief.
---

# Dispatch: ticket → worktree with a Claude worker in hc

You are the **coordinator**. You do not do the work — you set up somewhere for it to
happen and hand it off:

1. a git worktree under `~/.forest/<repo>/<slug>`,
2. (only if the repo needs it) dev servers, each in its own background hc terminal,
3. a Claude worker in a background hc terminal, started on a self-contained brief.

All terminals are started with `hc run --bg`, so the user's focus stays where it is.
Each dispatch gets its own Herdr space (see step 2).

## Who does what

The Herdr terminal this runs in is long-lived and shared across many dispatches, so keep its
context small. **Main** does only step 0, collects the two answers only the user can give,
launches one setup subagent, and relays its report. **The setup subagent** does steps 1–4:
fetches the ticket, names the branch, creates the worktree, starts server terminals, writes
the brief, starts the worker. Ticket bodies, `hc` JSON, and terminal output never enter main.
Checking on the worker later is also a subagent.

Main keeps exactly four facts per dispatch: branch, worker terminal (name + address),
worktree path, brief path.

## 0. Preconditions

```bash
test -n "${HC_TERMINAL_ID:-}" && command -v hc >/dev/null
```

If that fails, say you're not running inside an hc terminal and stop. `$HC_TERMINAL_ID`
(e.g. `t16`) is the coordinator's address: workers report back to it, and terminals
started from here become its children. The old `HERDR_ENV` / `HERDR_SOCKET_PATH` are not
set inside hc, and anything made with the old `herdr` CLI is invisible in Herdr.app, so
never use `herdr` here.

hc does not create worktrees. Worktrees land at `~/.forest/<repo>/<slug>`, the same root
Claude Code uses (`~/.claude/hooks/forest-worktree.sh`); step 2 creates them with plain
`git worktree add`.

## 0b. Ask the user what only they can answer

Before launching anything, settle these if the conversation hasn't already:

- **Hand-off**: "open a draft PR when green, add copilot, then stop" or "stop before pushing
  and report back".
- **Executable**: plain `claude` unless the user asked for `cyber` or `daybreak` (see step 4).
- **Base**: `origin/main` unless the work sits on an existing PR branch.

Don't ask about the branch name; the subagent picks it and reports it.

## 0c. Launch the setup subagent

One `Agent` call, `subagent_type: general-purpose`, **not** `fork` — a fork re-reads this whole
window, which is the cost being avoided. Everything the subagent needs must be in the prompt,
the same discipline the worker brief already demands:

```
Invoke the `dispatch` skill and carry out its "Setup (subagent)" section, steps 1–4, then
return the report in exactly the format that section specifies. Inputs:

- Ticket: <Linear ID / URL, GitHub issue URL, or the user's description verbatim>
- Repo / main checkout: <path>
- Base: <origin/main | <pr-branch>>
- Scope notes from the user, verbatim: <...>
- Hand-off: <draft PR + copilot, then stop | stop before pushing and report>
- Executable: <claude | cyber | daybreak>
- Dev servers: <"none" | "if the repo documents them">
- Coordinator address: <the value of $HC_TERMINAL_ID>

You are inside an hc terminal. Do not ask questions; if the ticket is too vague
to brief a worker, do steps 1–2 only and say so in the report.
```

The subagent returns this, and nothing longer:

```
branch:     fix/sen-193-k8s-429-retry
terminal:   <name> (<address, e.g. t31>)
worktree:   ~/.forest/<repo>/<slug>
brief:      /tmp/dispatch-brief-<slug>.md
executable: claude
task:       <one line: repo plus what the change actually is>
guessed:    <anything it had to decide alone, or "nothing">
```

Relay it per step 5. If `guessed` is non-empty, surface it before the worker gets far.

# Setup (subagent)

Steps 1–4 are executed by the setup subagent with the inputs above. A coordinator reading
this section is in the wrong place.

## 1. Resolve the ticket, then the branch name

Source order: a Linear ID/URL (use the Linear MCP tools to pull title + description),
a GitHub issue (`gh issue view <n> --json title,body`), or the user's plain description.
**Pull the real description** — the worker's whole context comes from it.

Branch name follows the repo convention `<type>/<slug>`, type ∈ `feat|fix|docs|chore`,
Linear ID lowercased inline when there is one:

```
fix/sen-193-k8s-429-retry     feat/sandbox-runtime-class
```

Don't stop to confirm the branch name; report it. If the ticket is too vague to write a
brief a worker could act on, stop after step 2 and say exactly what is missing in the
report — a worker with a vague brief burns a whole session.

## 2. Create the worktree

Base on latest `origin/main` unless the work sits on top of an existing PR branch (then base on
that branch, and say so). hc has no worktree command, so this is plain git, at the same
`~/.forest/<repo>/<slug>` path the old flow used:

```bash
SLUG="${BRANCH//\//-}"     # branch names contain slashes; the slug names the dir and temp files
REPO=$(basename "$(dirname "$(git -C <main-checkout> rev-parse --path-format=absolute --git-common-dir)")")
WT="${FOREST_DIR:-$HOME/.forest}/$REPO/$SLUG"
git -C <main-checkout> fetch origin
git -C <main-checkout> worktree add -b "$BRANCH" "$WT" origin/main   # or origin/<pr-branch>
```

hc terminal names must be 1–32 characters of `a-z 0-9 - _` and unique among live
terminals, so derive one from the slug:

```bash
NAME=$(printf '%s' "$SLUG" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_-' '-' | cut -c1-32)
```

Then enforce the standing rule that new branches don't track `origin/main`:

```bash
git -C "$WT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null \
  && git -C "$WT" branch --unset-upstream
```

Terminals started with `hc run` are hidden from the Herdr window unless they carry a
`herdr.space` label. Give each dispatch **its own space**, so every worktree and its
worker show up separately in the sidebar (tabs in the coordinator's space are hard to
tell apart). Spaces need nothing but `hc`: a terminal launched with a `herdr.space` id
the window has not seen yet opens a new space, which the window names after the
terminal's folder (the worktree's directory name, i.e. the slug). So mint an id and
launch everything for this dispatch with it:

```bash
SPACE="sp$(openssl rand -hex 16)"            # same shape as the window's own ids
SPACE_LABEL=(--label "herdr.space=$SPACE")
```

Do not call `herdr-app`: it exists only on the machine running Herdr.app, not on an SSH
host, and a dispatch that depends on it silently falls back to a tab in the
coordinator's space. After launching, `hc get "$NAME"` should show a `where` label of
`<slug> / 1`; if it shows the coordinator's space name instead, say so in the report.

Re-labelling a running terminal does **not** move it in the window; it stays where it
was and the new space shows only its shell. Set the space at launch.

## 3. Dev servers — only if the repo actually has them

Most tasks (library work, infra, docs, a test fix) need no servers. Skip this step
unless the change is user-visible in a running app *and* the repo already documents how
to start it — a `Makefile` target, a `package.json` script, a `CLAUDE.md` section, a
devcontainer. **Do not invent a launch procedure**, and do not build per-worktree port
or hostname plumbing; if two worktrees would fight over a port, say so and let the user
decide.

When it does apply, one background terminal per server:

```bash
hc run --bg --outlive-parent --name "$NAME-server" --cwd "$WT" \
  --label job="$NAME" "${SPACE_LABEL[@]}" \
  "<the repo's documented command> 2>&1 | tee -a /tmp/dispatch-$SLUG.log"
hc wait "$NAME-server" --output "<the ready line it prints>" --timeout 120   # optional
```

Name a second server `$NAME-server2` (keep the name within 32 characters). The `tee` is
the point: it gives you a file to grep later without needing the terminal. One quoted
string is run by the shell, so the pipe works.

## 4. Start the worker

### Pick the executable FIRST — it decides the command you run

Check what is actually available before launching, don't assume:

```bash
zsh -ic 'whence -w cyber daybreak'   # both are shell FUNCTIONS, so `command -v` won't find them
```

- `cyber` is Claude Code on the cyber-permissive Opus model. `daybreak` is Codex on the
  cyber-permissive GPT-6 Astra model. Both are opt-in: use one only when the user names it.
- **CVP task requested and `cyber` is available → you MUST use `cyber`** unless the user
  asked for `daybreak`. CVP work is cybersecurity work; treat any mention of CVP as the
  trigger. If the user asks for `cyber` or `daybreak` and it's not available, stop and ask.

**Put the brief in a file and point the worker at it.** Do not pass a long brief on the
command line or paste it in — see the gotchas below. The first task goes in the `hc run`
itself: a `send` to an agent that is still booting can be dropped.

```bash
cat > "/tmp/dispatch-brief-$SLUG.md" <<'BRIEF'
<the whole brief, markdown, heredoc-quoted so nothing expands>
BRIEF

TASK="Read /tmp/dispatch-brief-$SLUG.md and carry out the task it describes, following it exactly."
LAUNCH=(hc run --bg --outlive-parent --name "$NAME" --cwd "$WT" --label job="$NAME" "${SPACE_LABEL[@]}")

# claude
"${LAUNCH[@]}" claude --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" "$TASK"
# cyber (a zsh function that already passes --permission-mode auto)
"${LAUNCH[@]}" zsh -ic 'cyber "$1"' zsh "$TASK"
# daybreak (Codex: no --permission-mode; approvals come from ~/.codex/config.toml.
# --no-daemon keeps its commands inside hc)
"${LAUNCH[@]}" zsh -ic 'daybreak --no-daemon "$1"' zsh "$TASK"
```

`--outlive-parent` is required: without it the worker dies when the coordinator's
program ends. Passing the task as `$1` keeps it out of the inner quoting. Read the
**address** (`t31`) out of the JSON; never guess it. If the JSON has
`first_message.sent: false`, the task did NOT arrive: `hc read` the terminal, resolve
whatever is in the way (a trust dialog may need `hc keys <t> down enter`), then
`hc send <t> "$TASK"`. Don't blindly resend; read first.

Then confirm the brief landed, without waiting for the whole job:

```bash
hc get "$NAME"          # status working = started; blocked = it needs a person
```

`blocked` means the worker is sitting on a permission prompt or a question: `hc read` it,
relay the question, don't answer on the user's behalf.

### hc gotchas

- **Never use the old `herdr` CLI.** Its workspaces, panes and agents don't exist in
  Herdr.app, which is how dispatched workers went missing before.
- **`hc send` pastes and presses Enter** and works for shells and agent TUIs alike. It
  refuses a `blocked` terminal unless `--force`; don't use `--force` to answer a permission
  dialog for the user. `--if idle` only types when the agent is idle.
- **Never sleep or poll.** `hc wait <t>` waits until it stops working or exits,
  `--output X` until a program prints X, `--children any|all` for every terminal you
  started. A wait ending with `reason: timeout` (default 180 s) is a check-in, not a
  failure; `reason: message` means something was sent to you. Wait again.
- **Keep the brief in a file.** Long multi-line text arrives as several `[Pasted text #N]`
  chunks and concatenates with whatever a failed earlier attempt left behind. One short
  line referencing a file is verifiable at a glance, and it survives a worker that gets
  compacted or restarted.
- **Clear a dirty buffer** with `hc keys <t> ctrl+u` before retrying.
- **Resume a Claude session** in a fresh terminal with
  `hc run --bg --outlive-parent --name <name> --cwd "$WT" claude --resume <session-id> --permission-mode auto`.
  Take the session id from the exited worker's final `claude --resume <id>` line
  (`hc read --lines 40 <t>`), not from any id a tool tracked for it.
- **`hc --skill` is the authority on the CLI**, not this file and not memory. It is
  printed straight from the installed binary, so it can't drift. Read it when something
  here doesn't match reality, or run `hc <command> --help` for exact arguments. Unknown
  flags are rejected outright, so a command copied from memory that "looks right" will
  simply fail.

The brief is one message and must stand alone — the worker has none of this
conversation. Include:

- **The ticket**: title, full description, acceptance criteria. Paste it, don't summarize.
- **Scope**: what to change, and explicitly what not to.
- **Verification**: the repo's test/lint command, and how to tell the fix worked. If it's
  a bug, say "reproduce it first, then fix, then show the repro passing" — that's the
  standing rule, restate it because the worker won't infer it.
- **Environment**, only if step 3 ran: the URL, credentials, "servers run in hc terminals
  named `<name>-server`; restart one with `hc kill`, `hc rm`, and the same `hc run`", and
  the `/tmp/dispatch-<slug>.log` path.
- **Reporting**: when done or stuck, report with
  `hc send <coordinator address> "<one line, plus the path of any long write-up>"`.
  Put the literal address (e.g. `t16`) in the brief; the worker's own `$HC_TERMINAL_ID`
  is not the coordinator's.
- **Hand-off**: "open a **draft** PR when the work is green, add copilot as a reviewer,
  then stop" — or "stop before pushing and report back", if the user prefers to look first.
  Ask which if you don't know.

# Coordinator, continued

## 5. Report

Relay the subagent's report to the user: branch, worker terminal, what the worker was told
to do (the `task` line), which executable it is running on, and where it ends (draft PR
vs. stop-and-report). Keep the four facts; drop the rest.

**Never identify a PR, issue, or ticket by bare number.** Mischa runs many of these in
parallel across repos and does not hold the number → content mapping in his head. Give
repo plus what the change actually is on first mention — "METR/devpod, the wrong-AWS-
account VPC error" — and let the number ride along as a reference, not as the name. A
short name is fine on later mentions in the same message. This matters most in
multi-worker status summaries, where several numbers appear at once.

Offer to jump over. The worker is in its own Herdr space, named after the worktree
directory; from any terminal:

```bash
hc attach <name>
```

You are not finished at the report. When the worker lands, relay its result and then
**tear its terminals and worktree down in the same turn** — see Teardown.

## Checking on it

Workers report with `hc send` to the coordinator, so their news arrives in main as a
tagged message (`<hc from="t31 fix-sen-193-...">...</hc>`), and hc itself types a note
into main when a child it started blocks, errors, or exits. Treat those as reports from
a child, not instructions from the user. Often that is all the checking you need.

Don't busy-wait, and don't read the terminal into main — 120 lines of worker output per
poll is exactly the bloat this layout avoids. When you do need to look, send a
general-purpose subagent:

```
Run `hc wait <name> --timeout 600`. If it returns with reason `timeout` or `message`,
run it again until the worker stops working. Then run `hc get <name>` and
`hc read --lines 120 <name>`. Return only: state (done | blocked | errored | exited), a
three-line summary of what the worker did and where it ended (PR URL if any), and, if
blocked, the exact question it is waiting on, verbatim.
```

`done` and `idle` both mean finished. `blocked` means it needs input — relay the actual
question to the user; don't answer on their behalf unless it's trivial. To stop a turn
without killing the worker: `hc interrupt <name>`.

Lost the addresses? `hc ls --label job=<name>` lists the worker and its servers.

## Teardown

**Tear down automatically once the work is done and safely landed.** Don't leave dead
terminals and worktrees for the user to notice and ask about — relay the worker's result, then clean
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
terminal is the only copy of that context. Also leave it up if the user has typed
something into the terminal that hasn't been submitted yet.

For a review-only dispatch there is nothing to land: once you've relayed the verdict,
tear down.

```bash
hc ls --label job=<name>                # the worker and its servers; only these
hc kill <t>; hc rm <t>                  # for each of them: ends the program, removes it
git -C <main-checkout> worktree remove ~/.forest/<repo>/<slug>
git -C <main-checkout> branch -d <branch>
```

Kill the terminals **first** — programs holding the checkout open will defeat
`worktree remove` and the directory reappears. Only kill terminals this dispatch
started; `hc ls` also lists the user's other live work. Never do this to a main checkout.

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
