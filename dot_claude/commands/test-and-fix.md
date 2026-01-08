---
description: "Run all quality checks and fix failures"
---

Run all quality checks and fix any failures. For each check:

1. Run the check and capture results
2. If failures exist, analyze them
3. Fix issues one at a time
4. Re-run the check to verify
5. Repeat until all checks pass

## Checks to Run

**Type checking**
- Tools: `pyright`, `basedpyright`, `mypy`, or `tsc`

**Linting**
- Tools: `ruff check`, `eslint`, or `clippy`

**Formatting**
- Tools: `ruff format --check`, `prettier --check`, or `cargo fmt --check`

**Tests**
- Tools: `pytest`, `cargo test`, `npm test`, or `go test`

## Detecting Project Tools

Look for configuration files to identify the project's tooling:
- `pyproject.toml` (Python)
- `package.json` (Node.js)
- `Cargo.toml` (Rust)
- `Makefile` or other build configs

If unclear, ask the user which tools to run.
