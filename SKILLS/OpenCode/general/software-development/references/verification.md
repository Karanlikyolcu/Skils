# Verification

## Order of checks

Run the cheapest, most local check first. Stop and fix as soon as one fails.

| Order | Check | Common commands |
| ----- | ----- | ----- |
| 1 | Format | `prettier --write .`, `ruff format .`, `gofmt -w .`, `cargo fmt` |
| 2 | Lint | `eslint .`, `ruff check .`, `golangci-lint run`, `clippy` |
| 3 | Typecheck | `tsc --noEmit`, `mypy .`, `pyright`, `cargo check` |
| 4 | Unit tests | `vitest run`, `jest`, `pytest`, `go test ./...`, `cargo test` |
| 5 | Integration / e2e | `playwright test`, `cypress run`, `pytest -m integration` |
| 6 | Build | `pnpm build`, `npm run build`, `docker build .` |

Replace any row with the project's own command when one exists. A repo's `Makefile`, `package.json` scripts, or CI workflow is the source of truth.

## Triaging a failure

1. **Is it mine?** Read the error, then check whether the same failure exists on the untouched baseline:
   ```sh
   git stash
   <failing command>
   git stash pop
   ```
   If it fails on the baseline too, it is pre-existing. Report it, do not fix it silently.

2. **Which layer?** A failing typecheck after a lint fix usually means the lint fix changed behavior. Re-read the change.

3. **Test or code?** A failing test asserts a contract. Determine which side is wrong before editing either:
   - Contract changed on purpose: update the test and say so explicitly.
   - Contract unchanged: fix the code.

4. **Environment?** Missing dependency, wrong Node or Python version, unset env var, no database, no network. Fix the environment or report the requirement. Never work around a missing service by stubbing the integration in production code.

5. **Flaky?** Re-run in isolation, then in the full suite. Report suspected flakiness with the specific test name rather than re-running until it passes.

## What counts as verified

- Command run, exit code 0, on the current working tree.
- A check that was skipped is unverified, not passed.
- "Tests pass" without naming the command and the count of tests is not a verification statement.
