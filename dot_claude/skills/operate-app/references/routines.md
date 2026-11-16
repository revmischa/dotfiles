# Routines and schedules

## Durable operation

Monitoring and repair have different lifetimes:

| Layer | Purpose | Dependency |
| --- | --- | --- |
| Agent-independent checks | Alarms, scheduled production smoke and cost alerts | Their cloud or CI service, credentials and delivery path |
| Durable agent schedule | Daily review and bounded health triage | A running host, valid credentials and an approved execution policy |
| Optional session cron | Temporary checks during an active session | Session availability and task expiry |

Use one scheduler per repo and mode. A session cron is an alternative or a
reminder, not a second operator running beside the timer. Manual unattended runs
use the same wrapper and lock. A different host has a different lock: designate
one operator host, or add shared coordination before scheduling on several.
Git worktrees have distinct paths; register only the designated operations
checkout for a logical app. Independent monitoring remains necessary when an
agent is blocked, skipped or offline.

### Linux user timer

Prepare and review units before installing. A requested schedule includes its
necessary setup, but an ordinary health review does not authorize recurring work.

```bash
~/.claude/skills/operate-app/scripts/install-timer.sh /absolute/repo --dry-run
~/.claude/skills/operate-app/scripts/install-timer.sh /absolute/repo --daily 08:15 --health 6
~/.claude/skills/operate-app/scripts/install-timer.sh /absolute/repo --uninstall --dry-run
~/.claude/skills/operate-app/scripts/install-timer.sh /absolute/repo --uninstall
systemctl --user list-timers 'operate-app-*'
```

Defaults are daily at 09:30 in the host timezone and health every three hours.
Health runs start at minute 17; timers add a small randomized delay. Daily runs
catch up after downtime; health waits for the next scheduled interval.
`--health 0` disables health scheduling. The installer prints exact unit names
and the manual test command. Names include a hash of the canonical repo path so
repositories sharing a basename stay separate.

The wrapper locks the repo's state directory, starts `claude -p` in that checkout,
and limits runtime (daily four hours, health 45 minutes). A run finding the lock
held is recorded as skipped, not queued. Transcript retention is bounded. Inspect
both the transcript and `journalctl --user -u <service>` for failures that occur
before logging starts. An exit code of zero alone does not prove all checks ran.

The permission default is `dontAsk`: existing tool permissions apply and new
permission requests are denied. A deliberately configured
`OPERATE_APP_PERMISSION_MODE` may use a supported non-bypass mode; it never grants
business authority. Configure only the tools and credentials the run needs.
Never use bypass-permission flags to make a timer work. Inspect `claude --help`
for the installed CLI before changing invocation options.

The installer snapshots `PATH` and `XDG_STATE_HOME` into each service. It does not
start a login shell or inherit other variables from the installing terminal.
Configure a specific service with `systemctl --user edit <exact-service-name>`
when an approved non-default policy or runtime limit is needed, for example:

```ini
[Service]
Environment="OPERATE_APP_PERMISSION_MODE=dontAsk"
Environment="OPERATE_APP_DAILY_LIMIT=4h"
Environment="OPERATE_APP_HEALTH_LIMIT=45m"
```

Limits accept positive whole seconds, minutes or hours (`30s`, `45m`, `4h`);
keep them below the service's `TimeoutStartSec`, allowing its 60-second kill grace.
Configure service credentials through the established credential provider; do
not paste secrets into unit files or the runbook. Arbitrary
`OPERATE_APP_CLAUDE_ARGS` is rejected: use Claude settings for model and tool
configuration. Manual runs inherit their caller's environment, so they alone do
not prove systemd credential access.

Run the emitted health service manually once and inspect the result before
calling the schedule active. With `--health 0`, use
`scripts/run.sh /absolute/repo health` for a manual read-only check; verify the
daily service environment separately within its authorized scope. Confirm systemd user services are supported and
whether lingering is enabled; timers cannot run on a powered-off host. Record
host timezone, credential expiry, the exact units, last successful execution and
who notices missed runs. Monitoring for stale agent runs must live outside the
agent itself. Keep paths to credentials, not their values, in the runbook.

Do not create credentials, enable lingering, or change shared permissions merely
to resolve a missing capability. Carry forward existing authorization, prepare
any remaining decision, and continue independent work.

### Other schedulers

