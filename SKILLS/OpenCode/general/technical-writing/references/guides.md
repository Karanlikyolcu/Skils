# READMEs, Tutorials, How-tos, and Runbooks

Four document types, four different jobs. Mixing them is the most common documentation failure.

| Type | Reader's job | Structure |
|------|---------------|-----------|
| README | Understand what this is and get it running | What, why, quick start, layout, links |
| Tutorial | Learn by doing | A goal, steps that build something working, checkpoints |
| How-to | Complete a specific task | Prerequisites, numbered steps, verification |
| Runbook | Fix it now, under pressure | Symptom, diagnosis, mitigation, escalation |

## README

```markdown
# orders-service

Handles order creation, payment capture, and fulfillment. Owns the `orders`
table and publishes `orders.created` to the event bus.

## Quick start

```bash
docker compose up -d
curl localhost:8080/healthz
```

Requires Docker and a Postgres 16 instance. See `docs/setup.md` for a
non-Docker setup.

## Why this exists

Order state was previously duplicated across the checkout and fulfillment
services, which produced inconsistent totals. This service is the single
owner of order state.

## Layout

| Path | Contents |
|------|----------|
| `src/api` | HTTP handlers |
| `src/domain` | Business rules |
| `src/data` | Repositories and the database schema |
| `migrations/` | Database migrations |
| `tests/` | Test suite |

## Commands

| Command | Does |
|---------|------|
| `make dev` | Run with hot reload |
| `make test` | Run the test suite |
| `make lint` | Lint and typecheck |
| `make migrate` | Apply pending migrations |

## Documentation

- [Setup](docs/setup.md)
- [API reference](docs/api.md)
- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)

## Contributing

See `CONTRIBUTING.md`.
```

Rules:
- The first screen tells the reader **what this is** and **whether it is what they are looking for**.
- The quick start must actually work from a clean checkout, and must be tested in CI.
- Do not put a full tutorial in the README. Link to it.
- Do not put a feature list. The reader wants to know what it does, not what it might do.

## Tutorial

A tutorial teaches by having the reader build something that works. It is a learning path, not a reference.

```markdown
# Tutorial: build your first order API

In this tutorial you will build a small order service in Python. By the end
you will have a working API, a database, and a test.

## What you will build

- A `POST /orders` endpoint that validates input and stores an order
- A SQLite database with a migration
- A test that covers the happy path and one validation failure

## What you need

- Python 3.12 or newer
- curl
- About 30 minutes

## Step 1: create the project

```bash
mkdir orders-api && cd orders-api
python -m venv .venv && source .venv/bin/activate
```

Check it worked:

```bash
python --version    # expect Python 3.12.x
```

## Step 2: add the endpoint
...
```

Rules:
- **Every step produces a working state.** The reader can stop after any step and the code runs.
- **Show the expected output** after each step, so the reader knows it worked.
- **Explain the why, briefly.** A tutorial is the one place where the reasoning belongs in the prose.
- **Start with something that runs.** The first step produces visible output, because a reader who has seen it work will keep going.
- Do not use placeholders. Every line in every code block is real.
- End with what was built and where to go next.

## How-to guide

A how-to completes one task for someone who already has the context.

```markdown
# How to: rotate a database credential

Rotates the `orders-db` password in Vault and updates the running service.

## Prerequisites

- `vault` CLI authenticated (`vault status`)
- Access to the `orders` namespace
- The service is deployed on Kubernetes (check: `kubectl get deploy orders`)

## Steps

### 1. Generate a new password

```bash
vault read -field=password database/creds/orders-db-rotating > /tmp/newpass
```

The credential is write-once. If you lose it, generate another.

### 2. Update the database user

```bash
psql "$DATABASE_URL" -c "ALTER USER orders WITH PASSWORD '$(cat /tmp/newpass)';"
```

### 3. Update Vault

```bash
vault kv put secret/orders/db password="$(cat /tmp/newpass)"
```

### 4. Roll the deployment

```bash
kubectl rollout restart deployment/orders
kubectl rollout status deployment/orders --timeout=2m
```

### 5. Verify

```bash
curl -fsS localhost:8080/healthz
psql "$DATABASE_URL" -c "SELECT 1"
```

Expected: `{"status":"ok"}` and a row of `1`.

## Rollback

The old password is still valid until the database user is changed. To roll
back, repeat steps 2 to 4 with the previous credential from Vault's version
history.

## Troubleshooting

**The deployment does not become ready**
`kubectl logs deployment/orders -c orders --tail=50`. A `password authentication
failed` error means the secret did not propagate; check step 3.
```

