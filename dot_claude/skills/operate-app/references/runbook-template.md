# Runbook template

Copy to `docs/ops/runbook.md` in the app's repo and fill it in at bootstrap. It is
the first file every run reads, so keep it short and current. No secrets, no
personal data: name where a credential lives, never its value.

Create beside it: `metrics.md` (definitions, baselines, budgets), `backlog.md`
(ranked, with evidence), `decisions.md` (dated, with how to undo), and
`experiments/` (one file each).

```markdown
# <App> operations runbook

Last verified: <date>

## What this is
One paragraph: what the product does, for whom, the value moment, how it makes
money (or does not yet). Existing compatibility requirements.

## Owner and channels
- Owner: <role>, reads the daily update at: <channel or file>
- Interrupt channel (prod down, rollback, security, deadline): <channel>
- Delivery authorization: <source and scope; absent means local draft only>
- Owner's standing decisions and limits: <link to decisions.md entries>
- Exclude from traffic numbers: <how owners and synthetic traffic are identified>

## Authority
| Action | App / stage | Approval source | Limits / expiry |
| --- | --- | --- | --- |
| Merge / auto-merge | | unapproved until recorded | |
| Deploy / rollback / production writes | | unapproved until recorded | |
| Recurring schedule and execution policy | | unapproved until recorded | |
| External reports / urgent notices | | unapproved until recorded | |
| Spend / restore drills / cleanup | | unapproved until recorded | |

Record actual owner decisions, not inferred permission. Preserve requirements for
recent confirmation. Prepare blocked actions; continue independent authorized work.

## Stages and access
| Stage | URL | AWS profile / account alias | Region | Deployed by |
| --- | --- | --- | --- | --- |
| dev | | | | push to main |
| prod | | | | <promotion: branch, tag, or manual approval> |

- Login when credentials expire: `<command>` (needs a human: yes/no)
- Where secrets live: <SSM path / secret store>; how to list their names

## Path to prod
1. Worktree at <path convention>, branch off origin/main or the existing PR branch; no upstream tracking to main
2. Local gates: `<command>`
3. Draft PR and reviewers per repo rules; CI green: `<required checks>`
4. Authorized merge: `<command and approval>`; dev deploy: `<trigger and approval>`
5. Verify on dev: <what to look at>
6. Authorized promotion: `<commands pinned to the verified artifact/revision>`
7. After: smoke run `<where>`, then the error query for 15 minutes

Rollback: `<exact commands and authority>`; last verified in dev on <date>.
Compatible data/schema versions: <limits>; last good artifact: <how to find it>.
Never: <repo-specific rules: deploy locks, branches not to touch, files not to edit>

## Health
| Check | Expected |
| --- | --- |
| `curl -sS --max-time 20 -o /dev/null -w '%{http_code}' <url>` | 200 |
| <redirect host> | 308 |
| <health endpoint> | 200 and release = last deploy |

- Alarms: `<command or dashboard>`
- Scheduled smoke: `<workflow name>`, every <n> minutes
- Dashboard: <link>

## Queries
- Backend errors: `<script> '<window>'`
- Frontend errors: `<script or query>`
- Traffic and usage: `<script>` (flags for excluding owners)
- Google Analytics / Search Console: <property id, how to reach it>
- Revenue and reconciliation: `<script>`
- Cost: `<command>`

## Critical paths (browser walk and smoke)
| Path | Steps | A user should see | Checked on |
| --- | --- | --- | --- |
| Core action, signed out | | | prod |
| Sign up and sign in | | | dev only |
| Upgrade and pay | | | dev, provider test mode |

Fixtures: <path>. Test users: <how seeded in dev and cleaned up>.
Production suite: <read-only subset and guards against writes>.

## Funnel and key numbers
Pointer to `metrics.md`. The one number that matters: <metric>, usual value <n>/day.

## Known noise
| Pattern | Evidence / scope | Volume threshold | Review expiry |
| --- | --- | --- | --- |

## Data inventory
| Data | Where | Why | Retention | Leaves AWS to |
| --- | --- | --- | --- | --- |

## Vendors and costs
| Service | For | Cost basis | Kill switch |
| --- | --- | --- | --- |

Monthly budget: <approved amount>, alerts at 50/80/100%.
Incident cost threshold: <absolute amount and comparison window>.

## Schedules
| What | Where | Last confirmed |
| --- | --- | --- |
| Smoke against prod | CI workflow `<name>` | |
| Daily run | systemd timer `operate-app-<repo-id>-daily` or alternate scheduler | |
| Health check | systemd timer `operate-app-<repo-id>-health` or alternate scheduler | |
| Weekly day | <weekday> | |

Operator host / checkout: <one designated host and canonical path>.
Repo id: <exact id printed by installer>; host timezone: <zone>.
Execution policy and credentials: <configured locations, never values>.
Transcript / update / state paths: <XDG state directory>.
Missed-run detection: <independent check, threshold, approved destination>.
Last manual health validation: <time, result and evidence>.
Last weekly completion: <state.json field>.
Query cursors and notice delivery: <state.json fields; advance only on success>.

## Incidents
Dated, three lines each: what users saw, cause, what now prevents it.
```
