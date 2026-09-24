---
name: centaur-review
description: "Use when reviewing someone else's PR together — the user narrates their review out loud and wants observations tracked, located in the diff, challenged, and posted as inline GitHub review comments."
args: "<pr_url_or_number>"
---

# Centaur Review

The user leads the review by narrating as they read. Track their observations, find the
exact diff locations, challenge weak suggestions after they finish, and compose a
friendly review together. Do not replace their judgment with unsolicited analysis.

## Set up the review

Require a PR URL or number. Fetch its metadata, changed files, diff, linked issues,
and existing reviews, line comments, and conversation comments:

```bash
gh pr view <pr> --json number,title,body,url,headRefName,baseRefName,headRefOid,files
gh pr diff <pr>
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
gh api repos/$REPO/pulls/<number>/reviews
gh api repos/$REPO/pulls/<number>/comments
gh pr view <pr> --comments
```

For a re-review, summarize outstanding requests, unanswered questions, unresolved
threads, changes since the user's last review, and material concerns from other reviewers.

Launch these agents in parallel (background) and hold their results until consolidation:

- **bug-finder** — significant correctness, security, concurrency, and edge-case defects.
- **code-simplifier** — consequential unnecessary complexity or avoidable abstraction.
- **code-architect** — structural implications, pattern drift, and cross-module effects.
- **code-reviewer** — compare the diff with linked issue requirements; identify omissions,
  scope creep, and material deviations.

## Narrated review

Keep a private tracker: `# | file:start_line-end_line | severity | observation`.
Resolve locations from explicit references or the diff; if a quote or concept is
ambiguous, ask which changed file or line the user means. Never guess a location.
The user may be dictating, so read through transcription errors when matching quotes.

Briefly acknowledge each observation without interrupting flow. On request, show the
tracker, show analysis, or drop the last item. Interpret severity words as follows:

| Label | Signals |
| --- | --- |
| BLOCKING | blocking, must fix, cannot merge |
| IMPORTANT | important, should fix, concern |
| SUGGESTION | suggestion, could, maybe, idea |
| QUESTION | question, wondering, why |
| NITPICK | nitpick, minor, tiny |

Use actual new-file line numbers for additions and old-file lines for deletions.

## Consolidate and write

When the user says they are done, verify every tracked location. Ask the
**code-quality:red-teamer** agent to challenge each comment—not to review the PR—checking
whether it is correct, has missing context, or would improve the code. Gather the four
background results, discarding "Nothing to add," then show the user their comments, the
challenges, and candidate findings. They decide what remains.

Write each retained inline comment with a clear observation, a concrete question or
change when appropriate, and a friendly, direct tone. Clarity and actionability come
before softening; do not use emojis as a substitute for precision. Example:

```markdown
**Suggestion:** Could we return early when `items` is empty? The caller can supply
an empty list, so indexing `items[0]` would raise here. Let me know if I missed an
invariant.
```

Write a concise overall summary after the inline comments and end it with the
attribution marker, e.g. `*[Drafted by Fable 5.1, per Mischa]*`. Keep everything
public-safe: no internal incidents, security details, or usage numbers. Ask for explicit
approval before posting.

## Post inline review comments

Post to the **reviews** endpoint (not `/pulls/{number}/comments`) with a JSON body, so
newlines and quoting in comments survive intact:

```bash
COMMIT_SHA=$(gh pr view <pr> --json headRefOid -q '.headRefOid')
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

gh api repos/$REPO/pulls/<number>/reviews --method POST --input - <<JSON
{
  "body": "## Review Summary\n\n<concise assessment>\n\n*[Drafted by Fable 5.1, per Mischa]*",
  "event": "COMMENT",
  "commit_id": "$COMMIT_SHA",
  "comments": [
    {"path": "src/example.py", "line": 42,
     "body": "**Suggestion:** Could we handle the empty case here?"},
    {"path": "src/other.py", "line": 89,
     "body": "**Question:** What invariant makes this safe?"}
  ]
}
JSON
```

Each comment needs `path`, `line`, and `body`; `path` must match the diff and `line`
must exist in the new file (add `"side": "LEFT"` for deleted lines). Do not silently fall
back to a top-level PR comment: the purpose is line-level feedback.

| Error | Cause and correction |
| --- | --- |
| `"line" is not a permitted key` | Wrong endpoint. Use `/pulls/{number}/reviews`. |
| HTTP 422 | A `path` is not in the diff or a `line` is not in the diff hunk for that file. |

Confirm the resulting review URL after GitHub accepts the request.
