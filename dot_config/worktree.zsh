# Claude Code worktree helpers
# Uses claude --worktree and --tmux for session management
# Worktrees live at <repo>/.claude/worktrees/<name>

_gwt_base() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  echo "$toplevel/.claude/worktrees"
}

_gwt_dirs() {
  local base=$(_gwt_base) || return 1
  local dirs=("$base"/*(N/))
  [ ${#dirs} -eq 0 ] && {
    printf "\033[2m  no worktrees\033[0m\n"
    return 1
  }
  echo "${dirs[@]}"
}

_gwt_pick() {
  local base=$(_gwt_base) || return 1
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
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  local repo=$(basename "$toplevel")
  local session_name="$repo/$1"
  local wt_path="$toplevel/.claude/worktrees/$1"
  local claude_cmd="cd '$toplevel' && claude --dangerously-skip-permissions --worktree '$1' $2"
  tmux new-session -d -s "$session_name" -c "$toplevel" "$SHELL -ic \"$claude_cmd\"" 2>/dev/null
  tmux set-option -t "$session_name" default-command "cd '$wt_path' 2>/dev/null; exec $SHELL"
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
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

# Switch to an existing worktree session, or list them if no argument is given
gwss() {
  local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep '/')
  [ -z "$sessions" ] && {
    printf "\033[2m  no worktree sessions\033[0m\n"
    return 1
  }
  local choice
  if [ -n "$1" ]; then
    choice=$(echo "$sessions" | grep -F "$1" | head -1)
    [ -z "$choice" ] && {
      printf "\033[31m  no session matching '%s'\033[0m\n" "$1"
      return 1
    }
  elif command -v fzf >/dev/null; then
    choice=$(echo "$sessions" | fzf --prompt="  " --height=~40% --reverse)
    [ -z "$choice" ] && return 0
  else
    echo "$sessions"
    printf "\033[2m  usage: gws <name>\033[0m\n"
    return 1
  fi
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$choice"
  else
    tmux attach-session -t "$choice"
  fi
}

# List worktrees for the current repo with branch and status info
gwl() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf "\033[31m  not in a git repo\033[0m\n"
    return 1
  }
  local repo=$(basename "$toplevel")
  local base="$toplevel/.claude/worktrees"
  local dirs=("$base"/*(N/))
  if [ ${#dirs} -eq 0 ]; then
    printf "\033[2m  no worktrees for \033[0m\033[1m%s\033[0m\n" "$repo"
    return 0
  fi
  printf "\n\033[1;34m  %s\033[0m \033[2mworktrees\033[0m\n\n" "$repo"
  for d in "${dirs[@]}"; do
    local name="${d##*/}"
    local branch=$(git -C "$d" branch --show-current 2>/dev/null)
    local short=$(git -C "$d" log -1 --format="%s" 2>/dev/null | cut -c1-50)
    local dirty=""
    [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty="\033[33m *\033[0m"
    printf "  \033[32m%-20s\033[0m \033[36m%-25s\033[0m \033[2m%s\033[0m%b\n" "$name" "$branch" "$short" "$dirty"
  done
  printf "\n"
}

gwcd() {
  local base=$(_gwt_base) || return 1
  if [ -n "$1" ]; then
    [ -d "$base/$1" ] || {
      printf "\033[31m  worktree '%s' not found\033[0m\n" "$1"
      return 1
    }
    cd "$base/$1"
  elif command -v fzf >/dev/null; then
    local choice=$(_gwt_pick) || return 1
    [ -n "$choice" ] && cd "$base/$choice"
  else
    gwl
    printf "\033[2m  usage: gwcd <name>\033[0m\n"
  fi
}

gwrm() {
  local base=$(_gwt_base) || return 1
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
  local base="$toplevel/.claude/worktrees"
  [ -d "$base" ] || return
  compadd -- "$base"/*(N/:t)
}
compdef _gwt_completions gwcd gwrm
