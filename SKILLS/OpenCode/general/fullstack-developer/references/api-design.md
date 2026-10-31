# API Design

## Resources and URLs

- URLs name resources (nouns), HTTP methods name the operation (verbs). `POST /orders`, not `POST /createOrder`.
- Plural collection names: `/users`, `/orders`, `/products`.
- Nesting reflects ownership, and only one or two levels deep. `GET /orders/{id}/items` is fine; `GET /orders/{id}/items/{id}/variants/{id}` is not.
- Use a stable identifier in the path. If the client can find it by a natural key, expose that key as a field instead of a second path.
- Lowercase, hyphenated paths. `/order-items`, not `/OrderItems` or `/orderItems`.

| Method | Idempotent | Purpose |
|--------|-----------|---------|
| GET | yes | Read |
| POST | no (make it so) | Create, or a non-CRUD action |
| PUT | yes | Full replace |
| PATCH | not necessarily | Partial update |
| DELETE | yes | Remove |

Actions that do not map to CRUD become sub-resources or a dedicated endpoint (`POST /orders/{id}/cancel`), not verbs smuggled into the path.

## Request and response

- JSON in, JSON out. Use a single consistent envelope style across the whole API; pick one and never mix.
- Field naming: one convention everywhere (snake_case or camelCase). Match the ecosystem you integrate with.
- Timestamps: ISO 8601 with timezone, UTC. Never a Unix timestamp without units.
- Money: integer minor units plus a currency code, or a decimal string. Never a float.
- IDs: opaque strings. Do not expose sequential integers (they leak volume and invite enumeration).
- Nullable vs absent vs empty: be consistent and document it. `null` means "explicitly no value", absent means "not provided".
- Include only what the client needs. A full entity dump exposes fields that will later be restricted.

## Validation and errors

A single error shape for the whole API:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The request body is invalid.",
    "details": [
      { "field": "email", "issue": "must be a valid email address" }
    ],
    "requestId": "req_01H..."
  }
}
```

- `code` is a stable machine-readable string. Clients branch on it. Never branch on the message text.
- `message` is human-readable and safe to show.
- `details` is optional, structured, per-field.
- `requestId` echoes into the server logs so a user-reported error can be traced.

Status codes:

| Code | Use |
|------|-----|
| 200 | Read or update succeeded |
| 201 | Created (with `Location` header) |
| 202 | Accepted for async processing |
| 204 | Success, no body |
| 400 | Malformed request (unparseable, wrong type) |
| 401 | Not authenticated |
| 403 | Authenticated but not allowed |
| 404 | Resource does not exist (or is hidden - see below) |
| 409 | Conflict with current state (duplicate, version mismatch) |
| 422 | Semantically invalid (fails business validation) |
| 429 | Rate limited |
| 500 | Unexpected server error |

Never return 200 with an error body, and never return 500 for a client mistake.

For resources the user must not know about, return 404 rather than 403 - otherwise the endpoint confirms the resource exists.

## Pagination

- Never return an unbounded list.
- Offset pagination: simple, but slow and unstable when rows are inserted. Fine for small, mostly-static lists and for "page N" UI.
- Cursor pagination: stable and fast, and the right default for anything that grows or changes. The cursor encodes the sort position, usually opaque and signed.
- Default limit 20-50. Cap the maximum. Return the total count only when it is cheap and useful; otherwise omit it.
- The response carries the cursor and a `hasMore` flag:

```json
{ "data": [...], "pageInfo": { "nextCursor": "eyJ...", "hasMore": true } }
```

## Filtering, sorting, searching

- Define filter parameters explicitly (`status`, `createdAfter`). Free-form filter expressions are an injection surface and a support burden.
- Whitelist sortable fields. Never interpolate a sort field into SQL.
- Use a real search index for text search. A `LIKE '%term%'` across a large table will not survive contact with production.
- Cap the requested page size on the server even if the client asks for more.

## Idempotency

For POST endpoints that can be retried (payments, orders, webhook-ish calls):

- Client sends an `Idempotency-Key` (a UUID).
- The server stores the key with the result and returns the stored result on a repeat.
- Keys expire after a window (24 hours is typical).
- A repeat with the same key but a different body returns a 409.

This turns a network retry from a double-charge into a no-op.

## Versioning

- URL versioning (`/v1/orders`) is visible and easy to route. It accumulates dead versions.
- Header versioning is cleaner but invisible in logs and easy to get wrong.
- Additive changes (new optional field, new endpoint) need no version bump.
- Breaking changes: removing or renaming a field, changing a type, tightening validation, changing default behavior, changing an error code's meaning.
- Deprecation: announce, add a `Deprecation` and `Sunset` header, log usage per client, and remove only after usage reaches zero.

## Caching

- `ETag` plus `If-None-Match` for conditional requests. A 304 is a real win on list endpoints.
- `Cache-Control: max-age`, `s-maxage`, and `stale-while-revalidate` for shared caches.
- `Cache-Control: no-store` for anything sensitive.
- ETag generation: hash of the representation, not the row version alone (the representation changes when relationships change).

## Rate limiting

- Limit per user and per IP, per endpoint class.
- Auth endpoints get the strictest limits, with exponential backoff on failure.
- Return 429 with `Retry-After`.
- A limit that no client can observe is a limit nobody respects.

## Concurrency control

- Optimistic locking: a `version` column, the client sends the version it read, the server rejects a mismatch with 409.
- PATCH semantics: define whether a field present but null sets the value to null or is ignored. Make it explicit in the contract.

## Webhooks

- Sign the payload (HMAC-SHA256 over the raw body plus a timestamp). The receiver verifies before parsing.
- Include a timestamp and reject old deliveries (replay protection).
- Make delivery idempotent on the receiver side via a delivery ID.
- Retry with exponential backoff, then stop. Do not deliver forever.
- Send a stable event ID and a schema version in the payload.

## GraphQL

- Schema-first. The schema is the contract; generate types and keep resolvers thin.
- N+1 is the default failure mode. Use DataLoader to batch, and set query depth and complexity limits.
- Always paginate connections.
- Return partial data with an `errors` array where possible, rather than nulling the whole response.
- Disable introspection in production if the API is not public.
- Set query cost limits by depth, list size, and complexity.

## Documentation

- OpenAPI generated from the implementation, so it cannot drift.
- Every endpoint: purpose, auth requirement, request schema, response schema, error codes, rate limit, idempotency support.
- Include at least one example per endpoint.
