---
name: unblock
description: I haven't read the scroll. Walk me through what you need from me, one decision at a time, with enough context to decide cold, then continue.
disable-model-invocation: true
---

# Unblock

I jump between sessions and have not read your output. I do not know what you are
asking, why, or what the identifiers mean. I want the work to keep moving toward the
goal. Get me there with the least reading.

## 0. Thin the list first

Collect every open decision, question, approval, or action you are waiting on me for.
For each one, consult the `mischa-proxy` agent with the exact question, the goal, what
you did, and the options with your recommendation.

- Proxy says the call is not mine with high confidence: decide it, note it in the
  recap in §3, and do not ask.
- Proxy says LOOK IT UP: go look it up now; it is not a question anymore.
- Proxy says ALREADY SETTLED: apply what was settled.
- Only what survives is a question for me. Drop anything a later answer would make moot.

If nothing survives, skip to §3 and keep working.

## 1. Orient me in three lines

Before the first question: the overarching goal in one sentence, where the work stands
in one sentence, and how many decisions follow. Nothing else.

## 2. One decision at a time

Ask with the harness's question tool (`AskUserQuestion` in Claude Code) if it has one.
Otherwise the question is the last thing in the message and you stop. **One question
per turn, never a batch.** Wait for the answer before the next one.

Each question is self-contained, written for someone with no context:

- **What this is.** Expand every identifier the first time: a PR number gets its
  title and what it changes, a file gets what it is for, a service gets what it does,
  a name you coined gets its actual content. Never "approach B" or "the earlier fix".
- **What happened and why it is blocked.** Two or three sentences. Facts, not the
  investigation.
- **What it blocks.** Which part of the goal waits on this.
- **The options**, two to four, each with its real trade-off in a sentence. Your
  recommendation first, marked, with the reason in one line. If an option is
  irreversible, outward-facing, or touches production, say so in the option itself.
- **What happens after I answer.** One line: what you will do with it.

Ten lines of context is the budget. If it needs more, the question is not ready; go
narrow it first. Do not re-explain concepts I use myself. Do not describe your
reasoning or the path you took.

Act on each answer before asking the next question when the answer unblocks
independent work or changes what the next question should be. Otherwise collect and
continue after the last one.

Something that needs my hands rather than my decision (a merge, a prd write, a login,
a share) is not a question. Give me the exact command or click, and say what you will
do once it is done.

## 3. Continue

After the last answer: a recap of at most one line per decision (yours and the ones I
made, labelled), then resume the work. The recap is the last thing I should need to
read until the next real blocker.

Related: `/re-ask` restates every open question at the end of one message when I
missed it; `/clarify` expands a term I could not decode; `/up` is status only. This
command is for when the status is "waiting on you" and I want it to stop being that.
