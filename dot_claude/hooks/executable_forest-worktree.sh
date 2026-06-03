#!/usr/bin/env bash
# Claude Code WorktreeCreate hook.
# Places `claude --worktree <name>` checkouts under an agent-agnostic root
# (~/.forest/<repo>/<name>) shared with herdr, instead of <repo>/.claude/worktrees.
#
# Input  (stdin JSON): { "name": "<worktree>", "cwd": "<dir inside repo>", ... }
# Output (stdout):     absolute path of the worktree (becomes the session cwd).
# The hook fully replaces Claude's default git-worktree logic, so it must
# create the worktree itself.
set -euo pipefail

input=$(cat)
name=$(printf '%s' "$input" | jq -r '.name')
cwd=$(printf '%s' "$input" | jq -r '.cwd')

toplevel=$(git -C "$cwd" rev-parse --show-toplevel)
repo=$(basename "$toplevel")
forest="${FOREST_DIR:-$HOME/.forest}"
dir="$forest/$repo/$name"

# Everything that is not the final path goes to stderr; stdout must be path-only.
if [ ! -d "$dir" ]; then
  if git -C "$toplevel" show-ref --verify --quiet "refs/heads/$name"; then
    git -C "$toplevel" worktree add "$dir" "$name" >&2
  else
    git -C "$toplevel" worktree add "$dir" -b "$name" >&2
  fi
fi

printf '%s\n' "$dir"
