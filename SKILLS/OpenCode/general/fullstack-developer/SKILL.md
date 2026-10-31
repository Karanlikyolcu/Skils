---
name: Full Stack Developer
description: Use for end-to-end web application work - REST or GraphQL API design, database schema and migrations, authentication and authorization, frontend component architecture and state management, forms and validation, caching, background jobs, and connecting the browser to the server. Applies to any change that touches more than one layer of a web app.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Full Stack Developer

The full stack spans the browser, the network, the server, and the database. Most real bugs live in the seams between those layers, so this skill treats the whole path as one unit of work.

## 1. Trace the whole path first

Before writing code, write down the request path end to end:

```
Browser -> router -> middleware -> validation -> business logic -> DB / external service -> response -> client state -> render
```

For each hop, know: what comes in, what goes out, what can fail, and who is responsible for each decision. Most "backend bugs" are actually a contract mismatch at one of these boundaries.

Identify where each responsibility lives:

| Concern | Owner |
| ------- | ----- |
| Input shape and types | Contract, enforced at the boundary |
| Whether the operation is allowed | Authorization, server side, always |
| The business rule | Domain layer, framework-agnostic |
| Persistence | Repository, not the handler |
| Presentation | View or component |

If a rule is enforced in two places, it will eventually be enforced in only one. Enforce it once, at the layer that owns it.

## 2. Contract before implementation

- Define the API shape first: endpoint, method, request schema, response schema, error shape, status codes.
- Share the types between client and server from one source of truth (OpenAPI, Zod, JSON Schema, a shared package). Two hand-written copies drift.
- Validate at every boundary: HTTP input, query params, headers, message payloads, files, environment values. Assume anything crossing a process is hostile until validated.
- Make illegal states unrepresentable. A status field with 14 possible values and no enum is a future incident.

See `references/api-design.md` for REST and GraphQL conventions, pagination, filtering, versioning, idempotency, and error envelopes.

## 3. Data model and migrations

- Model the real domain. Normalize until it hurts, denormalize until it helps, and stop in the middle.
- Put invariants in the database: foreign keys, unique constraints, `NOT NULL`, check constraints, enum types. Application code is not a substitute for a constraint.
- Index what you query. Every index should map to a known access pattern; an unused index is pure write cost.
- Migrations must be reversible or explicitly documented as one-way, must not lock a large table for long, and must be backward compatible with the currently deployed code. Deploy the expand before the contract.
- Never edit an applied migration. Add a new one.

See `references/database.md` for schema design, index strategy, transaction and locking rules, and pagination patterns.

## 4. API layer

- Keep handlers thin. Parse, authorize, delegate, respond. No business logic in a route file.
- Use a consistent error envelope across the whole API. A client should never have to guess the error format.
- Return the right status code: 400 malformed, 401 unauthenticated, 403 unauthorized, 404 missing, 409 conflict, 422 semantically invalid, 429 rate limited, 500 unexpected.
- Make writes idempotent where the client can retry: accept an idempotency key, or make the operation naturally repeatable.
- Paginate every list endpoint that can grow. Default limit, maximum limit, cursor or offset chosen deliberately.
- Version the API when a breaking change ships. Non-breaking additive changes need no version.

See `references/backend.md` for service layers, validation, error handling, jobs, caching, configuration, and observability.

## 5. Authentication and authorization

Treat these as two separate problems:

- **Authentication**: who is this? Verify the credential properly, issue a session or token with a defined lifetime.
- **Authorization**: may this actor do this to this resource? Check it on the server for every request. A hidden button is not access control.

Rules:

- Never store passwords in plaintext. Use a memory-hard password hash (argon2id, scrypt, bcrypt) with a per-user salt.
- Compare secrets in constant time. Use a constant-time comparison, not `===`.
- Session cookies: `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`, `Path=/`, scoped narrowly.
- Tokens: short-lived access tokens, rotated refresh tokens, signed and verified with a real signature, with expiry and audience checked.
- Authorization defaults to deny. Allowlists over denylists.
- Check ownership, not just role. Role says "may a teacher do this"; ownership says "may this teacher do this to this record".

## 6. Frontend architecture

- Structure by feature, not by file type. A feature folder owns its components, hooks, API calls, and types together.
- One source of truth per piece of state. If both a server cache and local state hold it, define which wins and when they reconcile.
- Separate server state from client state. Server data is a cache with a lifecycle; client state is application logic. Mixing them creates refetch loops and lost updates.
- Derive, do not duplicate. Compute values from state rather than storing a second copy that can go stale.
- Keep components dumb enough to test. Separate data fetching from rendering so the component takes props.

See `references/frontend.md` for component patterns, state management, data fetching, forms, accessibility, and performance.

## 7. Forms and validation

- Validate on the client for fast feedback, validate on the server for correctness. The server is the only authority.
- Client-side validation is a UX feature, never a security control.
- Use the same schema on both sides. One source, two runtimes.
- Handle every field state: empty, focused, invalid, submitting, server error, success. A form with only the success state is unfinished.
- Preserve user input on a failed submit. Losing a long form on a validation error is a serious usability failure.
- Disable the submit button while in flight and prevent double submission.

## 8. Errors, loading, and empty states

Every data view needs all four:

- **Loading** - skeleton or spinner, with a stable layout so nothing jumps.
- **Empty** - explain why it is empty and what to do next. Never a blank panel.
- **Error** - human-readable message, retry affordance, no raw stack trace or internal error text.
- **Success** - confirmation where the action was not obviously visible.

Never show a spinner and an error at the same time. Never leave an infinite spinner after a failed request.

## 9. Integration testing

- Test the contract at the seam: real HTTP request in, real handler, real database transaction (or a faithful container), real response out.
- Seed the database deterministically. Tests that depend on row order, wall clock, or leftover state are flaky.
- One transaction per test with rollback, or a fresh schema per run. Do not share state across tests.
- Mock only what you do not own. Mocking your own database in an integration test defeats the purpose.
- Cover the failure paths: timeout, 500, malformed body, partial write. Those are where production breaks.

## 10. Ship it

Before calling it done:

- Environment configuration is externalized and validated at startup. The app refuses to boot with a missing required variable rather than failing at 3am.
- Logs are structured, carry a request or correlation ID, and contain no secrets or personal data.
- The health check distinguishes "process is up" from "dependencies are reachable".
- Migrations run as a separate deploy step, before the new code serves traffic.
- The change is revertible: a rollback restores the previous code without a data migration that breaks it.

## Supporting files

- `references/api-design.md` - REST and GraphQL conventions, pagination, versioning, idempotency, errors.
- `references/backend.md` - service layers, validation, error handling, jobs, caching, config, observability.
- `references/database.md` - schema design, indexes, transactions, locking, pagination.
- `references/frontend.md` - component structure, state, data fetching, forms, accessibility, performance.
- `references/contract-template.md` - API contract checklist to fill in before implementing.
