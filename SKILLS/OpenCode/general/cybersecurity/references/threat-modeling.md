# Threat Modeling

A threat model is a short document that answers: what are we protecting, who could attack it, and what stops them. It takes 20 minutes and prevents weeks of rework.

## When to do it

- Before implementing a new feature that handles sensitive data, money, or identity.
- Before a design that crosses a new trust boundary (new service, new integration, new storage).
- Before an architectural change that alters the security model.
- After a security incident or a significant new attack technique.

Do not do it for every change. Do it when the answer would change what you build.

## Step 1: Scope and assets

Define what you are modeling. One system, one workflow. "The whole platform" produces a useless document.

List the assets and their value:

| Asset | Value to the attacker | Impact if lost |
|-------|---------------------|----------------|
| Credentials | Take over accounts | Account takeover, fraud |
| Personal data | Identity theft, blackmail | Legal liability, user harm |
| Payment data | Direct theft | Direct financial loss |
| Business data | Competitive advantage | Loss of revenue |
| Availability | Denial of service | Revenue loss, reputation |

## Step 2: Draw the data flow

For each flow, list the actors, the components, and the data that moves.

```text
[User] --HTTPS--> [Web App] --SQL--> [Database]
                  |
                  +--HTTPS--> [Payment API]
                  +--SMTP-->   [Email Service]
```

Mark each boundary with the protocol and whether it is authenticated and encrypted.

```text
[User] --HTTPS/1.1--> [API Gateway] --TLS1.3--> [Service]
                          |
                    [No auth on internal hop]  <-- finding
```

## Step 3: STRIDE per element

Apply these six questions to each element and each flow.

| Threat | Question | Typical mitigation |
|--------|----------|-------------------|
| **S**poofing | Can someone pretend to be an actor? | Strong auth, mTLS, signed tokens |
| **T**ampering | Can data be modified in transit or at rest? | TLS, signatures, integrity checks, DB constraints |
| **R**epudiation | Can someone deny having done an action? | Audit logs, non-repudiable signatures |
| **I**nformation disclosure | Can data leak to the wrong party? | Authorization, encryption, minimal data, redaction |
| **D**enial of service | Can the system be made unavailable? | Rate limits, quotas, caching, timeouts |
| **E**levation of privilege | Can a user gain rights they should not have? | Authorization checks, least privilege, sandboxing |

Walk it per trust boundary, not per component. The interesting threats live at the boundaries.

## Step 4: Abuse cases

Walk through the flow as an attacker. Ask "what if this step were malicious?"

- What if the client sends a different `userId` than the one it displays?
- What if the client sends `role=admin` in the request body?
- What if the client replays a payment request 100 times?
- What if the client requests 1,000,000 records in one page?
- What if the client uploads a 10 GB file?
- What if the client sets `X-User-Id` directly?
- What if the client calls the internal service directly, bypassing the gateway?
- What if the redirect URL points to an attacker domain?
- What if the token is expired but the client keeps sending it?

Write these as concrete abuse cases with a trigger, an impact, and a likelihood.

## Step 5: Mitigations

For each threat, choose a control and note where it lives:

| Control type | Where |
|--------------|-------|
| Code | The application enforces it |
| Configuration | TLS settings, headers, CORS, rate limits |
| Infrastructure | WAF, network policy, IAM, secrets manager |
| Process | Code review, dependency scanning, penetration testing |

Prefer controls that do not depend on every developer remembering. A database constraint beats a code check. A gateway policy beats a handler check.

## Step 6: Rate the risk

Use likelihood × impact on a simple scale.

```text
Risk = Likelihood (1-5) x Impact (1-5)

1-4   Low       Accept, note it
5-9   Medium    Mitigate in this cycle
10-16 High      Must fix before release
17-25 Critical  Blocker
```

Adjust for existing controls and for detection: a threat with no alerting is worse than one with an alert.

Also record **residual risk** after the control, and **accepted risk** with the name of the person who accepted it. Accepted risk is a decision; unrecorded risk is an oversight.

## Threat model template

```markdown
# Threat Model: <feature or flow>

Date: <date>
Owner: <name>
Status: Draft | Accepted | Outdated

## 1. Scope
What is in scope. What is explicitly out of scope.

## 2. Assets
| Asset | Value | Impact of loss |

## 3. Data flow
The diagram, with trust boundaries marked.

## 4. Actors
| Actor | Trust level | Capabilities |

## 5. Threats
| # | Element | STRIDE | Threat | Mitigation | Control location | Residual risk |

## 6. Abuse cases
| # | Trigger | Impact | Likelihood | Mitigation |

## 7. Accepted risks
| Risk | Rationale | Accepted by | Review date |

## 8. Review trigger
What change would invalidate this model.
```

## Rules of thumb

- Threat model the design, not the code. Code-level bugs get patched; design-level flaws get re-designed.
- Do not write a document nobody reads. Two pages that inform a decision beats twenty pages in a wiki.
- A threat model is not a security guarantee. It is a structured way to avoid obvious misses.
- Update it when the design changes. A stale threat model is worse than none, because it gives false confidence.
