#!/usr/bin/env bash
# One unattended operate-app pass: run.sh <repo path> <daily|health>.
set -euo pipefail
umask 077

usage() { echo 'usage: run.sh <repo path> <daily|health>' >&2; exit 2; }
[ $# -eq 2 ] || usage
mode=$2
case "$mode" in daily|health) ;; *) usage ;; esac
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=common.sh
source "$here/common.sh"
operate_repo "$1"
require_runbook
permission=${OPERATE_APP_PERMISSION_MODE:-dontAsk}
case "$permission" in dontAsk|auto|acceptEdits|manual|plan) ;; *) echo "unsupported permission mode: $permission" >&2; exit 2 ;; esac
if [ -n "${OPERATE_APP_CLAUDE_ARGS:-}" ]; then
  echo 'OPERATE_APP_CLAUDE_ARGS is unsupported; use Claude settings for model and tool configuration' >&2
  exit 2
fi
if [ "$mode" = daily ]; then limit=${OPERATE_APP_DAILY_LIMIT:-4h}; else limit=${OPERATE_APP_HEALTH_LIMIT:-45m}; fi
[[ $limit =~ ^[1-9][0-9]*(s|m|h)$ ]] || { echo 'run limit must be a positive integer followed by s, m or h' >&2; exit 2; }

state=${XDG_STATE_HOME:-$HOME/.local/state}/operate-app/$repo_id
[[ $state = /* ]] || { echo 'XDG_STATE_HOME must be absolute' >&2; exit 2; }
mkdir -p -- "$state/runs" "$state/updates"
chmod 700 -- "$state" "$state/runs" "$state/updates"
# Both modes share the same lock. Overlapping runs are skipped, never queued.
exec 9>"$state/lock"
if ! flock -n 9; then
  echo "$(date -u +%FT%TZ) $mode skipped: another operate-app run holds the lock" >>"$state/runs/skipped.log"
  exit 0
fi
log=$(mktemp "$state/runs/$(date -u +%Y-%m-%dT%H%M%SZ)-$mode-XXXXXXXX.log")
command -v claude >/dev/null || { echo 'run.sh: claude is not on PATH' | tee -a "$log" >&2; exit 127; }

prompt="Scheduled operate-app $mode run. Load the operate-app skill and docs/ops/runbook.md for this checkout. Honor the owner's actual recorded authorizations and repository instructions; the schedule grants no additional permissions. Do not bootstrap, broaden tool access, bypass approvals, or install schedules. If permission or credentials are missing, record the blocker and continue independent read-only work. Save results and pending decisions under $state/updates/. Send reports only to an explicitly authorized destination."
if [ "$mode" = daily ]; then
  prompt+=" Follow the daily procedure. Include the weekly pass if due; keep unfinished work in the local update for the next run."
else
  prompt+=" Follow the bounded health procedure: URLs, alarms, error aggregates since the last completed check and scheduled smoke. Keep production access read-only: do not fix, merge, deploy or perform containment mutations. Record incidents and proposed actions for the next authorized repair task. Stay quiet unless an authorized urgent notification is needed."
fi

cd -- "$repo"
{
  echo "== operate-app $mode repo=$repo start=$(date -u +%FT%TZ) limit=$limit"
  status=0
  timeout --signal=TERM --kill-after=60s "$limit" \
    claude -p "$prompt" --permission-mode "$permission" --permission-prompts none </dev/null || status=$?
  echo "== end=$(date -u +%FT%TZ) exit=$status"
} >>"$log" 2>&1

# Sort NUL-delimited names so an unusual XDG path cannot change what is deleted.
mapfile -d '' -t logs < <(find "$state/runs" -maxdepth 1 -name '*.log' ! -name skipped.log -printf '%T@ %f\0' | sort -zrn)
for ((i = 200; i < ${#logs[@]}; i++)); do
  rm -f -- "$state/runs/${logs[i]#* }"
done
exit "$status"
