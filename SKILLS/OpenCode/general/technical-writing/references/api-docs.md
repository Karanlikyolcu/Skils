# API Documentation

## What an API reference must contain

For every endpoint:

| Section | Content |
|---------|---------|
| Purpose | One sentence: what this does for the caller |
| Authentication | Required, optional, or none |
| Authorization | The role, permission, or ownership rule |
| Idempotency | Whether a repeat is safe, and how |
| Request | Path params, query params, headers, body, with types and rules |
| Response | Success status, body shape, headers returned |
| Errors | Every status code, its machine-readable code, and when it happens |
| Rate limits | Requests per window, and the headers that report them |
| Pagination | Style, default and maximum limit, sort order |
| Examples | At least one request and one response |

## OpenAPI as the source of truth

Generate the reference from the schema so it cannot drift.

```yaml
openapi: 3.1.0
info:
  title: Orders API
  version: 2.4.0
  description: |
    Create and manage orders.

    All endpoints require an API key. Rate limits are per key.
servers:
  - url: https://api.example.com/v2
    description: Production
  - url: https://api.staging.example.com/v2
    description: Staging

paths:
  /orders:
    post:
      summary: Create an order
      description: Creates an order. Idempotent when `Idempotency-Key` is supplied.
      operationId: createOrder
      security:
        - apiKey: []
      parameters:
        - name: Idempotency-Key
          in: header
          required: false
          description: UUID. A repeat returns the original result.
          schema: { type: string, format: uuid }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/CreateOrderRequest' }
            examples:
              minimal:
                summary: A single item order
                value:
                  sku: ABC-123
                  quantity: 2
      responses:
        '201':
          description: Order created
          headers:
            Location: { schema: { type: string } }
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Order' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthorized' }
        '422': { $ref: '#/components/responses/ValidationFailed' }
        '429':
          description: Rate limit exceeded
          headers:
            Retry-After: { schema: { type: integer } }
```

- Annotate every operation with a `summary`, a `description`, and an `operationId`. The `operationId` becomes the generated client method name.
- Use `components/schemas` for every request and response body. Reuse, do not duplicate.
- Use `components/responses` for the standard error responses. One definition per status code, used everywhere.
- Add `examples` for every request and response. An example is the fastest way for an integrator to understand the shape.
- Mark a field `deprecated: true` with a description saying what to use instead and when it will be removed.

## Error documentation

Document the error envelope once, and reference it everywhere.

```yaml
Error:
  type: object
  required: [error]
  properties:
    error:
      type: object
      required: [code, message, requestId]
      properties:
        code:
          type: string
          description: |
            Stable machine-readable code. Branch on this, never on the message.
          example: validation_failed
        message:
          type: string
          description: Human-readable, safe to display.
          example: The request body is invalid.
        details:
          type: array
          description: Field-level problems, when applicable.
          items:
            type: object
            properties:
              field: { type: string }
              issue: { type: string }
        requestId:
          type: string
          description: Quote this when contacting support.
```

## Documenting the semantics, not just the shape

The schema says what the fields are. The prose says what they mean.

Document explicitly:

- **Units.** Bytes, cents, seconds, milliseconds. Never leave it implicit.
- **Timezones.** Timestamps are UTC unless stated.
- **Nullability.** The difference between "not provided", "null", and an empty value.
- **Enums.** Every allowed value, and what each one means.
- **Defaults.** The value used when the field is omitted.
- **Ordering.** Whether a list is sorted, and by what.
- **Idempotency.** Whether a repeat is safe.
- **Side effects.** What else the call does (sends an email, enqueues a job, charges a card).
- **Pagination.** Whether it is stable under concurrent writes.
- **Rate limits.** The number, the window, and the headers.

## Authentication and authorization

- One section on how to authenticate: the header or parameter, how to obtain the credential, how to rotate it, and its lifetime.
- Per endpoint: which scopes, roles, or permissions are required.
- An example of an unauthorized request and the 401 response.
- State whether the API key is scoped, and to what.

## Versioning

Document the version in the path or the header, and state the policy:

- Which changes are breaking and which are not.
- How a breaking change is communicated (the `Deprecation` and `Sunset` headers).
- The deprecation window, in months.
- Which versions are currently supported.

```markdown
## Versioning

We use path versioning: `/v2/`.

Additive changes (new optional fields, new endpoints) ship without a version
bump and are safe to adopt immediately.

Breaking changes - removing or renaming a field, changing a type, tightening
validation, changing the meaning of an error code - ship in a new major
version. The previous major version is supported for at least 12 months after
the new one ships. A deprecated version returns `Deprecation: true` and
`Sunset: <date>` headers.
```

## Keeping it accurate

- Generate the reference from the implementation, not by hand.
- In CI, compare the committed spec against the generated one and fail on a difference. This catches a route that was added without documentation.
- Validate the examples in CI: call the endpoint in a test environment and compare the shape.
- Check every link.
- Date anything version-specific, and re-verify it on each release.

## Beyond the reference

An API reference alone is not enough. Add:

- **A quickstart.** The shortest path from nothing to a working call: get a key, make one request, see a response.
- **Authentication.** How to obtain and rotate credentials.
- **Errors and retries.** Which errors are retryable, which are not, and how to handle a 429.
- **Pagination.** A worked example of walking through the pages.
- **Webhooks.** The payload, the signature verification, the retry policy, and the delivery ordering.
- **Rate limits.** The numbers, and what happens when they are exceeded.
- **Changelog.** What changed in each version, and the migration steps.
- **SDKs.** How to install and use the generated clients, if there are any.

## Anti-patterns

- A reference generated from the code with no prose, so the semantics are undocumented.
- Examples that are syntactically valid but semantically wrong.
- Error codes documented in a table that does not match the implementation.
- No mention of rate limits, pagination, or idempotency.
- A quickstart that assumes things the reference explains later.
- Examples with fake values that look like real credentials.
