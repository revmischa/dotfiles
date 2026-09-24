---
name: disk-hygiene
description: Use when a dev box is low on disk or RAM, `df` is far above what known work explains, load spikes with D-state processes, or git worktrees / docker images / temp dirs have piled up from many agent sessions. Triggers - disk full, ENOSPC, "clean up the worktrees", stale worktrees, docker prune, buildx cache, /tmp full, io pressure.
---

# Disk Hygiene on a Box with Many Agent Sessions

Reclaim disk from a machine where many agent sessions each left worktrees, containers, caches and scratch behind. The hard part is not deleting; it is knowing what is live. Sessions that are alive but idle look identical to dead ones on disk.

**Safety principle:** nothing is deleted whose directory any live process is standing in, and nothing is deleted that holds content existing only on disk: untracked, gitignored, and modified-tracked files all count, not just unpushed commits. Liveness is *measured*, never inferred from age or from a directory's name.

## Quick reference

| Phase | Purpose | Gate |
|---|---|---|
| 1 | Baseline: `df -h`, IO pressure, start a ledger file | |
| 2 | Check in with every live session | Replies drained; protected set written |
| 3 | Inventory + classify worktrees and scratch | Every non-live row has a class |
| 4 | Apply: paced, one at a time, re-checking liveness | Ledger shows 0 errors |
| 5 | Docker: dangling, leaked buildkit leases, stale tags, orphaned sandboxes | Each container's owner known before removal |
| 6 | Caches and temp families | Only known families, only idle >24h |
| 7 | Report: freed, kept-and-why, unowned WIP found | Summary next to ledger |

Biggest levers observed, in order: dangling docker images, a buildkit cache whose leases leaked, unused tagged images, orphaned sandboxes, `/tmp` families, then worktrees. Worktrees are smaller than they look: `uv` venvs hardlink into `~/.cache/uv`.

## Cleaning up after yourself

A request to clean up after yourself is not a sweep. The question is which paths are yours, and a directory's name answers it in neither direction. Do not assume a worktree you do not recognize is unused, and do not assume one named for an issue you worked is yours.

Ownership is measured, like liveness: find the creating command in your own or your subagents' transcripts (a `git worktree add`, a clone, a `mktemp`, a write under it). A path no transcript of yours names is not yours, whatever it is called: say so to whoever asked, and leave it. The sweep's two gates still hold for your own paths: no live process standing in one, and no content that exists only on disk.

## Pacing (applies to every phase)

- One `rm` or `du` at a time. On Linux, `sudo ionice -c3 nice -n19`; on macOS, `nice -n19`. Two parallel `du` walkers plus one `rm` can hang every shell on a busy box.
- On Linux, gate each deletion on `/proc/pressure/io` `full avg10 < 20`.
- Never `lsof +D` or `fuser` a tree per candidate; that is a full walk each time. Take **one** snapshot of every process's cwd and re-take it before each item:
  - Linux: `for p in /proc/[0-9]*; do readlink $p/cwd; done 2>/dev/null | sort -u`
  - macOS: `lsof -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2- | sort -u`
- Sizing is optional. `df` before and after measures what was freed; do not block on `du`.

## Phase 2: Check-in

Ask every live agent session (ListAgents / herdr panes / the user, for sessions you cannot reach) one message: I am inventorying every worktree and checkout on this box and deleting what no live session needs. I will not touch any directory a live session reports as in use. Please do not delete anything yourself. Confirm your cwd and any other checkout you or your subagents use; list dirs you created that are DONE and safe to delete; name other dead weight you own (docker images, caches, eval logs). "cwd only: <path>" is a complete answer.

