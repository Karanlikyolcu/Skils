# Review Checklist

Use this in order. Stop at the first layer with a blocking problem, but read the whole diff before deciding.

## Layer 0: Intent and scope

- [ ] What is the change supposed to do? Is the intent stated and does the diff match it?
- [ ] Is the scope appropriate? Any unrelated refactor, rename, or reformat to split out?
- [ ] Is this a complete change, or is part of it left for a follow-up that nobody has agreed to?
- [ ] Does it break a documented behaviour? Check the README, the API docs, and the existing tests.
- [ ] Are the tests updated alongside the behaviour? A stale test that still passes is worse than no test.
- [ ] Is a removed guard actually unnecessary now?

## Layer 1: Correctness

- [ ] The happy path
- [ ] Empty input, null/undefined, zero, negative
- [ ] Boundary values: max, min, off-by-one
- [ ] Very large input, unicode
- [ ] Error paths: does a failure leave partial state? Is the transaction rolled back?
- [ ] Concurrency: two callers at once, a read-modify-write race, a re-entrant call
- [ ] Ordering assumptions on an unordered collection
- [ ] Idempotency: what happens if this runs twice?
- [ ] Units: seconds vs milliseconds, bytes vs bits
- [ ] Time: timezone, DST boundary, clock skew, monotonic vs wall clock
- [ ] Resource cleanup on every path, including exceptions

## Layer 2: Contracts and boundaries

- [ ] Input validated with a schema at the boundary
- [ ] Output shaped as the caller expects
- [ ] Nullability of every field in the contract
- [ ] New error cases use the existing error envelope
- [ ] Default values do not silently change existing behaviour
- [ ] Breaking changes: removed field, changed type, tightened validation, changed default, changed error meaning
- [ ] Versioning or a deprecation path for a breaking change

## Layer 3: Data model and migrations

- [ ] The migration is reversible, or explicitly documented as one-way
- [ ] It does not lock a large table for long; a lock timeout is set
- [ ] It is backward compatible with the currently deployed code
- [ ] The deploy order is clear (expand, migrate, contract)
- [ ] New columns that will be filtered or joined are indexed
- [ ] Invariants are enforced in the database, not only in the code
- [ ] The migration handles data that already violates the new constraint

## Layer 4: Security

- [ ] An authorization check on every new path, and it checks the object, not just the role
- [ ] No user input trusted for identity (no `userId` from a body or header)
- [ ] No string-built SQL, shell command, or file path
- [ ] No unescaped output into HTML
- [ ] No secret, token, or personal data in the diff, in a log, or in a response
- [ ] New dependencies are justified and audited
- [ ] No new attack surface: a new endpoint, parameter, upload path, or redirect
- [ ] Multi-tenant queries filter by tenant in the data layer
- [ ] The new code does not disable a security control to make a test pass

## Layer 5: Tests

- [ ] A test exists for the new behaviour
- [ ] A bug fix has a regression test that fails without the fix
- [ ] The assertions are meaningful, not just "no exception"
- [ ] The test asserts on behaviour, not on implementation details
- [ ] Edge cases are covered, not only the happy path
- [ ] The test exercises the changed code path rather than mocking it away
- [ ] Fixtures and mocks are reset between tests
- [ ] No dependency on execution order, wall clock, network, or machine-local paths
- [ ] The test names describe the scenario

## Layer 6: Performance

- [ ] No N+1 query
- [ ] Every list query is bounded
- [ ] The index matches the new access pattern
- [ ] No work inside a loop that could be hoisted
- [ ] No allocation in a hot path
- [ ] No synchronous remote call on the request path or inside a transaction
- [ ] The cache has both a TTL and an invalidation strategy
- [ ] The page size and payload size are limited

## Layer 7: Readability

- [ ] The code reads like the code around it
- [ ] Names are accurate; no misleading names
- [ ] The intent is clear without reading the implementation
- [ ] Comments explain why, not what
- [ ] No dead code, commented-out code, or debug leftovers
- [ ] No magic numbers or strings that should be named
- [ ] Function length and parameter count are reasonable

## Layer 8: Operability

- [ ] A log line at the point of failure, with the identifiers needed to debug it
- [ ] A useful error message, not a bare exception
- [ ] A metric for a new failure mode
- [ ] The change is revertible, and the data is backward compatible with the previous version
- [ ] Feature flags have a default that preserves current behaviour

## Layer 9: Documentation

- [ ] The README or the API docs are updated for a behaviour change
- [ ] New configuration and environment variables are documented
- [ ] A changelog entry exists if the project keeps one
- [ ] The migration is documented for anyone who has to run it manually

## Layer 10: Verification

- [ ] The full test suite passes
- [ ] Lint and typecheck pass
- [ ] The change was actually run, not just compiled
- [ ] The tests fail without the change (verified by reverting locally)

## Severity guide

| Severity | Meaning |
|----------|---------|
| **Blocking** | A correctness, security, data-loss, or contract break. Must change before merge. |
| **Should fix** | A real defect or a significant maintainability problem, but not a break. Fix now or file it. |
| **Optional** | A suggestion, a preference, a minor improvement. The author decides. |

Mark every comment with one of these. A review where everything is blocking is exhausting; a review where everything is optional is useless.

## Quick diff commands

```sh
git diff --stat main...HEAD          # scope at a glance
git diff main...HEAD                 # the full change
git diff main...HEAD -- '*.sql'      # only the migrations
git diff main...HEAD -- '*.test.*'   # only the tests
git log --oneline main..HEAD         # the commits
git diff --check                     # whitespace errors
```

Read the whole diff, top to bottom, in one pass. Then read it again focusing on the layers you care about most for this change.
