---
name: DevOps
description: Use for delivery and operations work - CI/CD pipelines, Docker images, Kubernetes and container orchestration, infrastructure as code, cloud configuration, secrets and environment promotion, monitoring and alerting, log aggregation, deployment strategies, database migrations in production, and incident response and runbooks.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# DevOps

Delivery is a pipeline and operations is a feedback loop. This skill covers both: how a change gets to production safely, and what you do when production misbehaves.

## 1. The pipeline

Every commit travels the same path:

```
commit -> lint/typecheck -> unit test -> build -> integration test -> package -> deploy staging -> smoke test -> deploy production -> verify
```

Principles:

- **Every gate fails the build.** A warning that does not fail will be ignored within a month.
- **Fast gates first.** Lint and typecheck cost seconds; a full E2E suite costs minutes. Order by cost.
- **Build once, promote the same artifact.** Never rebuild between staging and production. What you tested is what ships.
- **Artifacts are immutable.** Tag with the commit SHA, not a moving tag.
- **The pipeline is code.** Versioned, reviewed, and tested like application code.
- **No manual steps in the release path.** A checklist that only one person knows is a single point of failure.

## 2. Infrastructure as code

- Everything is declarative: Terraform, Pulumi, CloudFormation, Crossplane, Helm, Kustomize.
- No manual console changes. A console change is invisible to the next `apply` and will be reverted or cause a drift.
- **Drift detection** in CI: detect when the live infrastructure differs from the code.
- Plan before apply. Read the plan; a destructive change must be reviewed.
- Module or reuse patterns for anything used more than once. Copy-pasted Terraform is how drift starts.
- State is stored remotely, encrypted, and locked. Never in a CI artifact.
- Tag or label everything with the owner and the environment, so orphan resources can be found.

## 3. Containers

**Image hygiene**

- Multi-stage build: compile in one stage, ship only the runtime artifacts in the final image.
- Distroless or a minimal base (`alpine`, `gcr.io/distroless/static`, `scratch`). Smaller image, smaller attack surface.
- Run as a non-root user. Add a `USER` directive.
- Never run a container as privileged, and never mount the Docker socket.
- No secrets in the image. Not in an ENV, not in a layer, not in a COPY.

**Determinism**

- Pin the base image by digest, not by a floating tag.
- Install dependencies from the lockfile, with `--no-install-recommends`.
- Do not run `apt-get upgrade` in a Dockerfile. It makes builds non-reproducible. Rebuild the base image instead.
- No network access during build if you can avoid it, so a compromised dependency cannot exfiltrate.

**Layering**

- Copy the dependency manifest first, install dependencies, then copy the source. The dependency layer is cached until the manifest changes.
- Combine commands with `&&` so a failed step fails the layer.
- Clean up in the same layer as the install.

**Runtime**

- One concern per container. Do not run the app and a database in one image.
- Mount the configuration, not bake it in.
- Declare `HEALTHCHECK`, `EXPOSE`, and resource requests and limits.
- Logs go to stdout/stderr, unbuffered. The platform collects them.
- The process must handle `SIGTERM` and exit gracefully, so a rolling deploy does not cut requests.

## 4. Kubernetes

**Deployment**

- `Deployment` for stateless services, `StatefulSet` for stateful ones, `CronJob` for scheduled work, `Job` for one-off tasks.
- Requests and limits on every container. No limits means one pod can starve the node.
- `PodDisruptionBudget` for anything that must stay up during a node drain.
- `readinessProbe` and `livenessProbe` both, and different. Readiness gates traffic; liveness restarts a stuck process. A liveness probe that runs the same heavy check as readiness causes restart storms.
- `startupProbe` for slow-starting apps, so liveness does not kill them during boot.

**Configuration and secrets**

- `ConfigMap` for non-sensitive configuration, `Secret` for sensitive values. A `Secret` is base64-encoded, not encrypted; enable encryption at rest in etcd.
- Prefer an external secret manager (Vault, AWS Secrets Manager, GCP Secret Manager, Sealed Secrets) over manifests holding secrets.
- Never put secrets in the image, in a ConfigMap, or in a git repo.
- Environment variables for simple values; mounted files for large ones. Environment variables leak into crash dumps and `/proc`.

**Networking**

- A `Service` for stable addressing, `Ingress` for HTTP routing.
- NetworkPolicy to restrict which pods may talk to which. Default deny, then allow explicitly.
- TLS at the ingress, with cert-manager for renewal.
- Readiness gates traffic removal, so a rolling update never sends traffic to an unready pod.

**Safe changes**

- `kubectl apply`, not `edit`. Anything changed by hand disappears on the next apply.
- `rollout status` and `rollout undo` are your tools.
- Set `maxSurge` and `maxUnavailable` deliberately. `maxUnavailable: 0` with a `maxSurge` requires capacity for the extra pod.
- Dry-run server-side first: `kubectl apply --dry-run=server`.
- Keep the previous version deployable. The new schema must be backward compatible with the old code during the rollout.

