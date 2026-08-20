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

Base on `origin/main` unless the work sits on top of an existing PR branch (then base on
that branch, and say so).

```bash
herdr worktree create --branch "$BRANCH" --base origin/main --no-focus --json
```

Read the **workspace id**, **root pane id**, and **path** out of the JSON. Never guess
IDs — re-read them after every split.

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
herdr pane run <srv-top> "cd $WT && <the repo's documented command> 2>&1 | tee -a /tmp/dispatch-$BRANCH.log"
```

Split again `--direction down` from `<srv-top>` for a second server. The `tee` is the
point: it gives you a file to grep later without needing the pane.

## 4. Start the worker

```bash
herdr pane rename <root-pane> "claude"
herdr pane run <root-pane> "claude --permission-mode ${CLAUDE_PERMISSION_MODE:-auto}"
herdr wait agent-status <root-pane> --status idle --timeout 60000
herdr pane run <root-pane> "<brief>"
```

The brief is one message and must stand alone — the worker has none of this
conversation. Include:

- **The ticket**: title, full description, acceptance criteria. Paste it, don't summarize.
- **Scope**: what to change, and explicitly what not to.
- **Verification**: the repo's test/lint command, and how to tell the fix worked. If it's
  a bug, say "reproduce it first, then fix, then show the repro passing" — that's the
  standing rule, restate it because the worker won't infer it.
- **Environment**, only if step 3 ran: the URL, credentials, "servers run in sibling
  herdr panes labelled 'server'; restart one by re-running its command there", and the
  `/tmp/dispatch-<branch>.log` path.
- **Hand-off**: "open a **draft** PR when the work is green, add copilot as a reviewer,
  then stop" — or "stop before pushing and report back", if the user prefers to look first.
  Ask which if you don't know.

## 5. Report

Tell the user: branch, workspace id, what the worker was told to do, and where it ends
(draft PR vs. stop-and-report). Offer to jump over:

```bash
herdr workspace focus <workspace-id>
```

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

```bash
herdr workspace close <workspace-id>    # stops panes, servers, and the agent
git -C <main-checkout> worktree remove ~/.forest/<repo>/<branch>
git -C <main-checkout> branch -d <branch>    # -D only if the user confirms it's abandoned
```

Close the workspace **first** — panes holding the checkout open will defeat
`worktree remove` and the directory reappears. Confirm before deleting anything with
uncommitted changes (`git -C <wt> status --porcelain`), and never do this to a main checkout.
