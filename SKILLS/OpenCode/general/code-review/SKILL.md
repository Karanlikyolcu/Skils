---
name: Code Review
description: Use when reviewing a diff, pull request, or patch - correctness and edge cases, security, API and data model changes, test quality, performance, error handling, and readability. Also covers writing review comments that are actionable and prioritised, giving an approval, requesting changes, and reviewing your own work before handing it over.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Code Review

A review has two outputs: better code, and shared understanding. A review that only blocks and never explains wastes the reviewer's time and teaches the author nothing.

## How to review

Work in this order. Stop at the first layer that has a blocking problem, but read the whole diff before you decide.

1. **Understand the intent.** Read the PR description, the linked issue, and the ticket. What is this supposed to do? If the intent is unclear, ask before reviewing the code.
2. **Check the scope.** Does the diff do what it claims, and only that? Unrelated refactors, renames, and reformatting make a review impossible and hide the real change.
3. **Correctness.** Does it work? Follow the logic against the stated requirements, including the edge cases.
4. **Contracts and boundaries.** Inputs validated, outputs shaped as expected, errors handled.
5. **Data and API changes.** Migration safe, backward compatible, indexes matching the access pattern.
6. **Security.** Authorization on every new path, injection, secrets, sensitive data handling.
7. **Tests.** Does a test exist for the new behavior, and would it fail without the change?
8. **Performance.** N+1 queries, unbounded loops, allocations in a hot path, a missing index.
9. **Readability.** Naming, structure, and whether the intent is clear to a reader.
10. **Operability.** Logs, metrics, and the failure path.

## What to look for, in detail

### Correctness

- The happy path, plus: empty input, null, zero, negative, boundary values, very large input, unicode.
- Error paths: does a failure leave partial state behind? Is the transaction rolled back?
- Off-by-one in loops, indices, ranges, and pagination.
- Inconsistent units: seconds vs milliseconds, bytes vs bits, local vs UTC.
- Time: timezone handling, DST boundaries, leap seconds, clock skew between services.
- Concurrency: two requests at once, a read-modify-write race, a re-entrant call.
- Ordering assumptions on a collection that is not guaranteed to be ordered.
- Idempotency: what happens if this runs twice? It will, eventually.

### Correctness in the diff itself

- Does the change match the stated intent? A correct implementation of the wrong thing is still wrong.
- Does it break a documented behaviour? Check the README, the API docs, and the tests.
- Are the tests updated along with the behaviour? A stale test that still passes is worse than no test.
- Is a removed guard actually unnecessary now, or was it covering a case that still exists?

### API and contracts

- Breaking changes: a removed field, a changed type, a tightened validation, a changed default, a changed error code's meaning.
- Nullability changes: is a field that was always present now optional?
- Error shape: does a new error case use the existing envelope?
- Defaults: does a new optional parameter silently change existing behaviour?
- Versioning: does this need a version bump or a deprecation path?

### Data model and migrations

- Is the migration reversible, or explicitly documented as one-way?
- Does it lock a large table? Does it have a lock timeout?
- Is it backward compatible with the currently deployed code? Deploy order matters.
- Are new columns indexed if they will be filtered on?
- Are constraints enforced at the database level, or only in the code?
- Does the migration handle the case where the data already violates the new constraint?

### Security

- Is there an authorization check on every new path, and is it correct? Check the object, not just the role.
- Is untrusted input validated with a schema at the boundary?
- Any string-concatenated SQL, shell command, or file path?
- Any output that reaches HTML without escaping?
- Any secret, token, or personal data that would end up in a log or a response?
- Are new dependencies needed, and are they audited?
- Does the new code widen an attack surface: a new endpoint, a new parameter, a new file path?

### Tests

- Is there a test for the new behaviour? A bug fix needs a regression test that fails without the fix.
- Does a test assert on behaviour, or on implementation details that will break on a harmless refactor?
- Are the edge cases covered, or only the happy path?
- Are the assertions meaningful? A test with no assertions passes trivially.
- Does the test actually exercise the changed code path, or does it mock away the thing being tested?
- Are the fixtures and mocks reset between tests?
- Is there a test that would catch the most likely regression from this change?

