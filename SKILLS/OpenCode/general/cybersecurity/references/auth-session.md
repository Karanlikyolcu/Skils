# Authentication, Authorization, and Sessions

## Password storage

- Hash with a memory-hard function: **argon2id** (preferred), **scrypt**, or **bcrypt**.
- Parameters for argon2id: memory 64-256 MB, iterations 3, parallelism 1, 32-byte salt. Tune to ~250-500 ms on production hardware and record the parameters with the hash.
- The salt is per-user, random, stored alongside the hash. The hash format encodes the algorithm and parameters, so you can change them later and re-hash on next login.
- Never MD5, SHA-1, SHA-256, or any fast hash. Unsalted or weakly salted hashes are trivially cracked with commodity GPUs.
- Never store the plaintext, not even encrypted. Encryption implies you can decrypt, and you do not need to.
- On successful login, check whether the hash uses outdated parameters and transparently re-hash.
- If a password is leaked from another service, check it against a breach corpus (e.g. HIBP k-anonymity range API) and force a reset.

## Password policy

- Length over composition. A long passphrase beats `P@ssw0rd!`.
- Minimum 12 characters for user-chosen passwords, 20 for generated ones.
- Check against a breach list and a list of common passwords.
- Do not force periodic rotation without a compromise signal; it drives predictable passwords.
- Do not silently truncate. If the site accepts at most 72 bytes (bcrypt), enforce that limit explicitly at the input.
- Support paste from password managers. Block paste and block password managers and users lose.
- Offer a password manager and a generator.

## Login and enumeration

- Generic error: "Invalid email or password". Never reveal which part was wrong.
- Same response time for an unknown user and a wrong password (hash a dummy password when the user does not exist).
- Do not leak existence through signup ("email already registered"), password reset, or invitation flows.
- Rate limit per account and per source, with exponential backoff. Consider a CAPTCHA after several failures.
- Alert the user of a successful login from a new device or location.
- Support multi-factor authentication (TOTP, WebAuthn, passkeys). Passkeys are phishing-resistant; prefer them.

## Password reset

- Generate a single-use token with a CSPRNG, at least 128 bits of entropy.
- Store only the hash of the token. Compare in constant time.
- Short expiry (15-60 minutes).
- Invalidate the token on use, on new issue, and on password change.
- Do not reveal whether the account exists. Always show the same confirmation page.
- Invalidate existing sessions after a reset.
- Rate limit reset requests per account and per source.

## Sessions (server-side)

- Generate the session ID with a CSPRNG, at least 128 bits. Store only a hash of it in the database, so a database leak does not yield usable session IDs.
- Store: id (hashed), user id, created, last seen, expires, IP, user agent, and a revocation flag.
- Idle timeout (e.g. 30 min for sensitive apps) plus an absolute timeout (e.g. 12 h).
- Rotate the session ID on privilege change: login, password change, MFA enrollment, elevation.
- Revoke server-side on logout. Clearing the cookie is not enough.
- Revoke all sessions on a password change, and all other sessions on a "log out everywhere" action.
- Detect concurrent sessions and show the user a list to revoke.

## Cookies

```
Set-Cookie: __Host-session=...; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=3600
```

- The `__Host-` prefix requires `Secure`, `Path=/`, and no `Domain`. It prevents a subdomain from setting the cookie and prevents a path-based fix. Use it where possible.
- `HttpOnly` blocks JavaScript access.
- `Secure` restricts to HTTPS.
- `SameSite=Lax` allows top-level GET navigation; `Strict` blocks all cross-site sending. `Lax` is usually right for apps; `Strict` breaks external links back into the app.
- Minimal `Domain` scope. Never `Domain=.example.com` unless subdomains genuinely need it.

## Tokens (JWT and opaque)

Prefer **opaque tokens** stored server-side when you need revocation. Use JWTs when the verification must be local and stateless.

If using JWT:

