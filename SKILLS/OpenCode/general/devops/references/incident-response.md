# Incident Response

## The first ten minutes

1. **Acknowledge.** Respond to the alert. An unacknowledged alert means nobody is looking.
2. **Assess impact.** How many users, which regions, since when. This decides severity.
3. **Stabilize.** Roll back, disable a feature flag, scale up, fail over, shed load. Do not debug while the bleeding continues.
4. **Communicate.** Post an update even if it is "investigating". Silence is worse than an incomplete answer.
5. **Preserve evidence** before making changes: capture logs, metrics, and a snapshot of the current state.

The order matters. Stabilize before diagnose. Diagnose before optimize.

## Severity

| Severity | Definition | Response |
|----------|------------|----------|
| SEV1 | Full outage, data loss, or a security breach | Page immediately, all hands, status page, exec notified |
| SEV2 | Major degradation, a subset of users, a broken critical flow | Page, respond within 15 min |
| SEV3 | Minor degradation, a workaround exists | Business hours, ticket |
| SEV4 | Cosmetic or internal | Normal backlog |

Every incident has one **incident commander**. The commander coordinates and does not debug. Separate roles for mitigation, investigation, and communication.

## Mitigation options, cheapest first

| Option | Speed | Risk | Reversibility |
|--------|-------|------|---------------|
| Disable a feature flag | seconds | low | instant |
| Roll back the last deploy | minutes | medium | redeploy |
| Scale up capacity | minutes | low | scale back |
| Fail over to the secondary region | minutes | high | fail back |
| Restart a service | minutes | low | n/a |
| Rate limit the endpoint | minutes | medium | raise the limit |
| Emergency config change | minutes | high | revert |
| Full rollback of a migration | hours | high | n/a |

Always ask: **what is the fastest change that reduces user impact, and how do we undo it?**

## Communication

**During the incident**

- A single channel, and a single source of truth (an incident doc).
- Post updates every 15-30 minutes, even when there is no change. "Still investigating, next update in 15 min" is a valid update.
- State impact in user terms, not internal terms. "Checkout is failing for 30% of users" beats "the payments pod is crash-looping".
- Do not speculate about the cause in the public channel.

**Status page** (SEV1/SEV2): post an initial notice within 15 minutes of confirming impact, update it as information arrives, and resolve it only when impact is over.

**After**: notify the affected users directly if the impact was material or data was involved.

## Postmortem

Blameless. The question is how the system allowed it, not who made the mistake.

```markdown
# Postmortem: 2026-01-14 checkout latency outage

- Severity: SEV2
- Duration: 43 minutes (14:02 to 14:45 UTC)
- Customer impact: 31% of checkout requests failed; ~2,400 orders lost
- Incident commander: <name>
- Participants: <names>

## Summary

A configuration change increased the database connection pool timeout. Under
traffic, connections were held open past the timeout, exhausting the pool and
causing checkout requests to fail for 43 minutes.

## Timeline

| Time (UTC) | Event |
|-------------|-------|
| 14:02 | Config change `POOL_TIMEOUT=5s` deployed via canary (25% traffic) |
| 14:04 | p99 latency alert on checkout fired; dismissed as a blip |
| 14:09 | Canary reached 100% traffic (auto-promote did not wait for SLO check) |
| 14:11 | Error rate alert fired, SEV2 declared |
| 14:14 | Root cause identified: pool exhaustion from the timeout change |
| 14:18 | Rollback started; failure continued during rollout |
| 14:31 | Rollback complete; error rate returned to baseline |
| 14:45 | Confirmed stable for 15 minutes; incident resolved |

## Impact

31% of checkout requests returned 503 for 43 minutes. Approximately 2,400
orders were not created. No data was lost or corrupted. 14 support tickets
were received.

## Root cause

The connection pool timeout was reduced from 30s to 5s to address a separate
slow-query alert. Under normal load, 5s was below the time required for the
longest legitimate transaction, so connections were returned late and the pool
exhausted.

The canary promotion did not gate on the latency SLO, so the change reached
all traffic before the effect was visible.

## Contributing factors

- The promotion gate checked only for errors, not latency.
- The initial latency alert was dismissed without checking the deploy that had
  just completed.
- No test covered the pool timeout configuration under load.

## What went well

- Error rate alerting detected the issue within 7 minutes of full rollout.
- The rollback was straightforward and took 13 minutes.
- The on-call engineer had runbooks for both services.

## What did not go well

- The latency alert was dismissed. Dismissal should require a reason.
- The promotion gate was insufficient for a performance-sensitive change.

## Action items

| Action | Owner | Due | Priority |
|--------|-------|-----|----------|
| Add latency SLO gating to canary promotion | <name> | 2026-01-21 | P1 |
| Add a load test covering the pool timeout range | <name> | 2026-01-28 | P1 |
| Require a reason when dismissing an alert | <name> | 2026-02-04 | P2 |
| Document the pool timeout sensitivity in the runbook | <name> | 2026-01-21 | P2 |

## Detection improvements

- Add an error-budget burn rate alert for checkout.
- Add a connection pool saturation metric with a threshold below 80%.
```