### Performance

- N+1 queries: a query inside a loop.
- Unbounded results: a list endpoint with no limit.
- A missing index for a new filter or join column.
- Work inside a loop that could be hoisted out.
- An allocation in a hot path.
- A synchronous call to a remote service on the request path, or inside a transaction.
- A cache with no invalidation strategy, or no TTL.

### Readability

- Does the code read like the code around it? Consistency with the codebase beats personal preference.
- Are the names accurate? A misleading name is a defect.
- Is the intent clear? A reader should not have to reconstruct the why.
- Are the comments explaining why, not what?
- Is anything dead, commented out, or a leftover debug statement?
- Is a magic number or a string literal that should be named and shared?

### Operability

- Is there a log line at the point of failure, with the identifiers needed to debug it?
- Does a failure produce a useful error message, or a bare exception?
- Is there a metric for a new failure mode?
- Can this be rolled back? Is the previous behaviour still reachable?

## Writing the comments

**Format**

Each comment has three parts:

```
[severity] What is wrong and why it matters.
[location] file:line
[fix] The concrete change.
```

Example:

> **[blocking]** This reads the whole `orders` table into memory and then filters in Python. With 2M rows this will OOM the worker, and it runs on every request.
> `src/api/orders.py:42`
> Push the filter into the query: `select_orders(status=..., limit=...)`. The `select_orders` helper already does this.

**Rules**

- **Separate blocking from non-blocking.** Mark each comment clearly, so the author knows what must change and what is optional. A review where everything is optional is not useful; a review where everything is blocking is exhausting.
- **Explain why, not only what.** "Use `select_orders` instead" is a command. "This loads every order and filters in Python, which will exhaust memory at production volume" is information the author can use next time.
- **One issue per comment.** A comment listing six problems gets one response and five bugs.
- **Give the fix when you can.** If you know how to fix it, say how. If it is genuinely the author's call, say what you are worried about and ask a question.
- **Distinguish a question from a defect.** "Is this safe if the list is empty?" is a question. "This crashes on an empty list" is a defect.
- **Be specific.** "This is inefficient" is not reviewable. Name the operation and the scale.
- **Do not rewrite the diff.** A review is not a pull request with comments on it. If the change needs a rewrite, say so and explain why.

**Tone**

- Assume good intent. The author probably had a reason you do not know yet.
- Attack the code, not the person. "This is wrong" not "you got this wrong".
- Praise specific good decisions when there are any. It tells the author what to keep doing.
- No nitpicks mixed in with real issues. If the only findings are formatting, say that plainly and approve.

## Verdicts

- **Approve** - no blocking issues. Optional suggestions are clearly marked as optional.
- **Approve with comments** - no blocking issues, but non-trivial suggestions.
- **Request changes** - at least one blocking issue. Say exactly what must change.
- **Do not approve, and do not request changes** - you need information. Ask the question and wait.

If you approve, approve. Do not leave a blocking issue in a review you approved; fix it or reclassify it.

## Reviewing your own work

Before handing work over, run the same checklist on your own diff. It catches most of what a reviewer would catch, and it is much cheaper than a round trip.

```sh
git diff main...HEAD
git diff --stat main...HEAD
```

Read the full diff as if you were the reviewer who has never seen the code. Then check:

- Does the diff do exactly what was asked?
- Any unrelated change to remove?
- Any debug code left in?
- Any secret in the diff?
- Does every new behaviour have a test?
- Do the tests actually fail without the change?
- Do the full test suite, lint, and typecheck pass?
- Is the error path handled and logged?
- Is there a migration, and is it reversible?

## Common mistakes

- Reviewing the diff line by line without understanding the intent, so a design problem is missed.
- Not running the code, so a broken test or a crash is not noticed.
- Commenting on style that the linter or formatter already handles.
- Marking everything blocking, so the author cannot tell what matters.
- Spending 40 minutes on one comment instead of reading the whole diff.
- Approving a diff that was never run.
- A large diff reviewed in one sitting at the end of the day. Review in the same session as the work, in chunks.
