# Observability

The test: with nobody having touched the app for a month, you can answer in under
a minute whether it is up, what broke, how many people it affected, and what it
cost. Anything you cannot answer is the next piece of work.

Define monitoring in infra code through the approved deployment path. Adapt to
the existing stack and verify installed APIs against official documentation.

## Order of work

1. Structured logs with request id and release on every backend line.
2. Frontend error capture.
3. Alarms on the handful of signals that mean users are hurt.
4. Business events for the funnel.
5. Custom metrics, tracing, a dashboard.
6. Cost and quota alerts.

## Backend: Powertools for AWS Lambda (TypeScript)

Use the installed Powertools Logger, Tracer and Metrics APIs with the handler
framework already in use. Centralize context injection, sanitized logging,
response-capture policy and metric flushing in one tested wrapper. Refer to the
[official Logger guide](https://docs.aws.amazon.com/powertools/typescript/latest/features/logger/)
and the matching installed version's middleware APIs; do not copy a generic
handler signature over the app's event/context types.

- Configure through environment set once in infra for all functions:
  `POWERTOOLS_SERVICE_NAME`, `POWERTOOLS_METRICS_NAMESPACE`, `POWERTOOLS_LOG_LEVEL=INFO`,
  `POWERTOOLS_LOGGER_SAMPLE_RATE=0.05` (a sample of requests logs at DEBUG),
  `POWERTOOLS_LOGGER_LOG_EVENT=false`, `POWERTOOLS_TRACER_CAPTURE_RESPONSE=false`,
  `POWERTOOLS_TRACER_CAPTURE_ERROR=false`. Exception metadata may contain user
  input even when response capture is off; see the
  [Tracer guidance](https://docs.aws.amazon.com/powertools/typescript/latest/features/tracer/).
  Add the release (git SHA) as a persistent log key.
- Enforce the wrapper: a test that imports every handler entry point and asserts
  it is wrapped, or a lint rule restricting `export const handler` to the wrapped
  form. Otherwise the tenth Lambda ships without it.
- More middleware in the same stack where it applies: input validation with the
  Powertools parser (zod), `@aws-lambda-powertools/idempotency` for anything that
  charges, sends or writes on retry, `@aws-lambda-powertools/batch` with partial
  batch responses for SQS and streams, a final error handler that maps typed
  errors to responses and counts everything else as `UnhandledError`.
- Wrap AWS SDK v3 clients with `tracer.captureAWSv3Client` and turn on active
  tracing for the functions. Annotate traces with the route and cold start. Leave
  X-Ray sampling at the default unless a problem needs more.

### Framework servers (Next.js on OpenNext, one big server function)

There is no per-route Lambda handler to wrap. Put the same three things where the
framework lets you:

- a tRPC (or route handler) middleware that times every procedure, logs one line
  per call with procedure name, outcome, duration and request id, and counts errors
  by class;
- the framework's server error hook (`instrumentation.ts` `onRequestError` in
  recent Next.js) so render errors reach the logs with a digest;
- the Powertools `Logger` and `Metrics` used directly, flushing metrics at the end
  of the request. Check that buffered metrics are actually published in a
  long-lived handler; an unflushed buffer is silently lost.

## Logging rules

- JSON only, one event per line, through the logger. `console.log` is a lint error.
- Every line: level, message, service, release, request id, cold start, route or
  procedure. Errors carry a stable allowlisted `code` and sanitized stack locations.
  Raw exception messages and stacks can embed URLs, tokens or user input.
- Log decisions and outcomes, not payloads. Never log request or response bodies,
  headers, tokens, emails, names, IPs, or user content. Use an explicit allowlist serializer and sanitization layer; do not assume
  the logger redacts arbitrary strings. Test both log output and emitted trace segments with synthetic sensitive
  values in nested fields, exception messages, stacks and URLs. Audit tracing
  middleware and SDK instrumentation too; sanitizing the logger alone is insufficient.
- Expected conditions (validation failure, 404, rate limited) are `WARN` or `INFO`
  with a code. `ERROR` means someone should look. If the daily error query is full
  of non-errors, fix the levels; a noisy error log hides the real one.
- Set a retention on every log group (30 to 90 days). "Never expire" is a slow
  cost leak. Bulk, rarely read logs can use the infrequent-access log class.

## Business events

One typed function, `track(event, props)`, with a closed union of event names and
props restricted by type to enums, booleans, numbers and coarse buckets. Validate the same schema at runtime, since types do not constrain browser
requests. Reject unknown fields and unbounded labels; a static type alone cannot
keep personal data out. It writes a structured log
line (queryable with Logs Insights at any cardinality) and, for the few events
that deserve a graph or an alarm, an EMF metric.

Instrument the funnel end to end before anything else: landed, saw the core
feature, started the core action, finished it, saw the result, the follow-up
actions (share, save, sign up), paywall seen, checkout started, paid, came back.
For each failure the user can see, an event with a reason code.

## Custom metrics

- Emit with EMF through Powertools `Metrics` (a log line, no API call on the hot
  path). Namespace per app, `service` and `stage` as dimensions.
- CloudWatch bills per unique metric and dimension combination. Dimensions must be
  low-cardinality: never user id, path with ids, or free text. High-cardinality
  questions are answered from logs.
- Worth a metric: core actions completed and failed by reason, third-party call
  count, latency and failures, queue age, payments succeeded and failed, sign-ups,
  anything you would alarm on.

## Frontend

- Capture `window.onerror`, `unhandledrejection`, the React error boundary and the
  framework's global error page, failed API calls (status and procedure, not
  payload), and web vitals (LCP, INP, CLS).
