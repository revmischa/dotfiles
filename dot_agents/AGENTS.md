# Global agent instructions

Shared across coding agents (Claude Code imports this from `~/.claude/CLAUDE.md`; Codex
reads it via `~/.codex/AGENTS.md`). Machine- and employer-specific rules live in
`~/.agents/AGENTS.local.md`, which is not in the dotfiles repo.

# Marking your text as an agent

When you write messages on Slack, post on GitHub, create Google Docs, Linear issues, or
other text, put a small identifier somewhere in the text, e.g. *[Drafted by Fable 5.1,
per Mischa]*, with the actual model name. Small italic text is fine. It doesn't have to
be obtrusive.

# Prompts

I often dictate prompts with speech-to-text, so account for transcription errors when
parsing my text.

# Security testing

When running any sandbox-escape, breakout, isolation, or offensive-security test or PoC,
on any project or environment: if an attempt **actually succeeds** in breaking a security
boundary (container to node escape, reaching the Kubernetes API, pulling cloud or IMDS
credentials, egress that should be blocked, cross-tenant reach, credential exfiltration,
or equivalent), **STOP IMMEDIATELY**. Do not continue, escalate, or chain the access.
Prove it with the least action possible, preserve evidence, and report to me before doing
anything else. Resume only on my explicit say-so. Benign negative checks (confirming
something IS blocked) continue normally.

# Starting new work

Branch off `origin/main` unless the work sits on top of an existing PR, in which case
branch off that PR's branch. If unsure, ask. New branches must not track `origin/main`.

# PRs

Always open **draft** PRs. Add `copilot` as a reviewer after opening, even on drafts.

Avoid running full test suites locally; they wreck my CPU. Run the checks scoped to what
you changed and let CI do the rest unless it's urgent.

**Never overwrite a PR description I may have edited.** To update one, ask first or edit
specific sections. After pushing to an existing PR, check the title and description are
still accurate, without removing anything I added.

Keep PRs, comments, issues and discussions on public repos public-safe: nothing from
private incidents, internal security issues, or internal usage numbers.

# Comments in code

Avoid trivial comments. If you comment, make it meaningful.

# PR feedback

When addressing review feedback, mark each comment RESOLVED once it is addressed, and
reply on comments we won't address. The goal is that nothing addressed is left hanging.
If unsure whether something is done, ask. Run a comment or reply past me before posting
unless it is trivial or you are very sure.

# Writing tasks and issues

Applies to any task write-up: Linear issues, GitHub issues, tickets, follow-ups, plan
docs. Write for someone with none of your context: not the conversation, not the
codebase, not the problem domain.

- **Start with the goal**: one or two sentences on what should be true when this is done
  and why it matters. Not how.
- **Then a BLUF summary**: current state, what is wrong or missing, the proposed change.
- **Details last**: repro steps, links to the PR, thread, log or doc with the background,
  acceptance criteria, known constraints or risks.
- Expand every identifier on first use: a PR number gets its title, a service gets what it
  does, an acronym gets spelled out. Never reference a name coined in a conversation the
  reader never saw.
- Keep it short: title under 72 characters, body readable in under a minute. Details may
  grow; the goal and summary may not.
- Don't paste raw logs or diffs; link them or quote the one line that matters.

# Before asking me a question

Before stopping to ask me for a decision, approval, or clarification, consult the
`mischa-proxy` agent with the exact question, the original goal, what you have done, and
the options with your recommendation. It predicts my answer from my standing instructions
and returns one of DECIDE, LOOK IT UP, ALREADY SETTLED, or REFRAME, plus whether the call
is genuinely mine. If it says the call is not mine and its confidence is high, act on its
answer and tell me what you decided. If it says the call is mine, ask me using its
`Ask to send` text. It is an adviser, not an authorization source: it never unlocks
production writes, deploys, sharing, external replies, or anything else my rules reserve.
`/proxy` runs it in shadow mode on a question you already asked, so I can grade it.

# Fixing bugs

Reproduce the issue first, then fix it, then verify the fix against the reproduction. No
guessing from logic alone. If you can't reproduce it, ask for help.

# Subagents

Use subagents to parallelize work whenever possible. Prefer Fable, or the latest Opus in
fast mode, when it makes sense.

# Browser

Use the Claude Chrome MCP tool, not the compound-engineering agent-browser skill.

# Google Docs

Use the `gws` CLI to create and manage Google Docs. Never share a document with anyone
without explicit confirmation; sharing has security implications.