Write the protected set (exact paths, not broad prefixes; a prefix as broad as `~/dev` blocks the owner's own explicit releases under it) to a file before Phase 4 starts. Silence is not consent; an unanswered session's cwd stays protected.

## Phase 3: Inventory and classify

For each repo: `git worktree list --porcelain`, plus a `find` for stray `.git` files or directories under the usual roots that git no longer registers (`git worktree prune --dry-run` names the stale registrations). For each worktree:

| Class | Test | Action |
|---|---|---|
| LIVE | cwd of any process, or in the protected set | keep |
| DIRTY | `git status --porcelain --ignored` non-empty | keep; report as undescribed WIP and whose it might be |
| UNPUSHED | `git log --branches --not --remotes` non-empty for its branch, or HEAD not reachable from any remote ref | keep; report |
| MERGED | branch's PR merged/closed and tree clean and pushed | delete |
| FRESH | created < 1h ago | keep; likely still being set up |
| RESIDUE | directory exists but git no longer registers it, and tests above pass | delete |

Scratch outside any repo (`/tmp/<family>-*`, `~/tmp`, eval log dirs): known families only, idle > 24h, not a live cwd. A bare `/tmp/x` gets a human decision.

## Phase 4: Apply

One item at a time: re-take the cwd snapshot, re-run the class tests, then `git worktree remove --force <path>` (or `rm -rf --one-file-system` for residue), then `git worktree prune`, then `df`, then a ledger line (JSONL: path, class, reason, freed). Stop on the first error and read it.

## Phase 5: Docker

1. `docker system df -v` first; it is the map.
2. `docker image prune -f` (dangling only). Usually the biggest single lever.
3. `docker buildx du`; if reclaimable shows 0 B while the cache is huge, the leases leaked: restart buildkitd (or the builder container), then `docker buildx prune --filter until=24h`.
4. Tagged images: remove only tags no running or stopped container references and no compose file on the box names; check `docker ps -a --format '{{.Image}}'` and the protected set first.
5. Containers: attribute each one before removal. Service containers (postgres, nats, registries, buildx) have no host holder by design and are never reaped. Eval or task sandboxes (compose projects named for a run) are orphaned when no eval process exists and nothing names them, or when their only holder is a dangling `docker exec -it ... bash` shell whose session is gone: kill the shell, then `docker compose -p <project> down -v`. Testcontainers fixtures whose ryuk is gone can be reaped after a 15-minute grace with zero clients; never race a ryuk that exists. When a live session is a plausible owner, ask.
6. `docker volume prune -f` (dangling only). Always safe.

## Phase 6: Caches and temp

- Temp families only, idle > 24h, never by glob on one owner's word (`/tmp/*.patch` can belong to three sessions).
- `uv cache prune` needs the exclusive lock; every `uv run` holds a shared lock for its lifetime, so on a busy box it times out. Run it in a quiet window with `UV_LOCK_TIMEOUT=3600`; never `--force`.
- Per-commit source caches (`~/.cache/<tool>/<sha>`): keep every sha still referenced by a remaining checkout's lockfile, delete the rest.

## Phase 7: Report

Ledger plus a summary: freed, kept-and-why (unpushed, dirty, live, fresh), undescribed WIP found and whose it might be, and anything that could not be reclaimed (locks, live owners). Files go under `~/.local/state/disk-hygiene/`.

## Common mistakes

| Mistake | Reality |
|---|---|
| Parallel `du` to "size things first" | IO storm; sizes are not needed to decide, `df` measures the result |
| `lsof`/`fuser` per candidate | Same storm; one cwd snapshot answers it |
| Trusting mtime for liveness | Rebases rewrite working copies; idle sessions have old mtimes |
| Trusting `git worktree list` alone | It misses directories git forgot and says nothing about unpushed work |
| Skipping the check-in "because it is slow" | Replies routinely move worktrees between delete and keep |
| A protected prefix as broad as `~/dev` | Blocks the owner's own explicit releases; protect exact paths |
| `docker buildx prune` on 0 B reclaimable | Leaked leases; restart buildkitd first |
| Diff of a stale checkout read as a revert | A checkout parented on an old main shows every later merge as "changes"; check `git log origin/main..HEAD` before alarming anyone |
| Deleting a live cwd | Its tools fail with "Working directory does not exist"; re-check liveness immediately before `rm`, not at inventory time |
| Reading a directory name as ownership | Names are not measurements; find the creating command or leave it |
