# Growth and revenue

Applies in full when the app has a paid option. Without one, the same method
applies to the core action and retention, and "should this charge, and for what"
goes to the owner as a decision with evidence.

## Know the machine first

Write these in `docs/ops/metrics.md` before running anything:

- **The value moment:** the instant a user gets what they came for.
- **The funnel:** landed, reached the core feature, started, finished, saw the
  result, did a follow-up, saw the paid offer, started checkout, paid, came back.
  Each step is an event you can count.
- **Baseline:** four weeks of each step, by channel and device.
- **Unit economics:** what one core action costs to serve (compute, third-party
  calls), and what a paying user is worth so far.
- **Who pays and why,** from what paying users did before paying (aggregates).

If a step cannot be counted, instrument it; that is the first "experiment".

## Where ideas come from

The biggest funnel drop. The pages people land on and the queries that bring
them, against what the page actually offers. What users do right before leaving.
Errors and dead ends users hit. Feedback themes. The moments of highest intent
(a result just delivered, a limit just reached), which is where an offer belongs.
What comparable products charge for, read from their public pages.

## Experiment protocol

One file per experiment in `docs/ops/experiments/`, written before any code:

```
# <date> <short name>
Hypothesis:  because <evidence>, changing <x> for <who> will move <metric> from <a> to <b>
Primary metric:   one number
Guardrails:       error rate, latency, refunds/cancellations, core action completion
Design:           A/B using an approved first-party assignment mechanism, or before/after with matched weekdays
Exposure:         who sees it, logged by which event
Stop rule:        target sample and minimum duration; fixed maximum date, then inconclusive if undersampled
Decision rule:    ship if ..., kill if ..., otherwise ...
Result:           (filled at readout: counts, interval, decision, what was learned)
```

- **One change per surface at a time.** Two overlapping tests on the same page
  explain nothing.
- **Assignment** is sticky through an approved first-party mechanism. Hashing
  an identifier does not establish anonymity. Log experiment and variant counts,
  not persistent identifiers. Any new tracking or storage requires the applicable
  privacy decision. No third-party testing script without vendor approval.
- **Decide the stop rule first, then do not peek for a verdict.** Check guardrails
  daily; stop early only for harm.
- **Sample size reality.** To detect a change from rate p by an absolute delta d
  you need roughly `16 * p * (1 - p) / d^2` exposures per arm (5% to 6.5% gives about 3,400 per arm with this
  approximation). This is a rough planning rule, not a power calculation; define
  the significance level, power, allocation and analysis before a real test. A site with 30 visitors a day cannot A/B a button colour.
  At low traffic: test big differences, run before/after over matched weeks, use
  the count of people who took the action rather than a rate, and say plainly
  that the result is weak evidence.
- **Report intervals, not points.** "9 of 140 against 4 of 150" with a Wilson
  interval, not "+140%".
- **Validate on data the change was not tuned on.** A threshold, model or ranking
  fitted to a sample is tested on a held-out one before it ships.
- **Read out, decide, clean up.** Ship the winner and delete the loser's code.
  An inconclusive result does not prove equivalence: retain the established
  variant unless other evidence justifies a change. Record what was
  learned, so the same idea is not retested next quarter.
- **Fake doors are allowed when honest:** a button for a feature that does not
  exist yet may say "coming soon, tell us you want it". It never takes money or
  implies the feature exists.

Run an experiment only when there is a useful hypothesis, adequate measurement
and a feasible sample. Otherwise document what is unknown and improve the
measurement or product reliability. There is no experiment quota.

## Candidate improvements within approved product scope

- Where and when the paid offer appears: at the moment of need, after value is
  shown, not before.
- The pricing page: clarity, order, comparison, the questions people have.
- Checkout friction: steps, required fields, sign-in timing, error messages,
  mobile layout.
- Explain existing free and paid limits clearly. Changing limits, entitlements
  or access is an owner decision even when the price stays the same.
- Onboarding and time to value; speed (every second on the core action costs
  completions).
- Landing pages that answer the queries people actually arrive with.
- Retention: history, saved results, reasons to return that serve the user.
- Share and referral loops that come from the product's own output.
- Recovery: a clear path back after a failed payment or an error.

## Owner decisions (propose with numbers, do not start)

Price points, new plans, discounts, coupons, trials that change what is charged.
Any email, notification or message to users. Paid acquisition. Affiliates and
partnerships. Refunds. Tax settings. A new vendor.

Make the proposal specific: the evidence, the expected effect, the cost, the
risk, how it would be measured, and what you will do in the meantime.

## Payments hygiene (part of operating, not optional)

- Hosted checkout and the provider's portal; card data never touches the app.
- Webhooks: signature verified, idempotent, retried safely; entitlements derive
  from provider events, not from the redirect back.
- Daily reconciliation: a scoped read-only comparison of provider subscriptions
  and database entitlements in both directions, returning aggregate mismatch
  counts. Correcting billing or entitlements requires the applicable write
  authorization; do not fetch customer records into the agent session.
- The paid path runs in the provider's test mode in the smoke suite.
- Check that live mode is fully configured (portal enabled, products and prices
  present, webhook endpoint registered, keys from the same account and mode in
  every stage). A mismatch between a publishable and a secret key fails only at
  the moment someone tries to pay.
- Alarm on webhook failures and on a day with zero successful payments when
  there are normally some.
- Cancelling is as easy as subscribing and works.

## Lines that are not crossed

No fake urgency, countdowns or scarcity. No pre-ticked add-ons. No hidden renewal
terms; the recurring price and period are next to the button. No obstacle course
to cancel. No invented reviews, testimonials, logos, user counts or "as seen in".
No accuracy or performance claim without a measurement behind it that you can
show. No degrading the free product to manufacture pain; limits are stated up
front. No selling or sharing user data. Revenue earned by tricking users is a
liability with a delay, and it is not what the owner asked for.

## Search and acquisition

Real pages for real intents, fast, with accurate titles and descriptions,
canonical URLs, a sitemap that is current, structured data that matches the page.
Watch Search Console weekly. No doorway pages, generated filler, or keyword
stuffing; they get the site penalised. Report identifiable AI-assistant referrals separately when an explicit referrer
or campaign tag supports attribution. Leave missing referrers unattributed; a
landing-page pattern alone does not identify a source.

## Cost side

Revenue minus cost is the number. Gate every expensive call (rate limits, quotas,
sign-in, a kill switch), cache what repeats, and move work to the client or to
cheaper compute when quality holds. Report unit cost with revenue in the weekly
update.
