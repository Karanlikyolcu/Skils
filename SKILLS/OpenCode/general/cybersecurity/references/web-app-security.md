# Web Application Security

## OWASP Top 10 and concrete controls

### 1. Broken access control

The most common serious flaw. Controls:

- Default deny. Every protected route has an explicit check.
- Object-level authorization: verify the actor owns or may access the specific record.
- Function-level authorization: verify the role may perform the specific operation.
- Deny by default at the framework level, then allow explicitly.
- Multi-tenant: tenant filter in the repository layer, always, plus a test that attempts cross-tenant access.
- Do not trust identifiers from the client. Never accept `userId`, `role`, `isAdmin`, or `tenantId` from a request body or header.
- Disable directory listing, and forbid access to raw storage paths.

Test: for every endpoint, try it as another user, as a lower role, and with another object's ID.

### 2. Cryptographic failures

- TLS for everything, including internal hops where an attacker could sit on the network.
- Passwords hashed with argon2id/bcrypt. See `secure-coding.md`.
- Secrets in a secret manager, never in code or images.
- Encryption at rest for sensitive data, with keys separate from the data.
- Do not invent an algorithm. Use a vetted library.

### 3. Injection

- Parameterize SQL. Whitelist identifiers.
- No shell with user input. Use argument arrays.
- Encode output for its context; sanitize only when HTML is required.
- Validate against a schema at the boundary.

### 4. Insecure design

- Threat model new flows.
- Business logic must enforce limits: max amount, max quantity, allowed state transitions. These are the checks an attacker cannot bypass by bypassing the UI.
- Assume the client is hostile and the API is public, even if it is "internal".

### 5. Security misconfiguration

- Disable directory listing, default accounts, and default credentials.
- Set security headers:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none'
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
Cross-Origin-Opener-Policy: same-origin
```

- Minimal CORS: an explicit origin allowlist, never `*` with credentials. `Vary: Origin` when reflecting.
- Disable verbose error pages. Turn off directory and stack traces in production.
- Set `server` headers off where possible; reduce the fingerprint.

### 6. Vulnerable and outdated components

- Lockfiles, automated audit in CI, prompt patching.
- Remove unused dependencies: an unused vulnerable package is still a vulnerable package.
- Scan container images and base images.

### 7. Identification and authentication failures

- See `auth-session.md`.
- Rate limit login, password reset, and MFA verification.
- Generic error messages, no user enumeration.
- Session invalidation on logout and on password change.

### 8. Software and data integrity failures

- Verify signed artifacts: checksums, Sigstore, package provenance.
- Do not run unsigned CI steps from untrusted pull requests.
- Do not `curl | sh` from a URL you do not control, especially with a mutable tag.
- CI: pin actions by SHA, use minimal token permissions, require review for forks.

### 9. Security logging and monitoring failures

- Log authentication events, access-control failures, input validation failures, and server-side state changes.
- Alert on: failed-login spikes, privilege changes, mass data export, secret/config changes, and logging failures.
- Keep audit logs outside the application's own write access.

### 10. Server-Side Request Forgery

- Allowlist hosts and schemes. Validate the resolved IP against private ranges.
- Block the cloud metadata address `169.254.169.254` explicitly.
- Disable redirect following, or re-validate each hop.
- Timeouts and size limits on outbound calls.

## CSRF

- Issue a CSRF token tied to the session; require it on state-changing requests.
- Use `SameSite=Lax` (or `Strict`) cookies as defense in depth.
- Require a custom header or `Content-Type: application/json` on JSON APIs, which forms cannot set.
- Never use GET for a state change.
- Do not disable the token check "for the mobile client" without an equivalent mechanism.

## Cookies

```
Set-Cookie: session=...; HttpOnly; Secure; SameSite=Lax; Path=/; Domain=example.com; Max-Age=3600
```

- `HttpOnly` blocks JavaScript access, which blunts XSS-based session theft.
- `Secure` restricts to HTTPS.
- `SameSite` limits cross-site sending.
- Minimal `Domain` and `Path` scope.
- Short lifetime plus an absolute expiry; refresh on activity.

## CORS

- `Access-Control-Allow-Origin` must be an explicit allowlist. Never reflect the origin without checking it.
- With credentials, `Allow-Origin: *` is invalid and browsers reject it. Use the exact origin.
- `Allow-Credentials: true` only with a specific origin.
- Only allow the methods and headers actually needed.
- `Vary: Origin` when the response varies by origin, so caches do not serve the wrong CORS headers.
- Preflight caching: `Access-Control-Max-Age` to avoid a round trip per request.

## Host header and URL issues

- Validate the `Host` header against an allowlist, to prevent cache poisoning and password-reset link poisoning.
- Build absolute URLs (reset links, webhooks) from a configured base URL, never from the request headers.
- Validate the `X-Forwarded-*` headers only if a trusted proxy sets them.

## Open redirect

- Use an allowlist of redirect targets, or only allow relative paths that start with a single `/` and are not `//`.
- Validate the return URL parameter against an allowlist of known app routes.

## File upload

- Enforce a size limit at the server and at the proxy.
- Sniff the content type from the file content, not the client header.
- Allowlist extensions and, better, allowlist content types.
- Store outside the web root with a generated, non-guessable name.
- Serve downloads with `Content-Disposition: attachment` and a safe `Content-Type`.
- Never execute or render the uploaded file as HTML.
- Scan for malware if the risk warrants it.

## Subresource integrity and third-party scripts

- Load third-party scripts with `integrity` and `crossorigin` attributes.
- Pin the exact version. A compromised CDN script runs with full page privileges.
- Consider a strict CSP so a compromised third-party script is contained.
- Self-host critical assets.

## API-specific hardening

- Rate limit: per IP and per user, stricter on auth and expensive endpoints.
- Request body size limits at the server and the reverse proxy.
- Disable HTTP TRACE. Return `405` for unknown methods.
- Set `Cache-Control: no-store` on responses containing sensitive data.
- Validate `Content-Type` on requests with a body.
- CORS preflight should not reveal more than needed.

## Checklist before shipping

- [ ] Access control checked on every endpoint, per object and per role
- [ ] Multi-tenant isolation enforced in the data layer, with a cross-tenant test
- [ ] All input validated with a schema at the boundary
- [ ] No SQL, shell, or template built by concatenation
- [ ] Output escaped by the framework, no unsafe HTML sinks
- [ ] CSRF protection on cookie-authenticated state changes
- [ ] Cookies: HttpOnly, Secure, SameSite, scoped, short-lived
- [ ] Security headers set, CSP without `unsafe-inline`
- [ ] Rate limits on auth and expensive endpoints
- [ ] Secrets from a secret manager, not from the repository
- [ ] Dependency audit clean, no unused packages
- [ ] Error responses carry no internals
- [ ] Audit logging on auth events and admin actions
- [ ] TLS enforced, HSTS set, certificate validation on
- [ ] File uploads restricted by size, type, and location