## 5. Deployment strategies

| Strategy | How | Use when |
|----------|-----|----------|
| Rolling | Replace pods gradually | Stateless services, backward compatible changes |
| Blue/green | Two full environments, switch traffic | Instant rollback, needs 2x capacity |
| Canary | Small traffic share, ramp up | Need real production metrics before full rollout |
| Recreate | Stop all, then start all | Stateful, single-instance, or a breaking migration |

- A **breaking change** needs expand/contract: ship the additive version first, migrate, then remove.
- Database migrations run as a separate step, before the new code serves traffic, and must be backward compatible with the currently running version.
- **Feature flags** let you decouple deploy from release. A flag that requires a deploy to turn off is not a kill switch.

## 6. Environments and promotion

- Environments: development, staging, production. Each with its own accounts, data, and secrets.
- The same artifact is promoted through all of them. Only configuration differs.
- Staging uses production-like data shapes but **never production personal data**. If it must, it is masked or synthetic.
- Production changes are auditable: who deployed what, when, and which commit.
- Access to production is time-bound and logged. A permanent admin account for everyone is not acceptable.

## 7. Configuration and secrets

- Twelve-factor style: config from the environment, not from the code.
- Validate configuration at startup and refuse to boot with a missing required value. A missing env var should fail in CI, not in production at 3am.
- Secrets from a secret manager, rotated on a schedule, and immediately after any exposure.
- Never log secrets. Redact at the source, not in the log pipeline.
- A secret that was ever in a log, a repo, or an image is compromised. Rotate it, then remove it.

## 8. Observability

**Metrics**

- The four golden signals: latency, traffic, errors, saturation.
- Percentiles, not averages. p50, p95, p99. An average hides the users having a bad time.
- Business metrics alongside technical ones.
- Alert on symptoms users feel, not on causes (CPU is high, but users do not care until latency rises).

**Logs**

- Structured JSON, one object per event.
- Fields: timestamp, level, message, service, environment, version, request ID, actor, error.
- Propagate the request ID across every hop, and return it to the client so a user report is traceable.
- Never log secrets, tokens, session IDs, personal data, or full request bodies.
- Use log levels deliberately. At `info` in production, `debug` is off and `error` is rare and actionable.

**Tracing**

- Distributed tracing across service boundaries, with context propagated through HTTP headers and message headers.
- Trace the slow request, not just the slow service. A span per meaningful operation.

**Dashboards and alerts**

- One dashboard per service: request rate, error rate, latency percentiles, and dependency health.
- Alerts must be actionable and tied to a runbook. An alert nobody can act on trains people to ignore alerts.
- Every alert has an owner and a runbook link.
- Alert on symptoms (error rate, p99 latency) with a burn-rate threshold, not on static thresholds.

## 9. Incident response

**During an incident**

1. **Stabilize first.** Roll back, disable a feature flag, or scale up. Do not debug while the bleeding continues.
2. **Establish the timeline.** What changed, when, and what is the blast radius.
3. **Communicate.** Post an update, even if it is "still investigating". Silence is worse than an incomplete answer.
4. **Mitigate, do not diagnose.** The full root cause comes later, after the user is unblocked.

**After**

- Write a blameless postmortem: timeline, impact, contributing factors, root cause, action items with owners and dates.
- Focus on the system, not the person. "The deploy was not gated on the error rate" is actionable. "Someone pushed a bad commit" is not.
- Action items must be concrete and owned. A postmortem with no follow-up is a press release.
- Track the action items to completion.

**Runbooks**

- A runbook per alert: what it means, how to diagnose it, the exact commands, and how to mitigate.
- Written for the person who has never seen the system before.
- Tested. A runbook that has never been followed is a guess.

## 10. Things to get right

- **Backups exist and are tested.** A backup that has never been restored is not a backup. Test the restore quarterly.
- **The database is the hardest thing to change.** Expand/contract, backfill in batches, and never run a long-running migration in the deploy path.
- **Rollback is possible.** The previous version can be redeployed, and the data is backward compatible with it.
- **Feature flags have an owner and an expiry.** A flag that outlives its feature becomes permanent complexity.
- **Cost is a signal.** Alert on unexpected spend growth. A runaway cron job is an incident waiting to happen.

## Supporting files

- `references/cicd.md` - pipeline design, build gates, caching, artifacts, matrix builds, promotion.
- `references/containers.md` - Dockerfile best practices, image size, multi-stage, runtime hardening.
- `references/kubernetes.md` - workloads, probes, resources, config, networking, safe operations.
- `references/observability.md` - metrics, logs, traces, dashboards, alerting, SLOs.
- `references/incident-response.md` - mitigation, postmortems, runbooks, on-call practice.
