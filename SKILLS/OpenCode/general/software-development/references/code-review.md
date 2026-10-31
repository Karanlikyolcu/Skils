# Code Review Self-Check

Run through this list before handing work back to the user or a reviewer.

## Correctness

- The change does what was asked, and nothing else.
- Edge cases handled: empty, null/undefined, zero, negative, very large, unicode, boundaries.
- Error paths behave sensibly and do not leave partial state behind.
- No silent catch blocks, swallowed errors, or ignored return values.
- Concurrency: no shared mutable state without synchronization, no race on async work.
- Input validated at the boundary where untrusted data enters.

## Scope

- No unrelated files modified.
- No drive-by refactors, renames, or reformatting.
- No leftover debug code: `console.log`, `print()`, `dbg!`, `TODO`, `FIXME`, commented-out code.
- No dependency added without the user agreeing to it.
- No dead code left behind. Removed code is deleted, not commented out.

## Tests

- New behavior has a test. A bug fix has a regression test that fails without the fix.
- Tests assert on behavior, not on implementation details.
- Test names describe the scenario, not the function name.
- No test relies on execution order, wall-clock time, network, or machine-local paths.
- Fixtures and mocks reset between tests.

## Readability

- Names say what the code does; no single-letter names outside short scopes.
- Functions do one thing and stay short enough to read without scrolling.
- Comments explain intent and invariants, not the mechanics.
- The code reads like the code around it.

## Project conventions

- Formatter and linter run clean.
- Typechecker passes without `any`, `@ts-ignore`, or `eslint-disable` added to silence a new warning.
- Naming, directory layout, and error handling match the surrounding modules.
- Public API changes are reflected in types, docs, and changelog where the project keeps one.

## Security

- No secrets, tokens, or credentials in the diff or in logs.
- User input is escaped or parameterized; no string-built SQL or shell commands.
- File paths and URLs are not taken directly from user input without validation.
- Authorization checks present on every new endpoint or handler.

## Documentation

- Public behavior change: docs and examples updated.
- New configuration or environment variables documented in the project README.
- Non-obvious setup steps mentioned in the summary.

## Final pass

```sh
git diff
git status
```

Read the full diff once, top to bottom, as if you were the reviewer. If something would raise a question, fix it or call it out in the summary.