- Verify the signature with the correct algorithm. Reject `alg: none` and reject an unexpected algorithm. Do not trust the `alg` header to pick the algorithm.
- Always verify `exp`. Also verify `nbf`, `aud`, and `iss`.
- Keep access tokens short-lived (5-15 minutes). Use a refresh token for longer sessions.
- Refresh tokens: rotate on every use, detect reuse of a rotated token, and revoke the family on detection.
- Store refresh tokens server-side so they can be revoked. A pure stateless refresh token cannot be revoked.
- Do not put sensitive data in the payload. The payload is base64, not encrypted.
- Use a strong key (at least 256 bits) and rotate with a key id (`kid`) so multiple keys can be active during rotation.
- Keep clock skew in mind, but never disable expiry validation.

## OAuth 2.0 / OIDC

- Use the authorization code flow with PKCE. Never the implicit flow.
- Validate `state` (CSRF protection) and use a fresh, unguessable value.
- Verify the ID token: signature, `iss`, `aud`, `exp`, and `nonce`.
- Validate the exact issuer, not a string prefix. `https://accounts.google.com.evil.com` must not pass.
- Pin the JWKS endpoint. Cache keys, but re-fetch when an unknown `kid` appears.
- Do not accept an email as identity without verifying `email_verified` and confirming the provider.
- Redirect URIs must be exact matches from a pre-registered allowlist.
- Never use a wildcard redirect URI in production.
- Request the narrowest scopes that work.

## Authorization model

- **RBAC**: roles grant permissions. Good for organizations with a stable role set.
- **ABAC**: attributes (owner, tenant, time, resource tag) drive the decision. Better for fine-grained rules.
- **Policy**: a single function decides, given (actor, action, resource). Centralizes the rules.
- Default deny. Check on every request, server-side.
- Enforce at the service layer, not only in the route, so internal calls are covered too.
- Check resource ownership explicitly. A role check alone does not answer "may this teacher edit this record".
- Cache permission checks carefully, and include every input in the cache key (user, role, resource, tenant).
- Make the permission list enumerable: a test asserts that every route has an explicit policy.

### Multi-tenant isolation

- Tenant id comes from the authenticated session, never from a request parameter or header.
- The repository layer applies the tenant filter automatically. A handler cannot forget it.
- The database row-level security policy is a strong second layer.
- Composite unique keys include the tenant: `UNIQUE (tenant_id, email)`.
- Background jobs carry the tenant context and re-establish it.
- Test: for every repository method, attempt a cross-tenant read and write and assert failure.

## API keys and service accounts

- Store only a hash of the API key, like a password. Show it once at creation.
- Prefix keys so they are recognizable in logs and secret scanners (`sk_live_...`).
- Scope per key. A key for read-only reporting does not also allow writes.
- Expiry and rotation. Revocation that takes effect immediately.
- Log every use with the key id, the endpoint, and the source.

## Sessions for mobile and desktop apps

- Use the platform credential store (Keychain, Keystore, libsecret). Never store tokens in plain preferences.
- Prefer short-lived access tokens with a refresh token stored in the secure store.
- Bind the refresh token to the device where possible, and detect a token used from a different device.
- Support revocation: the server rejects refresh tokens for a revoked device.

## Multi-factor authentication

- TOTP: 30-second window, allow one step of drift, do not cache the last accepted code in a way that permits replay.
- Recovery codes: single use, stored hashed, regenerate the whole set on use.
- Enforce MFA on admins, on sensitive actions, and after a password change.
- Keep the enrollment flow safe: confirm the password, show the secret once, verify a working code before saving.
- Require a second factor on device registration, not only on login.

## Checklist

- [ ] Passwords hashed with argon2id/scrypt/bcrypt and a per-user salt
- [ ] Login errors and timings do not reveal whether an account exists
- [ ] Rate limiting on login, reset, and MFA verification
- [ ] Session IDs from a CSPRNG, stored hashed, rotated on privilege change
- [ ] Cookies: HttpOnly, Secure, SameSite, scoped, `__Host-` prefix where possible
- [ ] Logout revokes server-side
- [ ] Password reset tokens are single-use, short-lived, and stored hashed
- [ ] JWTs: signature, `exp`, `nbf`, `aud`, `iss` all verified; `alg: none` rejected
- [ ] Refresh tokens rotate and reuse is detected
- [ ] Authorization default deny, object-level checks, enforced in the service layer
- [ ] Tenant id from the session, never from client input
- [ ] MFA available and enforced for privileged accounts
- [ ] API keys hashed, scoped, revocable, and logged
