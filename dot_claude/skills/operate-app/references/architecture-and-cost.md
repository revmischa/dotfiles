# Architecture, cost and maintainability

A small app should cost close to nothing when idle, scale without a meeting, and
be understandable by someone who has never seen it. Choose the boring,
pay-per-use AWS service; add a moving part only when a measured problem needs it.

Prices change. Check current pricing before a decision that depends on one.
These are options for an AWS serverless app, not a mandate to replace a working
stack. Measure total cost, operational burden and feature requirements first.

## Defaults

| Need | Reach for | Avoid unless measured need |
| --- | --- | --- |
| Compute | Lambda on arm64, memory right-sized | always-on containers, EC2 |
| HTTP | CloudFront in front of a function URL or HTTP API | REST API Gateway features you do not use |
| Data | DynamoDB on-demand, single-table, TTL, point-in-time recovery | RDS or Aurora with a floor cost; OpenSearch |
| Files | S3 with lifecycle rules, presigned uploads straight from the browser | proxying uploads through Lambda |
| Async work | SQS with a DLQ; EventBridge for events; Step Functions for multi-step | hand-rolled retry loops, in-request long work |
| Schedules | EventBridge Scheduler to a Lambda | a server with cron |
| Config and flags | SSM Parameter Store (standard tier), AppConfig | a flags SaaS |
| Secrets | SSM SecureString; Secrets Manager only when rotation is needed | secrets in environment files or the repo |
| Email | SES | a mail SaaS for transactional volume |
| Observability | CloudWatch Logs with retention, EMF metrics, X-Ray, alarms to SNS | a paid APM subscription |
| Edge protection | CloudFront caching, in-app rate limits; WAF when bots cost real money | paying for WAF rules nobody tuned |
| ML inference | in the browser (ONNX, WebGPU) or a Lambda container | always-on endpoints |
| Networking | no VPC | NAT gateways (a fixed monthly cost each) |

A third-party service is an owner decision when it costs money or receives user
data; make the case with the AWS-native alternative priced beside it.

## Cost routine

- Tag app resources with app and stage within the approved infra scope;
  account-wide cost allocation settings need the appropriate authorization.
- A monthly budget with alerts and Cost Anomaly Detection (the amount is the
  owner's; propose baseline x 1.5).
- Weekly: cost by service against last week, and the cost of one core action.
  Cost Explorer's API charges per request; one or two calls a week, not a loop.
- The usual leaks: log groups with no retention, verbose logging on a hot path,
  S3 buckets with no lifecycle (old versions, incomplete multipart uploads),
  forgotten stages and preview stacks, over-provisioned Lambda memory, low CDN
  cache hit ratio, data transfer out, a third-party API called more often than
  results change.
- Remove a stage only within its approved lifecycle and after confirming it
  contains no user data or resources still in use. Other stacks are the owner's.

## Guards against a runaway bill

Reserved concurrency on expensive functions. Throttling at the edge. Maximum
payload sizes. Timeouts on every outbound call. `maxReceiveCount` and a DLQ on
every queue. No event loop where a function writes to the thing that triggers it.
Per-user and global quotas on anything that calls a paid API, plus a kill switch.
A budget action or alarm that reaches a human before the month ends.

## Reliability patterns

- Timeouts, then retries with backoff and jitter, then idempotency: anything that
  charges, sends or writes on a retry carries an idempotency key (Powertools
  Idempotency over DynamoDB).
- DLQs alarmed at depth above zero, with a documented redrive.
- Partial batch responses for queue and stream consumers.
- Degrade, do not fail: when an optional dependency is down, the page still loads
  and says what is unavailable.
- Backups that have been restored at least once. Point-in-time recovery on the
  table, versioning plus lifecycle on user-data buckets, stateful resources
  retained and protected in prod.
- Know the runtime and certificate dates: upgrade the Node runtime before the
  Lambda deprecation notice, not after.

## Code structure

- **Layers with one direction.** Domain logic is pure TypeScript with no
  framework or SDK imports; data access sits behind small functions; handlers and
  pages are thin. Lint rules enforce the direction.
- **One schema, three uses.** A zod schema gives the type, the runtime
  validation and the API contract. Types are never hand-copied across a boundary.
- **One way to do each thing.** One logger, one error type hierarchy, one HTTP
  client wrapper, one way to read config. A second way is a refactor waiting.
- **Small modules, named for what they do.** If a file needs a table of contents,
  split it.
- **Delete.** Dead code, unused exports, unused dependencies and flags for
  finished experiments are removed weekly. Hiding or removing something users
  have is the owner's call; removing code nobody can reach is yours.
- **Few dependencies.** Each one is an upgrade, an audit and a licence. Prefer
  the platform and twenty lines of your own.
- **Infra as code only.** No console changes; a weekly preview against prod shows
  drift.
- **Stages.** Dev mirrors prod in shape. Prod data never flows to dev.

## Performance budgets

Write the numbers in `docs/ops/metrics.md` and fail CI or alarm when they are
crossed: p95 for the main API calls, LCP on a mid-range phone for the top landing
pages, JavaScript per route, time to complete the core action cold. Measure
before optimising and report the before and after.

## Docs that stay true

- `README.md`: what it is, how to run, test and deploy. Checked by following it.
- `CLAUDE.md` (or the repo's agent guide): architecture in a page, commands, and
  a gotchas section. Record non-obvious, reusable constraints and correct inaccurate guidance
  in the PR that found it; elapsed debugging time alone is not documentation value.
- `docs/ops/`: the runbook, metrics, backlog, decisions and experiments.
- `docs/ops/decisions.md`: one dated paragraph per decision that someone will
  later want to reverse: what, why, what was rejected, how to undo it.
- Docs change in the same PR as the behaviour. The weekly sweep catches what slipped.
