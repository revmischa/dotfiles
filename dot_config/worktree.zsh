# Claude Code / herdr worktree helpers
# gwf/gwfc launch claude in a worktree; gwcd/gwl/gwrm manage them.
# Worktrees live at ~/.forest/<repo>/<name> (shared with herdr; the location is
# set for claude by ~/.claude/hooks/forest-worktree.sh and for herdr by
# [worktrees] directory in ~/.config/herdr/config.toml).
#
# Inside a herdr session (HERDR_ENV=1) these open the worktree as a focused
# herdr workspace: gwf/gwfc run claude in its root pane, gwcd just focuses it.
# Outside herdr they fall back to launching claude in the current shell / plain cd.

_gwt_base() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  echo "${FOREST_DIR:-$HOME/.forest}/${toplevel##*/}"
}

# True when running inside a herdr pane with a reachable server.
_gwt_in_herdr() {
  [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_SOCKET_PATH:-}" ] &&
    command -v herdr >/dev/null 2>&1
}

# Ensure a git worktree exists at the forest path; echoes the path on stdout.
# Mirrors ~/.claude/hooks/forest-worktree.sh: reuse the branch if it exists,
# otherwise start a new one. Progress goes to stderr so stdout stays path-only.
_gwt_ensure() {
  local toplevel base dest
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n" >&2
    return 1
  }
  base="${FOREST_DIR:-$HOME/.forest}/${toplevel##*/}"
  dest="$base/$1"
  if [ ! -d "$dest" ]; then
    if git -C "$toplevel" show-ref --verify --quiet "refs/heads/$1"; then
      git -C "$toplevel" worktree add "$dest" "$1" >&2 || return 1
    else
      git -C "$toplevel" worktree add "$dest" -b "$1" >&2 || return 1
    fi
    printf "\033[32m  created\033[0m \033[1m%s\033[0m\n" "$1" >&2
  fi
  echo "$dest"
}

