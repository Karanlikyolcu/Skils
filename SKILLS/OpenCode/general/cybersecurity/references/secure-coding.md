# Secure Coding Reference

## Injection

**SQL injection** - attacker-controlled data concatenated into a query.

```python
# Vulnerable
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# Fixed: parameterized
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

- Parameterize every value. There is no case where string-building SQL is the right answer.
- Identifiers (table names, column names, sort direction) cannot be parameterized. Whitelist them against a fixed set.
- `ORDER BY` direction must be whitelisted: `direction = "ASC" if raw == "asc" else "DESC"`.
- Prefer an ORM or query builder that parameterizes by default, and check that raw escape hatches are not used with user input.
- Least privilege on the DB account: the app's user should not be able to `DROP`, and should have write access only to the tables it needs.

**Command injection**

```python
# Vulnerable
os.system(f"convert {filename} out.png")

# Fixed: argument array, no shell
subprocess.run(["convert", filename, "out.png"], shell=False, check=True)
```

- Never pass user input to a shell. Use `subprocess.run` with a list and `shell=False`.
- On Windows, watch for argument injection through batch files.
- Never use `eval`, `exec`, `Function()` with untrusted input.

**Template injection** - server-side template engines that evaluate expressions can execute code.

**NoSQL injection** - MongoDB: validate that the query value is the expected type. `{"$ne": null}` matches every document. Cast and validate types before querying.

**LDAP / XPath / header injection** - same principle: bind parameters, escape by context, validate structure.

## XSS

- Output encoding for the context. HTML body, attribute, URL, JS string, and CSS each need different encoding.
- Modern frameworks escape by default. The vulnerability appears when someone bypasses it: `dangerouslySetInnerHTML`, `v-html`, `|safe`, `raw()`, `innerHTML`.
- Rich text needs a real sanitizer (DOMPurify, Bleach) with an allowlist of tags and attributes.
- Never interpolate user data into a `<script>` block, an event handler attribute, or a `javascript:` URL.
- Validate URLs before putting them in `href`/`src`. Allow only `https:` (and `http:` where needed), never `javascript:` or `data:`.
- Set `Content-Security-Policy` so an injection has a hard limit.

## CSRF

- The cookie is sent automatically by the browser, so the server cannot tell a forged request from a real one.
- Mitigation: a CSRF token that the server issues and requires on state-changing requests, tied to the session.
- Or: `SameSite=Lax` or `Strict` cookies, which prevent cross-site cookie sending on POST. Defense in depth, not a complete fix (top-level GET navigations are still sent, and older browsers ignore it).
- Never use a GET for a state-changing action.
- Also protect JSON APIs: `Content-Type: application/json` plus a custom header requirement makes simple cross-site form attacks impossible, since forms cannot set custom headers.
- Do not combine a cookie session with a permissive CORS policy that allows credentials.

## Access control

- Default deny. Every protected route has an explicit check.
- Check the object, not just the role. This is the IDOR class and it is the most common serious vulnerability.
- Never trust an identity that arrives in a request header or body. Resolve identity from the session or a verified token.
- Multi-tenancy: filter by tenant in the repository, not in the handler, so it cannot be forgotten.
- Do not leak existence: a user who may not see a record should get the same response as for a record that does not exist.
- Administrative functions get a separate check, not a hidden link.

## Input validation

- Allowlist. Define what is acceptable, not what is not.
- Validate type, length, range, format, and cardinality.
- Normalize before validating: trim, Unicode-normalize, case-fold where appropriate.
- Structured formats need structured parsers. Never regex-parse HTML, XML, or JSON by hand.
- Validate file uploads: content type sniffed from content, not from the client header; size limit; extension allowlist; store outside the web root; rename to a generated name; never execute it.
- Reject unexpected fields on sensitive endpoints to prevent mass assignment.

## Path traversal

- Never join user input into a path with string concatenation.
- Resolve the path and check that it is still inside the allowed root:

```python
resolved = (BASE_DIR / user_input).resolve()
if not resolved.is_relative_to(BASE_DIR):
    raise ValueError("invalid path")
