# Code Quality

## Smell catalogue

**Long function** - over ~50 lines usually means several responsibilities. Split at the point where you can name the second thing it does.

**Long parameter list** - five or more parameters usually means the function wants an object. If the parameters are all one type, they are easy to swap by accident.

**Boolean flag parameter** - `render(true, false)` tells the reader nothing. Split into two functions.

**Feature envy** - a method reaches into another object's data more than its own. Move the behavior to the data.

**Data clumps** - the same four fields travel together across five signatures. Make a type.

**Shotgun surgery** - one logical change requires editing eight files in eight directories. That is a missing abstraction, not eight unrelated edits.

**Divergent change** - one file changes for many unrelated reasons. Split it.

**Primitive obsession** - raw strings and ints for things with a small domain (order status, country, currency). Use an enum or a value type so the compiler helps.

**Middle man** - a class that only forwards to another. Remove it or give it a reason to exist.

**Speculative generality** - hooks, extension points, and configurable behavior for a requirement that does not exist. Delete it. YAGNI is a real cost.

**Comments describing what** - `// increment i` above `i++`. Comments should explain why, or a non-obvious invariant.

**Dead code** - unreachable branches, unused exports, commented-out blocks. Delete it. Version control remembers it.

**Global mutable state** - a module-level variable anyone can write. It makes tests order-dependent and reasoning impossible.

## Naming

- Name things for what they are, not for how they are implemented. `PaymentProcessor` over `StripeHttpClient` unless it truly only wraps Stripe.
- Names should be readable at the call site: `user.isEligibleForRefund()`, not `user.elg()`.
- Boolean names read as predicates: `isValid`, `hasAccess`, `shouldRetry`.
- Avoid negation: `isNotReady` forces double negatives at the call site.
- Consistent vocabulary across the codebase. If it is a "customer" in one module and a "user" in another, that is a real problem, not a naming preference.
- Do not encode the type in the name (`stringName`, `listOfItems`) unless the language has no types.
- Rename when the meaning changes. A misleading name is worse than no name.

## Error handling

- Fail fast on programmer errors (invalid argument, impossible state). Return an error on expected failures.
- Never swallow an exception. If you catch it, either handle it, rethrow with context, or explicitly mark it as deliberately ignored with a comment saying why.
- Do not use exceptions for control flow in hot paths.
- Error messages should say what failed, with which identifiers, and what the caller can do. No stack traces or internal details to the user.
- Wrap errors at the layer where you can add context: `raise OrderNotFound(order_id)` beats propagating `KeyError`.
- Distinguish retryable from permanent failures. Retry only the retryable ones, with backoff.
- Log at the boundary where the error is finally handled, once, with the full context. Logging at every level produces duplicate noise.

## Defensive programming

Balance: validate at the boundaries (network input, user input, external files, environment), and trust the interior (your own code, called through a checked contract). Validating everything everywhere produces noise and hides real bugs.

- Null checks belong where the value can actually be null.
- Prefer returning a Result/error value over null when the caller must handle the failure.
- Use assertions for invariants that must never be violated, not for user input.

## API design

- One obvious way to do the thing. A good API makes the correct usage the easiest usage.
- Consistent naming and argument order across the whole surface. `get(id)` everywhere or `get({id})` everywhere.
- Return the domain object, not a partial DTO that hides fields. Do not silently omit fields for performance.
- Accept the smallest useful input. `update(patch)` is easier to reason about than `update(fullObject)`.
- Errors are part of the contract: name them, define them, make them machine-readable.
- Do not expose internal types across a module boundary. That couples the caller to your internals.
- Version deliberately. Additive changes are not breaking; removing or retyping a field is.
- Document the contract: what it accepts, what it returns, what it throws, and what it does not do.

## Testing

**The pyramid** - many fast unit tests, fewer integration tests, fewest end-to-end tests. Invert it and the suite becomes slow enough that people stop running it.

- **Unit test**: one unit, no I/O, milliseconds, hundreds of them.
- **Integration test**: real components wired together (database, HTTP), still fast enough to run per commit.
- **End-to-end test**: the whole stack through the UI. Expensive, brittle, but it catches wiring mistakes that nothing else finds.

Rules:

- Test behavior, not implementation. A test that breaks when you rename a private helper is testing the implementation.
- One reason to fail per test. If the name contains "and", split it.
- Arrange, Act, Assert, in that order, visibly.
- Name the test as a sentence about behavior: `rejects_expired_token`, not `test_token_3`.
- No shared mutable fixtures between tests. Each test builds its own state.
- No wall-clock dependency. Inject the clock. No sleeping to wait for something; await the condition.
- Deterministic randomness: seed the RNG.
- A bug fix ships with a test that fails before the fix and passes after. If you cannot write that test, the fix is not understood.

**Coverage** is a diagnostic, not a goal. Use it to find untested branches, not to chase a number. 100% coverage with meaningless assertions is worse than 60% with real ones.

## Refactoring discipline

- Refactoring and behavior change in the same commit make review impossible. Separate them.
- The tests must be green before you start and after every step. Red during refactoring means you lost the thread.
- Refactor in small, compilable steps. Each commit leaves the codebase working.
- Use the compiler: rename a field or change a signature and let the type errors find every call site.

## Performance code

- Measure first. Always.
- The hot path is a small fraction of the code. Optimizing the cold path is wasted effort.
- Algorithmic wins beat micro-optimizations by orders of magnitude: O(n log n) over O(n²), one index over a table scan, one query over N.
- Cache results, not computations, when the computation is cheap and the result is reused.
- Avoid premature memoization; it introduces invalidation bugs.
- Allocation in a hot loop costs. Reuse buffers and objects in hot paths.
- Keep the hot path branch-free and predictable where it matters. Avoid polymorphic dispatch and megamorphic call sites in tight loops.
