# Quality gates

Automated gates complement the repository's review and approval requirements.
Adapt them to the existing stack. A change should get past, in order: the type checker, the linter, tests, a production build, a browser
walking the built app, a deploy to dev, the same browser against dev, a deploy to
prod, the same browser against prod, and alarms. Record what each layer actually covers; passing
checks does not establish approval or eliminate risk.

Tighten by ratchet: turn on one rule or flag, fix or baseline what it finds, lock
it in CI so the count can only go down. Never a big-bang "strict mode" PR.

## Audit table (bootstrap and quarterly)

| Gate | Pass means |
| --- | --- |
| Types | `strict` plus the flags below, zero errors, in every package |
| Lint | type-aware strict preset, `--max-warnings 0`, no unexplained disables |
| Dead code and deps | unused files, exports and dependencies fail CI |
| Tests | unit and integration run in CI; every fixed bug has a test |
| Build | the production build runs in CI on every PR |
| Smoke | a browser loads every public page and walks the critical paths of the built app |
| Secrets and supply chain | secret scan, audit, licence allowlist, frozen lockfile, pinned actions |
| Infra diff | infra changes show a preview on the PR; stateful replacements fail |
| Merge rules | PR required, checks required, no force-push, on main and the prod branch |
| Deploy | dev automatically from main; prod by an explicit promotion; both followed by smoke |
| Rollback | one documented command or revert path, tried at least once |
| Watch | error rate read 15 minutes after each prod deploy |

## TypeScript

`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
`noImplicitOverride`, `noFallthroughCasesInSwitch`, `noImplicitReturns`,
`verbatimModuleSyntax`, `isolatedModules`. One base `tsconfig` every package
extends. `tsc --noEmit` over the whole workspace in CI.

- No `any`: `no-explicit-any` and the `no-unsafe-*` family as errors. `unknown`
  at boundaries, narrowed by a schema.
- Every boundary is parsed, not cast: environment variables at boot, request
  input, webhook bodies, third-party API responses, rows read from the database.
  One zod schema is the source for the type and the validation.
- `@ts-expect-error` with a reason, never `@ts-ignore`. No non-null `!` on
  anything that came from outside.
- Exhaustive switches over unions (`switch-exhaustiveness-check`), branded types
  for ids that must not be mixed, `satisfies` for config objects.

## ESLint

typescript-eslint `strictTypeChecked` and `stylisticTypeChecked` as the base, then:

- promises: `no-floating-promises`, `no-misused-promises`, `await-thenable`,
  `only-throw-error`, `prefer-promise-reject-errors`
- imports: no cycles, no unresolved, `consistent-type-imports`, and
  `no-restricted-imports` rules that encode the architecture (domain code cannot
  import the web framework or the AWS SDK; UI cannot import database code)
- React: hooks rules, the React Compiler rules, `jsx-a11y`
- hygiene: `no-console` (use the logger), `eqeqeq`, `no-param-reassign`,
  complexity and max-lines as warnings turned into errors by `--max-warnings 0`
- disables: require a description on every `eslint-disable`, forbid file-wide
  unlimited disables, report unused disables
- when a production bug comes from a pattern, write the rule that bans the
  pattern (a `no-restricted-syntax` selector is often enough) in the same PR

A legacy codebase gets the strict config plus a recorded baseline of existing
violations (ESLint's bulk suppressions, or a per-rule count checked in CI), so new
code is held to the standard today and the baseline shrinks over time.

## Other static checks

`prettier --check`; `knip` for unused files, exports and dependencies;
`actionlint` on workflows; `gitleaks` (or the host's secret scanning) on the diff;
`pnpm audit --prod` failing on high and critical; a licence allowlist check;
`pnpm install --frozen-lockfile`; `packageManager` and `engines` pinned.

## Tests

- Unit tests beside the source; pure domain logic carries most of the weight.
- Integration tests against a local DynamoDB (or the stack's local equivalent),
  not mocks of the database client.
- Contract tests where the outside world calls in: webhook signature and replay
  handling, auth callbacks.
- Authorization tests for every data access: user A cannot read, change or delete
  user B's things. These are the tests that prevent the incident you cannot undo.
- Reproduce every bug before fixing it and rerun that reproduction afterward.
  Add a regression test when it can detect recurrence.
- No network in unit tests. Investigate flaky tests; do not rerun until green
  or silently remove a required check. A quarantine needs the repo's approved
  process and equivalent coverage for any release-critical behavior.
- Coverage as a ratchet on changed files, not a global target to game.

## Build and browser smoke

- CI runs the same production build that deploys.
- Playwright against that build: every public page and doc; fail on unexpected HTTP errors, uncaught exceptions, console
  errors, hydration errors and visible error text. Negative tests explicitly
  assert their expected failures. One place lists the pages; adding a page without adding it there fails a
  test.
- The critical paths, end to end: the core action with a fixture, sign-up and
  sign-in with a throwaway user against a local database, the paid path in the
  payment provider's test mode.
- Budgets that fail the build: bundle size per route, and an accessibility scan
  (axe) on the key pages.
- Parameterize the base URL and stage. Production runs only an explicitly
  read-only subset. Local/dev tests may write synthetic fixtures and exercise
  test-mode payments within approved scope, with owned fixture cleanup. Guard
  mutating tests against production URLs and live payment credentials.

## CI shape

```
pull_request:  static (tsc, lint, format, knip, audit, secrets, actionlint)
               test
               build -> smoke (against the built app)
               infra preview (when infra changed)
