# Backend Engineering

## Layering

```
route/handler -> validation -> application service -> domain -> repository -> DB
```

- **Handler**: parse the request, call one service method, map the result to a response. No logic.
- **Application service**: orchestrates. Owns the transaction boundary, the order of operations, and the events emitted.
- **Domain**: the rules. Framework-free, no I/O, unit-testable without mocks.
- **Repository**: the interface the domain depends on; the implementation translates to SQL/ORM.

The service layer is where transaction boundaries live. A repository method that opens its own transaction defeats multi-step atomicity.

## Validation

- Validate at the edge, once, with a schema. Parse, then validate, then act.
- Reject unknown fields on strict endpoints to catch typos and mass-assignment attempts.
- Coerce deliberately: do not silently accept `"true"` as a boolean. Either reject it or convert it explicitly.
- Validate against the business rule, not just the type. "age is a number" is weak; "age is between 0 and 150" is useful.
- Keep the schema as the single source, ideally shared with the client so the same rules run in both places.

## Error handling

- One error type at the application boundary, mapped to HTTP in exactly one place.
- Known failures (not found, conflict, forbidden) are values, not exceptions, when they are part of normal control flow.
- Unexpected failures produce a 500 with a generic message and a request ID. The detail goes to the log, not the client.
- Never leak stack traces, SQL, file paths, or internal hostnames.
- Log once, at the boundary, with the full context.

## Transactions

- One transaction per request, scoped to the service method.
- Keep transactions short. Do not call an external service inside a transaction; the lock is held while waiting on the network.
- Set an isolation level deliberately. Most services need the default (READ COMMITTED); only escalate to SERIALIZABLE with a retry loop, or use explicit row locks.
- Avoid deadlocks by keeping a consistent lock order across the codebase, and by retrying on deadlock detection.
- Use `SELECT ... FOR UPDATE` only when you need to lock specific rows; prefer optimistic versioning otherwise.

## Background jobs

- Any slow or unreliable work belongs in a job, not the request.
- The job payload is a reference (an ID), not a big object graph.
- Jobs must be idempotent: a retry must not duplicate effects. Use an idempotency key or a unique constraint.
- A job's status is queryable. A job that can fail invisibly will.
- Retry with exponential backoff and jitter. Give up after a bounded number of attempts and route to a dead-letter queue.
- Use a visibility timeout longer than the job's expected runtime, and re-queue jobs whose visibility expired (crashed worker).

## Caching

- Cache at the layer where the read happens. Cache-aside is the default: read cache, miss reads DB and populates.
- Keys must include every dimension that affects the result (tenant, locale, permissions, version).
- Set a TTL. A cache without a TTL is a stale-data bug waiting for a user to find it.
- Invalidate on write. If invalidation is hard, use a short TTL plus an explicit version bump.
- Do not cache per-user data in a shared cache without the user key in the cache key.

## Configuration

- Read config from the environment (or a config service). Never from a checked-in file.
- Validate configuration at startup and refuse to boot on invalid values. A missing env var should fail in CI, not in production at 3am.
- Separate required from optional config, with defaults for the optional.
- Log the effective configuration at startup, with secrets redacted.

## Rate limiting and abuse control

- Limit per IP and per user, on auth, expensive, and public endpoints.
- Use a token bucket or sliding window; a fixed window lets a client burst at the boundary.
- Return 429 with `Retry-After`.
- Add a global concurrency limit to protect downstream dependencies.

## Observability

- Structured logs (JSON), one object per event. Fields: timestamp, level, message, request ID, route, status, duration, user ID.
- Propagate a request ID from the edge, return it in the response, include it in every log line.
- Metrics: request rate, error rate, duration percentiles (p50/p95/p99, not averages), plus domain metrics (queue depth, job failures, DB pool usage).
- Distributed tracing across service boundaries, with the trace ID logged and returned.
- Alert on symptoms users feel: error rate, p99 latency, and saturation, not on CPU.
- Health checks: a liveness check (is the process alive) and a readiness check (are dependencies reachable). Keep them separate.

## Performance

- Measure with real data volumes. A query fast on 100 rows may scan on 10 million.
- Eliminate N+1 queries by eager loading or batching. This is the single most common backend performance bug.
- Bound every query. Add `LIMIT` to list endpoints and to any query whose result set depends on user input.
- Use the query plan. `EXPLAIN ANALYZE` before adding an index.
- Cache expensive computations, not everything.
- Use a connection pool and size it from the database's capacity, not from hope. Long transactions starve the pool.

## Async work

- Async is for I/O concurrency, not for making slow code faster. A CPU-bound task in an async function still blocks the loop.
- Set timeouts on every outbound call. Use a deadline that propagates down the call chain.
- Use a circuit breaker for a flaky dependency, so it fails fast instead of exhausting the pool.
- Retry only idempotent operations, with backoff and jitter.

## Testing

- Unit test the domain with no I/O.
- Integration test services against a real database in a transaction that is rolled back, or a fresh schema per test.
- Contract test the API shape so a breaking change fails a build, not production.
- Test the failure paths: dependency timeout, 500 response, malformed body, partial write, concurrent modification.
