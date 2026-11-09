# Claude Code / Herdr worktree helpers
# gwf/gwfc launch claude in a worktree; gwcd/gwl/gwrm manage them.
# Worktrees live at ~/.forest/<repo>/<name> (the location is set for claude by
# ~/.claude/hooks/forest-worktree.sh; these helpers create them with git).
#
# Inside a Herdr.app terminal (herdr-core sets HC_TERMINAL_ID) these open the
# worktree as its own Herdr space named <repo>/<name>, via herdr-app: gwf/gwfc
# run claude in it, gwcd just opens or shows it. herdr-core (`hc`) has no
# worktree or space commands of its own. Outside Herdr they fall back to
# launching claude in the current shell / plain cd.

# Main-repo name, stable from inside linked worktrees (show-toplevel is not).
_gwt_repo() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  basename "$(dirname "$common")"
}

_gwt_base() {
  local repo
  repo=$(_gwt_repo) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  echo "${FOREST_DIR:-$HOME/.forest}/$repo"
}

# True when running inside a Herdr.app terminal with the app CLI available.
_gwt_in_herdr() {
  [ -n "${HC_TERMINAL_ID:-}" ] && command -v herdr-app >/dev/null 2>&1 &&
    command -v jq >/dev/null 2>&1
}

# Ids of open Herdr spaces rooted at a folder, from `herdr-app ls`.
_gwt_spaces_at() {
  herdr-app ls 2>/dev/null |
    jq -r --arg f "$1" '.spaces[]? | select(.folder == $f) | .id'
}

# Open the worktree at $2 as a Herdr space named <repo>/$1, or show the one
# already open there. Remaining args, if any, are the program to run in it.
_gwt_open_space() {
  local name=$1 dest=$2 space repo
  shift 2
  space=$(_gwt_spaces_at "$dest" | head -n 1)
  if [ -n "$space" ]; then
    herdr-app do space.select --id "$space" >/dev/null 2>&1 &&
      printf "\033[2m  switched to existing\033[0m \033[1m%s\033[0m\n" "$name"
    return
  fi
  repo=$(_gwt_repo) || return 1
  if [ $# -gt 0 ]; then
    herdr-app do space.new --name "$repo/$name" --folder "$dest" \
      --argv "$(printf '%s\n' "$@" | jq -nRc '[inputs]')" >/dev/null 2>&1
  else
    herdr-app do space.new --name "$repo/$name" --folder "$dest" >/dev/null 2>&1
  fi || {
    printf "\033[31m  herdr-app: failed to open space\033[0m\n"
    return 1
  }
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
  base=$(_gwt_base) || return 1
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
    # Open the worktree as its own Herdr space running claude, or show it if open.
    local dest
    dest=$(_gwt_ensure "$1") || return 1
    if [ -n "$(_gwt_spaces_at "$dest")" ]; then
      _gwt_open_space "$1" "$dest"
      return
    fi
    _gwt_open_space "$1" "$dest" claude --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" ${2:+"$2"} &&
      printf "\033[32m  started claude in\033[0m \033[1m%s\033[0m\n" "$1"
  else
    (cd "$toplevel" && claude --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" --worktree "$1" ${2:+"$2"})
    # Stay in the worktree after claude exits, if it was created
    local dest="$(_gwt_base)/$1"
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
# Inside Herdr, worktrees open as a Herdr space are marked.
gwl() {
  local repo
  repo=$(_gwt_repo) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }

  local base; base=$(_gwt_base) || return 1
  local dirs=("$base"/*(N/))
  if [ ${#dirs} -eq 0 ]; then
    printf "\033[2m  no worktrees for \033[0m\033[1m%s\033[0m\n" "$repo"
    return 0
  fi
  local open=""
  _gwt_in_herdr && open=$(herdr-app ls 2>/dev/null | jq -r '.spaces[]?.folder')
  printf "\n\033[1;34m  %s\033[0m \033[2mworktrees\033[0m\n\n" "$repo"
  for d in "${dirs[@]}"; do
    local name="${d##*/}"
    local branch=$(git -C "$d" branch --show-current 2>/dev/null)
    local short=$(git -C "$d" log -1 --format="%s" 2>/dev/null)
    local dirty=""
    [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty="\033[33m *\033[0m"
    local mark="  "
    [ -n "$open" ] && print -r -- "$open" | grep -qxF -- "$d" && mark="\033[35m●\033[0m "
    printf "  %b\033[32m%-20s\033[0m \033[36m%-25s\033[0m \033[2m%.50s\033[0m%b\n" \
      "$mark" "$name" "$branch" "$short" "$dirty"
  done
  [ -n "$open" ] && printf "\n  \033[35m●\033[0m \033[2mopen as a Herdr space\033[0m"
  printf "\n"
}

# Go to a worktree, creating it if missing. Inside Herdr this opens (or shows)
# the worktree as a Herdr space; outside Herdr it cd's the current shell.
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
    if [ -n "$(_gwt_spaces_at "$dest")" ]; then
      _gwt_open_space "$target" "$dest"
    else
      _gwt_open_space "$target" "$dest" &&
        printf "\033[34m  opened space\033[0m \033[1m%s\033[0m\n" "$target"
    fi
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
  local base; base=$(_gwt_base 2>/dev/null) || return
  [ -d "$base" ] || return
  compadd -- "$base"/*(N/:t)
}
compdef _gwt_completions gwcd gwrm

# Herdr quality-of-life aliases. Terminals run in herdr-core (`hc`); Herdr.app
# (`herdr-app`) shows and arranges them. The old `herdr` multiplexer's worktree
# list has no equivalent; use gwl.
if command -v hc >/dev/null 2>&1; then
  alias hda='hc attach'              # attach a terminal: hda <t> (ctrl+\ detaches)
  alias hst='hc server status'       # herdr-core status
  alias hls='hc ls'                  # live terminals
fi
if command -v herdr-app >/dev/null 2>&1; then
  alias hd='herdr-app'               # open / raise the Herdr window
  alias hws='herdr-app ls'           # spaces, tabs and terminals
fi