_gwt_pick() {
  local base; base=$(_gwt_base) || return 1
  local dirs=("$base"/*(N/))
  [ ${#dirs} -eq 0 ] && {
    printf "\033[2m  no worktrees\033[0m\n"
    return 1
  }
  for d in "${dirs[@]}"; do
    local name="${d##*/}"
    local branch=$(git -C "$d" branch --show-current 2>/dev/null)
    local dirty=""
    [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty=" *"
    printf "%-20s  %s%s\n" "$name" "$branch" "$dirty"
  done | fzf --prompt="  " --height=~40% --reverse --ansi | awk '{print $1}'
}

_gwt_session() {
  local toplevel
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  if _gwt_in_herdr; then
    # Open the worktree as a focused herdr workspace, run claude in its root pane.
    local dest out already pane
    dest=$(_gwt_ensure "$1") || return 1
    out=$(herdr worktree open --path "$dest" --focus --json 2>/dev/null) || {
      printf "\033[31m  herdr: failed to open worktree\033[0m\n"
      return 1
    }
    already=$(printf '%s' "$out" | jq -r '.result.already_open // false')
    if [ "$already" = "true" ]; then
      printf "\033[2m  switched to existing\033[0m \033[1m%s\033[0m\n" "$1"
      return 0
    fi
    pane=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
    [ -z "$pane" ] && {
      printf "\033[31m  herdr: no pane id in response\033[0m\n"
      return 1
    }
    herdr pane run "$pane" "claude --permission-mode ${CLAUDE_PERMISSION_MODE:-auto}${2:+ $2}" >/dev/null &&
      printf "\033[32m  started claude in\033[0m \033[1m%s\033[0m\n" "$1"
  else
    (cd "$toplevel" && claude --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" --worktree "$1" ${2:+"$2"})
    # Stay in the worktree after claude exits, if it was created
    local dest="${FOREST_DIR:-$HOME/.forest}/${toplevel##*/}/$1"
    [ -d "$dest" ] && cd "$dest"
  fi
}

gwf() {
  [ -z "$1" ] && {
    printf "\033[2m  usage: gwf <name>\033[0m\n"
    return 1
  }
  _gwt_session "$1" ""
}

gwfc() {
  [ -z "$1" ] && {
    printf "\033[2m  usage: gwfc <name>\033[0m\n"
    return 1
  }
  _gwt_session "$1" "--chrome"
}

# List worktrees for the current repo with branch and status info.
# Uses the herdr API when available (marks worktrees open as herdr workspaces),
# otherwise falls back to globbing the forest directory.
gwl() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  local repo=$(basename "$toplevel")

  if command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local json
    json=$(herdr worktree list --json 2>/dev/null)
    if [ -n "$json" ]; then
      printf "\n\033[1;34m  %s\033[0m \033[2mworktrees\033[0m\n\n" "$repo"
      printf '%s' "$json" | jq -r '
        .result.worktrees[]
        | select(.is_linked_worktree == true)
        | [ .path, .branch, (if .open_workspace_id then "1" else "0" end) ]
        | @tsv' |
        while IFS=$'\t' read -r path branch open; do
          local name="${path##*/}"
          local short=$(git -C "$path" log -1 --format="%s" 2>/dev/null)
          local dirty=""
          [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && dirty="\033[33m*\033[0m"
          local mark="  "
          [ "$open" = "1" ] && mark="\033[35m●\033[0m "
          printf "  %b\033[32m%-20s\033[0m \033[36m%-30s\033[0m \033[2m%.40s\033[0m %b\n" \
            "$mark" "$name" "$branch" "$short" "$dirty"
        done
      printf "\n  \033[35m●\033[0m \033[2mopen as herdr workspace\033[0m\n\n"
      return 0
    fi
  fi

  # Fallback: on-disk forest dirs
  local base="${FOREST_DIR:-$HOME/.forest}/$repo"
  local dirs=("$base"/*(N/))
  if [ ${#dirs} -eq 0 ]; then
    printf "\033[2m  no worktrees for \033[0m\033[1m%s\033[0m\n" "$repo"
    return 0
  fi
  printf "\n\033[1;34m  %s\033[0m \033[2mworktrees\033[0m\n\n" "$repo"
  for d in "${dirs[@]}"; do
    local name="${d##*/}"
    local branch=$(git -C "$d" branch --show-current 2>/dev/null)
    local short=$(git -C "$d" log -1 --format="%s" 2>/dev/null)
    local dirty=""
    [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty="\033[33m *\033[0m"
    printf "  \033[32m%-20s\033[0m \033[36m%-25s\033[0m \033[2m%.50s\033[0m%b\n" "$name" "$branch" "$short" "$dirty"
  done
  printf "\n"
}

# Go to a worktree, creating it if missing. Inside herdr this opens (and focuses)
# the worktree as a workspace; outside herdr it cd's the current shell.
gwcd() {
  local target="$1"
  if [ -z "$target" ]; then
    if command -v fzf >/dev/null; then
      target=$(_gwt_pick) || return 1
      [ -z "$target" ] && return 0
    else
      gwl
      printf "\033[2m  usage: gwcd <name>\033[0m\n"
      return 1
    fi
  fi
  local dest
  dest=$(_gwt_ensure "$target") || return 1
  if _gwt_in_herdr; then
    herdr worktree open --path "$dest" --focus --json >/dev/null 2>&1 &&
      printf "\033[34m  opened workspace\033[0m \033[1m%s\033[0m\n" "$target"
  else
    cd "$dest"
  fi
}

gwrm() {
  local base; base=$(_gwt_base) || return 1
  local target="$1"
  if [ -z "$target" ] && command -v fzf >/dev/null; then
    target=$(_gwt_pick) || return 1
  fi
  [ -z "$target" ] && {
    gwl
    printf "\033[2m  usage: gwrm <name>\033[0m\n"
    return 1
  }
  git worktree remove --force "$base/$target" 2>/dev/null &&
    printf "\033[31m  removed\033[0m \033[1m%s\033[0m\n" "$target" ||
    printf "\033[33m  failed to remove %s\033[0m\n" "$target"
}

_gwt_completions() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return
  local base="${FOREST_DIR:-$HOME/.forest}/${toplevel##*/}"
  [ -d "$base" ] || return
  compadd -- "$base"/*(N/:t)
}
compdef _gwt_completions gwcd gwrm

# herdr quality-of-life aliases
if command -v herdr >/dev/null 2>&1; then
  alias hd='herdr'                    # launch / attach the persistent session
  alias hda='herdr session attach'   # attach a named session: hda <name>
  alias hst='herdr status'           # client + server status
  alias hw='herdr worktree list'     # worktrees known to herdr
  alias hws='herdr workspace list'   # open workspaces
fi
