---
name: Cybersecurity
description: Use for security engineering - threat modeling a design, secure code review, authentication authorization and session design, input validation and injection defenses, secrets and key management, dependency and supply chain risk, cryptography usage, and security testing. Applies when writing or reviewing anything that handles untrusted input, credentials, personal data, or network exposure.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Cybersecurity

Defensive security engineering. The goal is that the system fails safe, that compromise requires more than one mistake, and that every assumption about a trust boundary is written down.

## 1. Identify the trust boundaries first

Before reviewing or writing security-relevant code, draw the trust boundaries and list what crosses them.

Trust boundary examples: browser to server, server to database, server to third-party API, internal service to internal service, user input to the filesystem, one tenant to another.

For each boundary, answer:

- What data crosses it, and who can influence it?
- What is validated, where, and by which layer?
- What is the assumption if the other side is compromised?
- Does the boundary fail closed or open?

If you cannot name the boundary, you cannot reason about it. Most vulnerabilities are a boundary that was assumed to be there, or assumed not to be there.

## 2. Threat model before you build

For anything new, a short threat model takes 20 minutes and prevents weeks of rework.

See `references/threat-modeling.md` for the STRIDE walkthrough, data-flow steps, abuse cases, and risk rating.

Minimum output:

1. Assets worth protecting, and their value.
2. Entry points and trust boundaries.
3. For each entry point: spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege.
4. Mitigations per threat, and which are code, which are configuration, which are infrastructure.
5. Residual risk and accepted risk, stated explicitly.

Threat model the design, not just the code. Most design-level flaws (shared credentials, missing tenant isolation, unbounded queue) cannot be fixed by patching the endpoint later.

## 3. Secure coding defaults

The order of defense matters. Apply these in order, and stop when the risk is acceptable.

| Priority | Control |
| -------- | ------- |
| 1 | Do not accept the input (allowlist) |
| 2 | Validate against a strict schema (type, length, range, format) |
| 3 | Encode for the output context (HTML, shell, SQL, URL) |
| 4 | Parameterize the query |
| 5 | Run with least privilege |
| 6 | Sandbox or isolate the operation |

- **Never use string concatenation to build SQL, shell commands, or file paths.** Use parameterized queries, `execFile` with an argument array, and path APIs that resolve against a fixed root.
- **Never render untrusted data into HTML.** Escape by default and sanitize only when HTML is genuinely required. A sanitizer is a last resort, not a default.
- **Validate on the server.** The client is controlled by the attacker.
- **Allowlist, do not denylist.** Rejecting known-bad values always misses the next one.
- **Normalize before you validate** (trim, case-fold, unicode-normalize) so equivalent inputs cannot bypass a filter.
- **Constrain size.** Every input has a maximum length, every upload a maximum size, every query a maximum result count, every request body a maximum body size.

See `references/secure-coding.md` for the per-language and per-class vulnerability catalogue with concrete fixes.

## 4. Authentication, authorization, sessions

Two separate gates. Authentication failure is annoying; authorization failure is a breach.

**Authentication:**

- Hash passwords with argon2id, scrypt, or bcrypt. Never MD5, SHA-1, or plain SHA-256.
- Per-user random salt, embedded in the hash. Use a tuned work factor.
- Rate limit and lock out by account and by source IP. Monitor enumeration.
- Generic error messages: "invalid credentials", never "no such user".
- Compare secrets in constant time.

**Authorization:**

- Default deny. Check on every request, server side.
- Check the specific object, not just the role. `can(user, "update", postId)`.
- Prefer policies in one place over scattered `if` statements.
- Multi-tenant data: every query filters by tenant id, enforced in the repository layer, and covered by a test that tries to cross tenants.
- Object-level checks (IDOR): never trust an identifier from the client without verifying ownership.

**Sessions and tokens:**

