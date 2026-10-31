# Git Workflow

## Before any change

```sh
git status              # what is already modified
git branch --show-current
git log --oneline -5
```

Read `git diff` before editing. If the working tree already contains changes you did not make, ask whether to keep or stash them. Never discard them.

## Branches

- Branch from the current branch unless told otherwise.
- Name: `feature/<short-slug>`, `fix/<short-slug>`, `chore/<short-slug>`.
- Slug in lowercase kebab-case, 3-6 words, describing the outcome.
- Do not commit directly to `main` or `master` unless the user says so.

## Commits

One logical change per commit. Split unrelated edits into separate commits so each can be reviewed and reverted on its own.

```
<type>: <imperative summary under 72 chars>

<why the change is needed>

<optional body: constraints, alternatives rejected, follow-ups>
```

Common types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`.

Rules:

- Subject in the imperative: "add retry logic", not "added" or "adds".
- Body explains why. The diff already shows what.
- Reference issue IDs when given: `fix: prevent duplicate webhook delivery (#412)`.
- No "wip", "fixes", "changes", or "update" as a subject.
- Never amend or rewrite history the user did not ask you to rewrite.

## Staging

```sh
git add path/to/file.ts path/to/other.ts
git diff --staged
```

Stage by path. Review the staged diff, then commit. Watch for:

- Debug leftovers: `console.log`, `print()`, `dbg!`, `TODO`, commented-out blocks.
- Secrets: keys, tokens, `.env`, `*.pem`, connection strings with passwords.
- Generated files and build output that do not belong in the repo.
- Unrelated changes swept in by a broad `add`.

## Pull requests

Prepare a PR only when asked. Include:

- **Title**: the same imperative summary used for the commit.
- **Body**: what changed, why, how it was verified, and what a reviewer should look at.
- **Scope**: list the touched areas so the reviewer knows where to look.

```sh
git push -u origin <branch>
gh pr create --title "<title>" --body "<body>"
gh pr create --title "<title>" --body-file <file>
```

Do not push or open a PR without an explicit request. If the remote requires a token or credential you do not have, report that instead of trying to work around it.

## Recovering from mistakes

- Wrong file staged: `git restore --staged <path>` (keeps the edit in the working tree).
- Wrong commit content, not pushed: `git reset --soft HEAD~1` to keep changes staged.
- Wrong commit content, pushed: `git revert <sha>` to add a revert commit. Never force-push shared history.
- Ask before any history rewrite, and never rewrite commits that were not yours.