```

- Use an allowlist of known files, or generated IDs that map to paths server-side.
- Do not expose directory listings.

## SSRF

- Any URL the server fetches is an attack surface, including from the server's own network perspective.
- Allowlist schemes (`https` only) and hosts. Block private IP ranges, link-local (`169.254.0.0/16`, which includes the cloud metadata endpoint `169.254.169.254`), loopback, and IPv6 equivalents.
- Resolve DNS and check the resolved IP, not just the hostname (DNS rebinding).
- Disable redirect following, or re-validate every hop.
- Set a timeout and a response size limit.
- Do not let the caller control the port.

## Deserialization

- Never deserialize untrusted data into an object graph (Java `ObjectInputStream`, PHP `unserialize`, Python `pickle`, .NET `BinaryFormatter`).
- Use JSON with a schema, or a safe format with a strict schema.
- If a dangerous format is unavoidable, use an allowlist of permitted classes and enforce it.

## XXE

- Disable external entity resolution in every XML parser (`disallow-doctype-decl`, `FEATURE_SECURE_PROCESSING`, `noent: false`).
- Use JSON or a schema-validated format where possible.

## Race conditions

- TOCTOU: check then act is not atomic. Use a database constraint, an atomic operation, or a lock.
- Use `SELECT ... FOR UPDATE` or optimistic versioning for read-modify-write.
- Make idempotency keys unique in the database, so the uniqueness constraint enforces the check.

## Secrets

- Never in source control, never in images, never in client bundles, never in logs.
- Read from the environment, a secret manager, or a KMS.
- Rotate on a schedule and immediately after any exposure.
- Scan the repository history, not just the working tree. A deleted secret is still in the history.

## Cryptography

- Use a high-level, well-reviewed library and standard algorithms.
- AEAD modes only: AES-GCM, ChaCha20-Poly1305. Never ECB, never CTR without a MAC.
- A fresh nonce per encryption under the same key. Nonces for GCM are usually 12 random bytes.
- CSPRNG for all randomness: `crypto.randomBytes`, `secrets.token_bytes`, `os.urandom`. Never `Math.random()`, `random.random()`, or `rand()`.
- Key derivation with HKDF, scrypt, argon2, or PBKDF2 as appropriate. Never a bare hash.
- Password hashing: argon2id with a tuned memory cost, or bcrypt with a high cost factor.
- Constant-time comparison: `hmac.compare_digest`, `crypto.timingSafeEqual`, `MessageDigest.isEqual`. Never `==` on a secret.
- Verify MACs before decrypting, to avoid padding-oracle style attacks.
- Certificates: verify the chain and the hostname. Never set `verify=False` to "fix" a certificate error.
- TLS 1.2 minimum, 1.3 preferred. Disable SSLv3, TLS 1.0/1.1, and weak ciphers.

## Errors and logging

- Never return stack traces, SQL, or internal paths to the client.
- Log the detail server-side with a request ID; return the request ID to the client.
- Redact secrets and personal data from logs. Redact at the source.
- Do not log full request bodies on authenticated endpoints.
- Log security events with enough context to detect the pattern: actor, target, action, result, source, correlation ID.

## Dependencies

- Lock the dependency graph. Commit the lockfile.
- Audit in CI: `npm audit`, `pip-audit`, `cargo audit`, `govulncheck`, `osv-scanner`.
- Check the transitive count and the install scripts of a new dependency.
- Verify package names and publishers. Typo-squatting is common and effective.
- Pin CI actions by commit SHA, not by tag.
- Rebuild base images regularly so base-image CVEs get patched.

## Language-specific quick reference

**Python**: use `secrets` for tokens, `hmac.compare_digest` for comparisons, `bandit` for static analysis, `pip-audit` for CVEs, parameterize with the DB driver's placeholder syntax, and never use `pickle` on untrusted data.

**JavaScript / TypeScript**: `crypto.randomBytes` for randomness, `crypto.timingSafeEqual` for comparisons, `helmet` for headers, `zod` or `joi` for validation, `node --experimental-permission` or a sandbox for untrusted code, and never `eval`.

**Java / Kotlin**: `SecureRandom` not `Random`, `MessageDigest.isEqual` for comparisons, JPA with parameterized queries, `XMLInputFactory` with external entities disabled, and a `SecureRandom`-based `CSPRNG` for tokens.

**Go**: `crypto/rand` for randomness, `subtle.ConstantTimeCompare` for comparisons, `html/template` (not `text/template`) for HTML, parameterized SQL, and `gosec` for static analysis.

**C / C++**: no overflows (use safe integer functions), no `strcpy`/`sprintf` (`strncpy`/`snprintf` with bounds, or better, safer string handling), and explicit frees with no double free.