- Cookie: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict`), correct `Path` and `Domain`, short idle timeout plus absolute timeout.
- Rotate the session identifier on privilege change (login, password change, MFA).
- Invalidate server-side on logout. Clearing the cookie alone does not end a stolen session.
- JWTs: verify signature, `exp`, `nbf`, `aud`, and `iss`. Use a strong algorithm and reject `alg: none` and algorithm confusion. Keep them short-lived.
- OAuth/OIDC: validate `state` (CSRF), use PKCE, verify the issuer and audience, pin the JWKS endpoint, never accept an unverified identity claim.

## 5. Cryptography

- Use a vetted, high-level library. Do not implement a cipher, a padding scheme, or a key derivation yourself.
- AEAD (AES-GCM, ChaCha20-Poly1305) for data at rest. Never ECB. Never unauthenticated encryption.
- Randomness from a CSPRNG (`crypto.randomBytes`, `secrets.token_bytes`). Never `Math.random()` for tokens, IDs, or IVs.
- Nonces/IVs are unique per message. Never reuse with the same key.
- Key derivation: HKDF or scrypt/argon2, with a context-specific info string.
- TLS 1.2+ minimum, TLS 1.3 preferred. Verify certificates. Disable weak cipher suites and legacy renegotiation.
- Compare MACs in constant time, before decrypting.
- Keys live in a secret manager or KMS, never in the repository, not in environment files, not in the image.

## 6. Secrets and configuration

- Never commit secrets. Scan for `.env`, `.pem`, `.key`, credential patterns in every diff and every commit.
- Secrets come from the environment, a vault, or a KMS, and are injected at runtime.
- Rotate anything that has ever been committed, logged, or exposed. Deleting the file is not rotation.
- Redact secrets from logs, error messages, and stack traces. A logger that prints the whole request object is a leak.
- Keep separate secrets per environment. A staging credential that works in production is a production credential.
- Have a documented rotation procedure. Undocumented rotation does not happen.

## 7. Dependencies and supply chain

- Lockfile committed. Builds use the lockfile, not floating ranges.
- Prefer a small dependency surface. Every dependency is code you did not write and will inherit updates.
- Review what a new dependency actually pulls in - transitive count matters more than the direct package.
- Audit tools: `npm audit`, `pip-audit`, `cargo audit`, `osv-scanner`, `govulncheck`. Run them in CI on every build.
- Watch for typosquatting and lookalike names when adding packages.
- Pin the base image by digest, and rebuild it on a schedule so base-image CVEs get fixed.
- Do not run untrusted install scripts, and do not pipe a remote script to a shell.

## 8. Web application specifics

See `references/web-app-security.md` for OWASP Top 10 mapped to concrete controls, plus the specific defenses for CSRF, SSRF, XXE, deserialization, path traversal, and open redirects.

Highest-value web controls, in order of how often they are the actual vulnerability:

1. Access control broken (IDOR, missing function-level auth, tenant isolation)
2. Injection (SQL, command, template, NoSQL)
3. XSS and CSRF
4. Broken authentication and session handling
5. SSRF and unsafe URL fetching
6. Sensitive data exposure and missing security headers
7. Missing rate limits on expensive or auth-adjacent endpoints

## 9. Logging, detection, response

- Log security-relevant events: login success and failure, logout, privilege change, password reset, access denied, admin actions, key use. With actor, target, result, source, and a correlation ID.
- Never log secrets, tokens, full request bodies, session IDs, card numbers, or personal data. Redact at the source, not in the log pipeline.
- Alert on: brute force, privilege escalation attempts, unusual access patterns, mass export, key or config change, log tampering.
- Have an incident response path: who is on call, how to rotate credentials quickly, how to revoke sessions, how to notify affected users.
- Keep an audit trail that an attacker with application access cannot quietly edit.

## 10. Report findings properly

When reviewing or auditing, write findings so they can be acted on:

- Severity, with a stated impact in terms of what an attacker gains.
- Location: file, line, and the specific code path.
- Reproduction steps, including the exact request and the preconditions.
- The concrete fix, with code.
- The general pattern it represents, so the same class of bug can be found elsewhere.

Order findings by severity, not by file order. Separate confirmed findings from suspicions. Do not report style issues or theoretical concerns as vulnerabilities, and do not bury a critical finding under a wall of nitpicks.

## Supporting files

- `references/threat-modeling.md` - STRIDE walkthrough, data flow analysis, abuse cases, risk rating.
- `references/secure-coding.md` - vulnerability catalogue by class and language, with fixes.
- `references/web-app-security.md` - OWASP Top 10 controls, CSRF, SSRF, XXE, deserialization, headers.
- `references/auth-session.md` - password storage, cookies, tokens, OAuth, MFA, rate limiting.
- `scripts/secret-scan.sh` - scan a repo for committed secrets and common misconfigurations.
