---
name: analyze
description: "Review changes with type-checker, bug-finder, code-simplifier and code-reviewer in parallel"
---

Review the changes in `$ARGUMENTS` (a PR, branch, or path). With no argument, use
the code I just wrote or modified on the current branch.

Read what changed, then run these four agents **in parallel** on it:

1. **type-checker** - type safety, `Any` leaks, missing annotations
2. **bug-finder** - subtle bugs, edge cases, failure modes
3. **code-simplifier** - unnecessary complexity, simplification opportunities
4. **code-reviewer** - project conventions, security, test coverage gaps

After all four complete, provide one unified summary, deduplicated, with severity
(blocking, important, suggestion):

- Critical issues that need immediate attention
- Type safety improvements to make
- Simplification opportunities
- Suggested fixes with code examples where helpful

Do not post anything anywhere without confirmation.