- Send with `navigator.sendBeacon` to a first-party endpoint that validates size
  and shape, rate limits per client, and logs only validated error codes, sanitized frame locations, an allowlisted
  route pattern, release, browser family and viewport bucket. Treat every browser
  field as untrusted; discard raw messages, query strings, user ids and payloads.
  Add a global ingestion cap as well as per-client limits.
- Sample vitals; deduplicate errors per page load and cap error ingestion.
  Count dropped events so a flood cannot silently distort the reported rate.
- Keep source maps out of public serving; store them as a build artifact keyed by
  release so stacks can be symbolicated offline.
- Investigate noisy signatures before filtering. Extension-like errors and
  `ResizeObserver` failures can also reveal app defects. Record the scope, reason,
  expiry and volume threshold for every exclusion; preserve aggregate counts.
- CloudWatch RUM is the managed alternative, priced per event; the first-party
  endpoint is usually enough for a small app.

## Health and release

- `/api/health`: cheap, returns the release and checks the dependencies that
  matter (table reachable, required config present). The smoke suite and the
  uptime check call it.
- The release id is in every log line, in the health response and in a `<meta>`
  tag, so "which version is serving this error" is never a question.

## Alarms

Few, actionable, each with a runbook line. All routed to one SNS topic that reaches
the alert channel.

| Signal | Alarm when |
| --- | --- |
| CDN 5xx rate | above 1 to 2% for 5 minutes |
| Lambda errors per function | error rate above baseline for 5 minutes (use rate, not a count of 1) |
| Lambda throttles, timeouts | any sustained; duration p95 above 80% of the timeout |
| Queue and stream health | DLQ depth above 0; oldest message age climbing |
| DynamoDB | throttled requests, system errors |
| Payments | webhook failures; zero successful payments over a period that normally has some |
| Core action | success rate below baseline; zero completions over a period that normally has some |
| Uptime | scheduled smoke or health check failing twice in a row |
| Email | SES bounce or complaint rate near the sending limits |
| Cost | budget at 50, 80, 100% of the monthly amount; Cost Anomaly Detection |
| Quotas and expiry | concurrent executions near the account limit; certificate days to expiry; runtime deprecation dates |

Set missing-data handling deliberately ("zero traffic" must not page at night for
a low-traffic app; "zero completions for six daytime hours" should). Use composite
alarms so one outage is one alert. An alarm that fired and needed no action gets
fixed or deleted the same day.

## Uptime from outside

Run the smoke suite against prod on a schedule from CI (GitHub Actions cron is
free for public repos and cheap otherwise) and alert on failure. That covers
"the page renders and the core action works", which a ping does not. Add a
Route 53 health check or CloudWatch Synthetics canary only if minute-level
detection is worth its monthly cost.

## Dashboard

One CloudWatch dashboard in infra code: traffic, error rate, p95, cold starts,
core action funnel, payments, third-party spend, month-to-date cost. It exists so
the owner can look once without asking; you work from queries.

## Query recipes (Logs Insights)

These templates assume the sanitized schema above; validate them against the
app's log format and a known synthetic event before relying on their results.
Never run raw-message grouping over legacy logs that may contain personal data.
Use explicit account, region, log groups and bounded UTC start/end times. Poll
until the query succeeds; timeout, partial or failed queries are unavailable,
not zero errors. See the [official aggregation syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax-Stats.html).

```text
# Sanitized error signatures, no raw message projection
filter level = "ERROR" and ispresent(code)
| stats count(*) as n, min(@timestamp) as first, max(@timestamp) as last by code, route, release
| sort n desc | limit 50

# Counts and latency grouped by outcome; compute error rate from these counts
filter ispresent(procedure) and ispresent(duration_ms)
| stats count(*) as n, pct(duration_ms, 50) as p50, pct(duration_ms, 95) as p95 by procedure, outcome
| sort p95 desc

# REPORT records in the Lambda text-log schema; count present init durations
filter @type = "REPORT"
| stats count(*) as invocations, count(@initDuration) as cold, pct(@duration, 95) as p95, max(@maxMemoryUsed / 1000000) as max_mb by @log
```

The error-code query excludes uncoded platform failures; also inspect Lambda's
error/throttle metrics and a tested sanitized query for runtime failures and
timeouts. Structured platform log formats need their own field mapping. Limited
signature lists are not total error counts; compute totals separately.

Wrap the repo's own version of these in a script (`scripts/ops/errors.sh '<window>'`)
and name it in the runbook, so every run asks the same question the same way.

## Known noise

Internet background radiation (probes for `.env`, source maps, stale server-action
ids, malformed form posts, bot user agents) will appear as errors. For each
signature: establish why it is harmless under defined conditions, record the pattern, reason,
review expiry, expected volume and date in the runbook's noise list, and where cheap remove it at the source
(return 404 early, a WAF or CDN rule, a lower log level). Review exclusions monthly and whenever volume, release or impact changes;
noise is not a permanent exemption.

## Telemetry privacy

Aggregates only, everywhere. No emails, names, user ids, IPs, content hashes or
user content in events, metrics, dashboards, reports or PRs. Coarse geography
only, from the CDN's own headers, never by sending IPs to a third party. If a new
signal changes what the privacy page says is collected, that text is the owner's
decision: flag it before shipping.
