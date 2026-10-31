# API Contract Template

Fill this in before implementing an endpoint. If a field cannot be answered, the design is not settled yet.

---

## Endpoint

```
METHOD /path
```

**Purpose:** one sentence - what this does for the caller.

**Authentication:** required | optional | none
**Authorization:** the role, permission, or ownership rule that grants access.
**Idempotent:** yes | no - and if no, is an `Idempotency-Key` supported?

## Request

**Path parameters**

| Name | Type | Rules | Example |
|------|------|-------|---------|
| | | | |

**Query parameters**

| Name | Type | Required | Default | Rules | Example |
|------|------|----------|---------|-------|---------|
| | | | | | |

**Headers**

| Name | Required | Purpose |
|------|----------|---------|
| | | |

**Body**

```json
{
  "field": "value"
}
```

| Field | Type | Required | Nullable | Rules | Example |
|-------|------|----------|----------|-------|---------|
| | | | | | |

**Validation rules** - the checks beyond type:
- field: rule
-

**Unknown fields:** rejected | ignored

**Size limit:** body max, string max, array max, upload max.

## Response

**Success status:** `200` | `201` | `202` | `204`

```json
{
  "field": "value"
}
```

| Field | Type | Nullable | Notes |
|-------|------|----------|-------|
| | | | |

**Headers returned:** `Location` | `ETag` | `Cache-Control` | `Retry-After` | `X-Request-Id` |

## Errors

| Status | `code` | When it happens | Client should |
|--------|--------|-----------------|---------------|
| 400 | | | |
| 401 | | | |
| 403 | | | |
| 404 | | | |
| 409 | | | |
| 422 | | | |
| 429 | | | |

**Error envelope shape** (must match the whole API):

```json
{
  "error": {
    "code": "",
    "message": "",
    "details": [],
    "requestId": ""
  }
}
```

**Are details ever returned to the client?** What is redacted from the message?

## Pagination

**Style:** offset | cursor | none
**Default limit:** **Max limit:**
**Sort order:** the default and whether the client may change it
**Cursor encoding:** opaque | visible

```json
{ "data": [], "pageInfo": { "nextCursor": "", "hasMore": true } }
```

## Rate limiting

**Limit:** requests per window, per user and per IP
**Headers:** `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` | `Retry-After`
**Behavior on exceed:** `429` with a body?

## Idempotency

**Key header:** `Idempotency-Key`
**Server behavior on repeat:** returns the original result | `409` on a different body
**Key TTL:**

## Concurrency

**Optimistic locking:** version field | etag | none
**Conflict response:** `409` | `412`

## Lifecycle

- **Events emitted:** name and payload, if any
- **Side effects:** email, webhook, cache invalidation
- **Async:** does it return `202` and process later? How is the result observed?

## Caching

**`Cache-Control`:** **ETag:** **Invalidated by:**

## Non-goals

What this endpoint deliberately does not do, so nobody asks for it later.

## Examples

**Request**

```bash
curl -X POST https://api.example.com/v1/orders \
  -H 'Authorization: Bearer ...' \
  -H 'Content-Type: application/json' \
  -d '{"sku":"ABC-123","quantity":2}'
```

**Response**

```json
{
  "id": "ord_01H...",
  "status": "created"
}
```

**Error**

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The request body is invalid.",
    "details": [{ "field": "quantity", "issue": "must be at least 1" }],
    "requestId": "req_01H..."
  }
}
```

---

## Client/server type sharing

Where do the types live?
- [ ] Shared package
- [ ] Generated from OpenAPI
- [ ] Generated from the schema library
- [ ] Duplicated (requires a contract test)

**Runtime validation:** does the client parse the response, or trust the type?
