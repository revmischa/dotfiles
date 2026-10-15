---
name: thermonuclear
description: "Run independent deep-review and code-quality passes in parallel, then synthesize their evidence-backed findings. Use for thermonuclear, double review, or combined bug/security and maintainability branch audits."
disable-model-invocation: true
---

# Thermonuclear Review

Run the two independent review passes in parallel, then synthesize their results. This complements the ordinary `code-review` skill: use it when an uncompromising, diff-scoped security/correctness and structural-quality pass is wanted.

## Workflow

1. Determine the review scope from the user request, PR, current branch, or relevant changed files.
2. Gather the diff and any file/context excerpts needed for reviewers to evaluate the change without guessing.
3. Dispatch two independent read-only subagents in the same message, in the background:
   - `thermonuclear-deep-review` covers bugs, breakages, security, developer-experience regressions, and feature-gate leaks.
   - `thermonuclear-code-quality` covers maintainability, structure, file-size growth, ad-hoc branching, abstractions, and codebase health.
   Each loads the skill of the same name as its brief.
4. Pass each subagent the same scoped diff/file context and ask it to return prioritized findings with file references and evidence.
5. After both finish, synthesize the results with findings first, deduplicated across reviewers. Weight overlapping findings more heavily, resolve disagreements with your own judgment, and keep summaries brief.

If individual background summaries are already visible to the user, do not restate them wholesale. Surface the unified verdict, the highest-signal findings, and any remaining uncertainty.
