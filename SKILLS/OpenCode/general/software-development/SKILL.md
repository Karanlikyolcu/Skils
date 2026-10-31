---
name: Software Development
description: Use for hands-on coding work in an existing codebase - exploring, implementing features, fixing bugs, refactoring, writing tests, and preparing commits or pull requests. Covers repo conventions, change scoping, verification, and review hygiene.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Software Development

Instructions for making correct, reviewable changes to an existing codebase.

## 1. Orient before editing

Never guess a codebase's structure, conventions, or toolchain.

1. Read the project's instruction files first: `AGENTS.md`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, and any `docs/` index.
2. Detect the stack from manifests and config, not from assumption:
   - `package.json`, `pnpm-workspace.yaml`, `bun.lock*`
   - `pyproject.toml`, `requirements*.txt`, `uv.lock`, `poetry.lock`
   - `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle*`, `Gemfile`
3. Find the real commands. Check `package.json` scripts, `Makefile`, `justfile`, `Taskfile.yml`, `tox.ini`, `noxfile.py`, CI workflows under `.github/workflows/` or `.gitlab-ci.yml`.
4. Match the surrounding code: naming, file layout, error handling, comment density, test style, import style, formatting.

## 2. Scope the change

- Change only what the task requires. Leave unrelated code alone, even when it looks wrong.
- Do not reformat, rename, or "improve" code outside the lines you must touch.
- Read a file completely before editing it when the change is structural.
- When a change touches more than ~3 files or crosses a module boundary, state the plan and get approval first.

## 3. Implement

- Follow the existing idiom rather than importing a different style. If the codebase has no convention for something, pick the simplest option and stay consistent.
- Handle the real cases, not only the happy path: empty input, missing keys, zero and negative values, partial failure, concurrent access.
- Prefer explicit error propagation over silent fallbacks. Never swallow an error without a reason.
- Keep comments for intent and invariants, not for restating the code.
- Do not add dependencies without asking first.
- Do not introduce TODO stubs, placeholder returns, or commented-out code to make a build pass.

## 4. Verify

Run the project's real checks, in this order, after each meaningful change:

1. Typecheck / lint / format
2. Unit tests
3. Integration or end-to-end tests if they exist and are affected

Use the exact commands from the project's tooling, not generic substitutes.

- Fix the cause, not the test. Changing an assertion to match broken behavior is not a fix.
- If a check fails for a reason unrelated to your change, report it instead of silently working around it.
- If you cannot run the checks, say so explicitly and state what remains unverified.

Read `references/verification.md` for the triage order when checks fail.

## 5. Git discipline

- Check `git status` and `git diff` before staging anything.
- Stage by path. Never `git add .` or `git add -A`.
- Do not commit, amend, rebase, reset, push, or open a PR unless the user asked for that specific action.
- Never rewrite or discard commits or working-tree changes that you did not create.
- Commit messages: one logical change per commit, imperative subject under ~72 characters, body explaining why rather than what.
- Never commit secrets, credentials, `.env` files, tokens, or generated build output. Check `git diff --staged` before every commit.

See `references/git-workflow.md` for branch naming, commit formats, and PR preparation.

## 6. Report

When you finish, state plainly:

- What changed and where (file paths).
- What you verified, with the commands you ran.
- What you did not verify and why.
- Any follow-up you deliberately left out of scope.

Do not claim success for work you did not complete. If part of the task is blocked, finish everything else and say clearly what is blocked and what the blocker needs.

## Supporting files

- `references/verification.md` - order to run checks, and how to triage failures.
- `references/git-workflow.md` - branches, commits, pull request preparation.
- `references/code-review.md` - self-review checklist before handing work back.
- `scripts/precheck.sh` - detect the project stack and print the available commands.
