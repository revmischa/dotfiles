---
name: hc
description: "Herdr / herdr-core (`hc`): run programs and coding agents in persistent terminals. Use whenever you start, message, wait on, read, or clean up an hc terminal (background workers, helper agents, dev servers, slow builds), when the user mentions Herdr, a Herdr space, workspace, tab or session, or when $HC_TERMINAL_ID is set and work should run in the background. Never use the old `herdr` CLI."
---

# hc

**Run `hc --skill` now and follow it.** That is herdr-core's own manual, printed by the
installed binary, so it always matches the CLI. This file is only a pointer to it plus the
one thing it can't know: how Herdr.app places terminals on this setup.

## Where a terminal shows up in Herdr.app

hc has no notion of windows, spaces or tabs. `herdr-app`, which arranges them, exists only
on the machine running Herdr.app, not on an SSH host. Herdr.app places each hc terminal by its labels instead:

| How it was started | Where it appears |
| --- | --- |
| `--label herdr.space=<id the window hasn't seen>` | **its own space** (a sidebar entry), named after its `--cwd` folder |
| no space label, started from a terminal (the default) | **a tab in the parent's space**, i.e. in the user's current workspace |
| no space label, `--no-parent` | hidden from the window (still in `hc ls`) |

Unlabelled `hc run` calls are why tabs pile up in the user's space. So:

- **A worker, reviewer, long-lived agent or anything the user should be able to find:**
  start it with `hc-space` (in `~/.local/bin`), which is
  `hc run --bg --outlive-parent --label herdr.space=<fresh id>` plus your arguments.
  It prints `space: sp…` on stderr; `HC_SPACE=sp…` puts a second terminal (its dev
  server) in the same space.

  ```sh
  hc-space --name fix-x --cwd ~/.forest/repo/fix-x ~/.local/bin/claude --permission-mode auto "Read /tmp/brief.md and do it."
  HC_SPACE=sp0123… hc-space --name fix-x-server --cwd ~/.forest/repo/fix-x "bun dev"
  ```

- **A short helper you wait on yourself** (a build, a test run, `gh run watch`): add
  `--no-parent` so it stays out of the window. You lose parent notes; `hc wait <t>`
  replaces them.
- Only add a tab to the user's space when they ask for one.
- Set the space at launch: `hc label` on a running terminal does not move it.
- `hc get <t>` shows a `where` label (`<space name> / <tab>`) once the window has placed
  it. Check it after launching anything the user should see.