Use an already established scheduler when it has the required repo, tools and
credentials. Do not install systemd as a dependency on an unsupported platform.
For session crons, discover available tools, inspect task expiry and renew only
those this operation owns. Session tasks are not a durable substitute: see the
[current scheduling documentation](https://code.claude.com/docs/en/scheduled-tasks).
Do not assume local AWS profiles or local connectors exist in a cloud runner.

## State between runs

Under `${XDG_STATE_HOME:-$HOME/.local/state}/operate-app/<repo-id>/`, retain private
transcripts in `runs/`, owner update drafts in `updates/`, and an operator-maintained
`state.json`. The wrapper owns the lock and logs; the agent owns semantic state.
Do not create another source of truth in session memory.

Record only operational metadata, never secrets, personal data or raw payloads:

- last successful query end time per source and stage;
- last completed daily and weekly pass;
- open incident fingerprints, first/last seen, severity and recovery status;
- notification destination, last delivered fingerprint/time and failed delivery;
- current run's completed steps, pending work and proposed/merged/deployed revision.

Write state atomically while holding the wrapper lock. Advance a source cursor
only after its query completes successfully; preserve gaps on failures. Query a
small overlap for delayed ingestion and deduplicate by stable incident signature.
The first run uses an explicit bounded lookback and reports its coverage. A failed
notification is not delivered; retry within the approved channel's limits. Record
credential expiry once, then probe quietly and notify on recovery or changed impact.
Interactive mutating runs must coordinate with the scheduled runner before writing
shared state. `status` reads state without acquiring a writing role or changing it.

## Prompts

The wrapper supplies these tasks; it must not duplicate the workflow or broaden
authority. For another scheduler, use the same intent:

- **Daily:** load this skill and the repo runbook, do the daily pass, include weekly
  work when due, honor standing instructions and recorded approvals, save an update,
  and deliver only through an authorized destination. Leave unapproved actions as
  concrete proposals and record incomplete work.
- **Health:** load this skill and runbook, perform bounded read-only production
  triage, record health and incidents locally, and notify only through an already
  authorized channel when the interrupt criteria apply. Do not fix, merge or deploy.

## Daily run

1. **Resume.** Read runbook, previous update and state. Check the actual deployed
   revision and unfinished work; do not infer completion from yesterday's plan.
2. **Schedules.** Inspect owned schedules and their last results, including missed
   or skipped runs. Renew only an authorized expiring schedule.
3. **Health.** Check each URL's expected status with a bounded timeout, health and
   release response, alarms, last deploy and scheduled smoke history. A recovered
   smoke failure still needs triage. Select the correct account, region and stage.
4. **Errors.** Read backend errors, timeouts, throttles and queue age; frontend
   sanitized signatures and failed calls; CDN errors, database signals, quota and
   expiry warnings, and available cost data. Aggregate by release, route and code.
   Record count, first seen and impact; mark unknown causes as unknown.
5. **Usage.** Yesterday and trailing seven days versus the previous seven, with UTC
   windows: observed visitors/clients, channels, landing pages, funnel, retention
   where measurable, and revenue. Use configured first-party analytics, GA4 or
   Search Console only when available and authorized. Keep sources separate;
   missing data is not zero. Payment reconciliation reports aggregate mismatches
   from a scoped query, without returning customer records or fixing entitlements.
6. **Experiments.** Check guardrails and stop rules. Read out completed experiments;
   do not start another without a measurable question and sufficient traffic.
7. **Repair and improve.** Prioritize user harm, reproduce, fix and verify within
   authority. Choose one justified improvement if time remains. Record blocked
   actions and their concrete proposed changes. A no-change day is valid.
8. **Browser.** Follow `browser-checks.md` on the applicable stages. Record missing
   browser access as incomplete coverage, not a successful walk.
9. **Record and report.** Update durable state, the local update, and relevant
   runbook, backlog, baseline and experiment files. Documentation changes use the
   normal review path; routine timestamps belong in local state. Report using
   `SKILL.md` and record delivery separately from completion of the work.

## Health check

Aim for five minutes of read-only triage: URLs, expected release, alarms, recent
error aggregates, invocation counts, scheduled smoke and stale monitoring. An
empty query is meaningful only if the query succeeded and traffic was expected.
Known noise may be excluded only within its documented conditions and expiry;
a changed volume, release or impact reopens it.

Record new incidents for daily repair; interrupt for an unrecovered outage,
security signal or urgent decision through an authorized channel. Do not start
fixes or deployments from this mode. A request to repair switches to a separately
authorized repair task; it is not an implied side effect of the health schedule.

## Weekly pass

Add to the daily review, recording what was actually completed:

- Dependency and security updates: review relevant findings and changes; green
  automated PRs still follow merge authorization. Run focused scans, not an
  offensive test without scope. Security boundary escapes stop immediately.
- Cost by service and per core action, idle resources and quota headroom. Inspect
  infrastructure previews for drift within the permitted access scope.
- Full browser walk at desktop and phone widths, plus measured performance changes.
- Recovery readiness: inspect backup age and prior restore evidence. An actual
  restore, access to its contents or resource deletion requires an approved drill,
  isolated destination, access restrictions and cleanup plan. Do not copy prod
  data into dev or onto the operator's machine.
- Housekeeping: only worktrees/resources this operation created, after checking
  dirty and unpushed work and the applicable deletion authorization.
- README, agent guidance and runbook against current behavior.

Include the week's numbers, shipped changes, experiment findings and next work in
the daily update. A blocked restore drill is a reported gap, not a passed check.

## Status mode

Read-only: health, metrics with freshness, incidents, experiments, owner decisions
and last schedule executions. Respond in the current conversation. Do not edit
state, renew timers, repair defects or deliver to an external channel.

## Measurement and prioritization

- Running JavaScript measures observed JS clients, not verified humans. Bots can
  run it and people can block it. Define bot filtering and label the remaining
  uncertainty. Do not infer users or retention from aggregate event counts.
- Exclude synthetic traffic and staff using explicit markers or known staff roles;
  geography cannot identify an owner. Avoid identifying people to improve a count.
- Name source, window, timezone and filters. Mark days before a filter existed.
  Do not silently replace an unavailable filtered metric with an unfiltered one.
- At low volume report counts and denominators, such as “7 of 31,” and avoid trend
  claims from a single day. Compare like weekdays and account for incomplete days.
- Rank improvements by observed impact, evidence and effort. If measurement is
  inadequate, improve it within the approved data policy; do not invent a finding.

## Interrupted or failed runs

Persist progress before a long phase; a killed process may not get a final write.
On resume, reconcile open PRs, CI and actual deployed revisions before retrying
mutations. Never retry a payment, message or deploy merely because its response
was lost. If one source or credential fails, complete independent checks and mark
the gap. Red CI on main blocks promotion. Follow `SKILL.md` stop conditions for
incidents; rollback remains subject to its recorded authority and compatibility.
