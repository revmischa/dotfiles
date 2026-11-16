#!/usr/bin/env bash
# Install, preview or remove systemd user timers for one bootstrapped checkout.
set -euo pipefail
umask 077

usage() {
  echo 'usage: install-timer.sh <repo> [--daily HH:MM] [--health 0|1|2|3|4|6|8|12|24] [--dry-run] [--uninstall]'
}
fail() { echo "$*" >&2; exit 2; }
repo='' daily=09:30 health=3 dry=0 uninstall=0
while [ $# -gt 0 ]; do
  case "$1" in
    --daily) [ $# -ge 2 ] || fail '--daily needs HH:MM'; daily=$2; shift 2 ;;
    --health) [ $# -ge 2 ] || fail '--health needs a number of hours'; health=$2; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) fail "unknown option: $1" ;;
    *) [ -z "$repo" ] || fail 'only one repo is accepted'; repo=$1; shift ;;
  esac
done
[ -n "$repo" ] || { usage >&2; exit 2; }
[[ $daily =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || fail '--daily must be HH:MM'
case "$health" in 0|1|2|3|4|6|8|12|24) ;; *) fail '--health must be 0 or a divisor of 24 without leading zeroes' ;; esac

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$here/common.sh"
operate_repo "$repo"
unit_dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
[[ $unit_dir = /* ]] || fail 'XDG_CONFIG_HOME must be absolute'
base=operate-app-$repo_id

if [ "$uninstall" -eq 1 ]; then
  if [ "$dry" -eq 1 ]; then
    echo "would disable $base-{daily,health}.timer and remove their timer/service files from $unit_dir"
    exit 0
  fi
  for kind in daily health; do
    if [ -e "$unit_dir/$base-$kind.timer" ]; then
      systemctl --user disable --now "$base-$kind.timer"
    fi
    rm -f -- "$unit_dir/$base-$kind.timer" "$unit_dir/$base-$kind.service"
  done
  systemctl --user daemon-reload
  echo "removed $base timers; active runs, transcripts and updates retained"
  exit 0
fi

require_runbook
run=$here/run.sh
unit_value "$run"
unit_value "$repo"
unit_value "$PATH"
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
[[ $state_home = /* ]] || fail 'XDG_STATE_HOME must be absolute'
unit_value "$state_home"
[ "$dry" -eq 1 ] || [ -x "$run" ] || fail "missing executable: $run; apply the skill with chezmoi first"

service() { # kind limit
  cat <<UNIT
[Unit]
Description=operate-app $1 run for $repo_id
After=network-online.target

[Service]
Type=oneshot
ExecStart="$run" "$repo" $1
Environment="PATH=$PATH"
Environment="XDG_STATE_HOME=$state_home"
UMask=0077
TimeoutStartSec=$2
Nice=5
UNIT
}
timer() { # kind calendar persistent
  cat <<UNIT
[Unit]
Description=operate-app $1 schedule for $repo_id

[Timer]
OnCalendar=$2
Persistent=$3
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
UNIT
}
emit() {
  if [ "$dry" -eq 1 ]; then
    echo "--- $1"; cat; echo
  else
    local temp
    temp=$(mktemp "$unit_dir/.operate-app.XXXXXXXX")
    cat >"$temp"
    mv -f -- "$temp" "$1"
  fi
}

[ "$dry" -eq 1 ] || mkdir -p -- "$unit_dir"
service daily 5h | emit "$unit_dir/$base-daily.service"
timer daily "*-*-* $daily:00" true | emit "$unit_dir/$base-daily.timer"
if [ "$health" -gt 0 ]; then
  service health 1h | emit "$unit_dir/$base-health.service"
  health_hour="0/$health"
  [ "$health" -ne 24 ] || health_hour=00
  timer health "*-*-* $health_hour:17:00" false | emit "$unit_dir/$base-health.timer"
fi
if [ "$dry" -eq 1 ]; then
  echo "dry run: nothing written. Units would go to $unit_dir"
  exit 0
fi

if [ "$health" -eq 0 ] && [ -e "$unit_dir/$base-health.timer" ]; then
  systemctl --user disable --now "$base-health.timer"
  rm -f -- "$unit_dir/$base-health.timer" "$unit_dir/$base-health.service"
fi
systemctl --user daemon-reload
systemctl --user enable --now "$base-daily.timer"
[ "$health" -eq 0 ] || systemctl --user enable --now "$base-health.timer"

if [ "$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null)" != yes ]; then
  echo "note: timers stop at logout unless lingering is enabled for $(id -un)" >&2
fi
systemctl --user list-timers "$base-*" --no-pager
echo "transcripts: ${XDG_STATE_HOME:-$HOME/.local/state}/operate-app/$repo_id/runs/"
if [ "$health" -gt 0 ]; then
  echo "try it once: systemctl --user start $base-health.service"
else
  echo "health timer disabled; daily service: $base-daily.service"
fi
