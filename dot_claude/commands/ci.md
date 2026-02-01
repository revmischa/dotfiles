# CI Status Check and Fix

Check CI status for a GitHub PR and fix any failing checks until everything is green.

## Usage

Provide a PR URL or number as the argument: `/ci 719` or `/ci https://github.com/METR/inspect-action/pull/719`

## Instructions

1. **Get PR details and CI status**
   - Parse the argument to extract PR number (and optionally repo from URL)
   - If no repo specified, use the current repo from git remote
   - Run: `gh pr view <PR> --repo <REPO> --json title,headRefName,statusCheckRollup`
   - Run: `gh pr checks <PR> --repo <REPO>` to see current check status

2. **Identify failing checks**
   - Look for checks with `fail` or `failure` status
   - For each failing check, get the logs: `gh run view <RUN_ID> --repo <REPO> --log-failed`

3. **Diagnose and fix issues**
   Common CI failures and fixes:
   - **yarn.lock out of sync**: Run `yarn install` in the frontend directory, commit the updated lockfile
   - **Lint errors**: Run `ruff check . --fix` and `ruff format .`, commit fixes
   - **Type errors**: Run `basedpyright .`, fix type issues
   - **Test failures**: Run the failing tests locally, fix the code or tests
   - **Missing dependencies**: Add to `pyproject.toml` or `package.json`

4. **Commit and push fixes**
   - Make targeted commits for each fix
   - Push to the PR branch

5. **Monitor CI until green**
   - After pushing, poll `gh pr checks` every 30-60 seconds
   - If new failures appear, diagnose and fix them
   - Continue until ALL checks show `pass`

6. **Report completion**
   - List all checks and their final status
   - Summarize what was fixed
   - Confirm the PR is ready for review/merge

## Argument

$ARGUMENTS