### Rules for postmortems

- **Action items must be specific, owned, and dated.** "Improve monitoring" is not an action item.
- **Separate cause from contributing factors.** The cause triggered it; the contributing factors let it happen and let it last.
- **Record what went well.** It tells the team what to preserve.
- **Blameless means system-focused, not name-free.** "The deploy was not gated on latency" is fine. "Someone pushed a bad config" is not.
- **Track the action items to completion.** An untracked postmortem is theatre.
- Review the postmortem with the whole team within two weeks, while the memory is fresh.

## Runbooks

A runbook is written for the person who has never seen the system, at the worst moment of their life.

```markdown
# Runbook: checkout error rate above 5%

## Symptom
The `CheckoutErrorBudgetBurn` alert fires, or users report failed checkouts.

## Impact
Customers cannot complete a purchase.

## Diagnosis

1. Check the recent deploys:
   `kubectl rollout history deployment/checkout`
2. Check the error breakdown by status and endpoint:
   `kubectl logs -l app=checkout --since=15m | grep -o '"status":[0-9]*' | sort | uniq -c`
3. Check dependency health:
   `kubectl exec deploy/checkout -- pg_isready -h $DB_HOST`
4. Check the connection pool metric in the dashboard.

## Mitigation

**If the last deploy is the cause** (most common):
```sh
kubectl rollout undo deployment/checkout
kubectl rollout status deployment/checkout --timeout=5m
```

**If a dependency is failing:**
```sh
kubectl scale deployment/checkout --replicas=6   # add capacity to the healthy region
```

**If the pool is exhausted:**
Scale the database, or reduce traffic with a rate limit on the checkout route.

**If none of the above works:**
Disable checkout and show a maintenance message. Better than a broken checkout.

## Escalation
- Database team: #db-oncall
- Payments provider issue: <link to the provider status page>

## Verification
- Error rate below 0.5% for 15 minutes.
- `kubectl get endpoints checkout` shows all replicas ready.
- A test checkout completes successfully.
```

## Preventing recurrence

- **Alert on the cause, not only the symptom.** A pool saturation metric would have caught this before the error rate.
- **Test the deployment gate.** The promotion rule failed. Fix the rule.
- **Automate the mitigation.** A rollback that takes 13 minutes should take 1.
- **Track recurrences.** If the same incident happens twice, the postmortem action items were not done.

## Common mistakes

- Debugging during the outage instead of mitigating first.
- One person doing everything: commander, debugger, and communicator.
- No communication. Stakeholders assume silence means nobody is working.
- Rolling back a database change without checking whether the previous code is compatible with the new schema.
- Blame in the postmortem, so people stop reporting issues.
- A postmortem with 20 action items and no owners. Nothing gets done.