push to main:  all of the above -> deploy dev -> smoke dev
promotion:     select verified release -> deploy prod -> smoke prod -> tag release
schedule:      smoke prod every 30 to 60 minutes -> alert on failure
               weekly: audit, dependency updates, infra drift check
```

- Deploy jobs share a concurrency group with `cancel-in-progress: false`; PR jobs
  cancel superseded runs.
- AWS access through GitHub OIDC and a role scoped to the app's stack. No
  long-lived keys in secrets.
- Minimal `permissions:` per job; third-party actions pinned by commit SHA.
- Dependency updates use grouped draft PRs where required. Read compatibility
  notes and verify the changes; merge only with the applicable authorization.
- Path filters and required checks do not mix: a required check that never runs
  blocks the PR forever. Prefer always running and exiting early.
- Keep CI under about ten minutes. Slow gates get bypassed in spirit; cache,
  split and parallelise instead of dropping checks.

## Merge and promotion rules

Branch protection on main and on the prod branch: PRs only, required checks,
linear history, no force-push, no deletion, applied to admins. This is a repo
setting, so it is the owner's click: request it once in the bootstrap report with
the exact settings, and until then behave as if it were on.

Follow the owner's merge authorization and required reviews. Never merge while
a deploy from main is still running. Promote the exact artifact or pinned revision
verified on dev, including all changes since the previous production release. If
stage-specific configuration requires rebuilding, verify that build before promotion.

## Local hooks

Pre-commit: format and lint staged files. Pre-push: type check and the tests for
what changed. Hooks are a convenience for fast feedback; CI is the gate. Do not
skip hooks, and do not rely on them.

## Deploy safety

- **Dev first, always.** Verify the change on dev through the real user path
  before promoting.
- **Post-deploy smoke** on both stages, red on failure and visible in the daily
  health read.
- **Rollback** is a known, authorized path to a retained release or tested
  revert. Record commands, permissions and compatible data/schema versions in
  the runbook. Verify in dev within deploy authorization; do not assume an old
  binary can read data written by the current release.
- **Gradual traffic shifting** (Lambda aliases with canary or linear deployment
  and alarm-triggered rollback) where the framework exposes it and the traffic
  justifies it.
- **Data changes** are expand, migrate, contract: every deploy works with the
  schema one version back. Stateful resources are retained and protected in prod;
  a preview that replaces a table, bucket or user pool fails CI.
- **Feature flags** (SSM Parameter Store or AppConfig) for risky changes, default
  off, and a kill switch for every paid third-party call.
- **Config** is validated at boot by schema; a missing variable fails the build
  or the health check, not the first user request. Know the platform limits
  (Lambda's 4 KB environment cap) before adding variables.
- **Never unlock** a deploy lock you did not take. Someone else is deploying, or a
  deploy died and needs a human to decide.

## After every prod deploy

Smoke result, then 15 minutes later: error rate against the previous hour, p95
latency, any alarm. Record the release id, query window and result. A regression freezes
promotion; use the authorized, compatible rollback path or escalate the action.