Rules:
- **Prerequisites first.** Not as a surprise at step 4.
- **One action per step.**
- **Verification at the end**, with the expected output.
- **A rollback section.** If there is none, say so explicitly.
- **Troubleshooting for the likely failures**, not for everything.
- Mark destructive steps clearly and say what is irreversible.

## Runbook

Written for the person who has never seen the system, at the worst moment of their life.

```markdown
# Runbook: orders-service latency above 2s

## Symptom

The `OrdersLatencyBurn` alert fires, or users report the checkout is slow.

## Impact

Customers see the checkout take more than 2 seconds. Orders are still
completing.

## Diagnosis

Work down this list; stop when you find the cause.

### 1. Is it the database?

```bash
kubectl exec deploy/orders -- psql "$DATABASE_URL" -c \
  "select query, calls, mean_exec_time from pg_stat_statements
   order by mean_exec_time desc limit 5;"
```

A single query with a high mean execution time is the cause.

### 2. Is it a dependency?

```bash
kubectl logs deployment/orders --since=15m | grep -o '"dependency":"[^"]*"' | sort | uniq -c
```

### 3. Is it the service itself?

```bash
kubectl top pods -l app=orders
kubectl logs deployment/orders --since=15m | grep '"duration_ms"' | tail -50
```

## Mitigation

**If the database is the cause** (most common):

```bash
kubectl exec deploy/orders -- psql "$DATABASE_URL" -c "select pg_cancel_backend(pid) from pg_stat_activity where state = 'active' and query_start < now() - interval '30 seconds';"
```

**If a dependency is failing:**

```bash
kubectl scale deploy/orders --replicas=6
```

**If the service is CPU-bound:**

```bash
kubectl scale deploy/orders --replicas=6
```

**If none of the above works:**

Disable the slow path behind the `checkout_v2` flag and enable `checkout_v1`.
This degrades functionality but restores checkout speed.

## Escalation

- Database team: `#db-oncall`, page `db-primary`
- Payments provider: https://status.example-payments.com

## Verification

- p95 latency below 800 ms for 10 minutes
- Error rate below 0.1%
- `kubectl get endpoints orders` shows all replicas ready
```

Runbook rules:
- Start with the symptom and the impact, in the words a user would describe.
- The diagnosis steps are ordered by likelihood, and each one is a single command with the expected interpretation stated.
- The mitigation options are ordered by speed and risk, and the cheapest safe one is first.
- Every runbook ends with verification.
- Escalation contacts are current. A stale contact makes the runbook worse than nothing.

## Tutorials vs how-tos

| | Tutorial | How-to |
|---|---------|---------|
| Goal | Learn the system | Complete a task |
| Reader | New to the system | Already knows the system |
| Explanation | Included, briefly | Assumed |
| Length | Long | Short |
| Success | The reader understands and can build something new | The task is done |
| Structure | Linear, building up | Direct, minimal preamble |

A document that is mostly explanation is a tutorial. A document that is mostly steps is a how-to. If you cannot tell which one you are writing, decide first.

## Documentation index

Every project needs one page that links everything, so a reader does not have to guess where a document lives.

```markdown
# Documentation

## Start here
- [Setup](setup.md)
- [Architecture](architecture.md)

## Reference
- [API reference](api.md)
- [Configuration](configuration.md)

## Operations
- [Runbook](runbook.md)
- [Deploying](deploy.md)

## Development
- [Contributing](../CONTRIBUTING.md)
- [Testing](testing.md)
```

Group by the reader's situation, not by the document type. "I am on call" is a better grouping than "reference documents".
