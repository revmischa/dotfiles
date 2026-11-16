# Shared identity for the runner and timer installer. Paths are canonical so a
# symlink to a checkout cannot create a second schedule or bypass its lock.
operate_repo() {
  [ -d "$1" ] || { echo "no such directory: $1" >&2; return 2; }
  repo=$(cd -- "$1" && pwd -P)
  local top
  top=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || {
    echo "not a Git checkout: $repo" >&2; return 2;
  }
  [ "$repo" = "$(cd -- "$top" && pwd -P)" ] || {
    echo "use the checkout root: $top" >&2; return 2;
  }
  local slug digest
  slug=$(basename -- "$repo" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -c 'a-z0-9' '-' | cut -c1-48)
  digest=$(printf '%s' "$repo" | sha256sum)
  repo_id=${slug}-${digest:0:16}
}

require_runbook() {
  [ -f "$repo/docs/ops/runbook.md" ] || {
    echo "missing docs/ops/runbook.md: bootstrap interactively before scheduling" >&2; return 2;
  }
}

# Unit values use double quotes. Reject specifiers, expansions and controls
# rather than implementing a second systemd escaping language.
unit_value() {
  case "$1" in
    *[\"\'\\%\$]*|*[[:cntrl:]]*) echo "unsupported character in systemd value: $1" >&2; return 2 ;;
  esac
}
