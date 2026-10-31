# Observability

## The three pillars and what each answers

| Pillar | Answers | Cost |
|--------|---------|------|
| Metrics | Is it happening, and how much? | Low |
| Logs | What exactly happened? | Medium |
| Traces | Where did the time go, across services? | High |

Use all three, but know that logs answer "what" and traces answer "where". Neither tells you "how many users are affected" as directly as metrics do.

## Metrics

**The four golden signals**

| Signal | Metric | Why |
|--------|--------|-----|
| Latency | p50, p95, p99 of request duration | Percentiles, not averages |
| Traffic | requests/second, messages/second | Demand and capacity |
| Errors | error rate by type | Whether users are affected |
| Saturation | CPU, memory, queue depth, connection pool usage | How close to the limit |

- **Percentiles, not averages.** An average of 100 ms hides that 1% of requests take 10 s. Track p50, p95, p99.
- **Bucket the histogram.** A single duration metric loses the distribution.
- **Label carefully.** Every unique label combination is a new time series. Cardinality explosion is the most common metrics bill.
- **Rate and counter, not gauge, for most things.** Counters and rates aggregate correctly across instances. Gauges do not.
- **Business metrics alongside technical ones.** "Checkout success rate" is what leadership cares about.

**Prometheus conventions**

```promql
# request rate by status
sum(rate(http_requests_total[5m])) by (status)

# error ratio
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# p99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# saturation: pool in use
sum(db_pool_in_use) / sum(db_pool_max)
```

## Logs

**Structure**

```json
{
  "timestamp": "2026-01-14T10:22:31.442Z",
  "level": "error",
  "message": "payment capture failed",
  "service": "checkout",
  "version": "1.4.2",
  "env": "production",
  "request_id": "req_01H...",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "user_id": "u_8821",
  "order_id": "o_5591",
  "error": { "type": "GatewayTimeout", "message": "upstream did not respond in 2000ms" },
  "duration_ms": 2001
}
```

- JSON, one object per event. A key-value line is harder to query and breaks on a delimiter inside a message.
- Always: timestamp, level, message, service, version, environment.
- Always: request ID and trace ID where available.
- **Log the error object, not just a message.** The stack and the type are the useful part.
- Use the exception's structured fields (cause chain, HTTP status, provider error code).

**Levels**

| Level | Use for | Volume |
|-------|---------|--------|
| `error` | The operation failed and someone may need to act | Rare and actionable |
| `warn` | Degraded but handled | Occasional |
| `info` | Business-significant events | Moderate |
| `debug` | Diagnostic detail | Off in production |

- `error` in production must be actionable. If nobody reacts to it, it is a `warn`.
- Do not log at `error` for a client mistake. A 400 from a bad request is not an error.

**Never log**

- Passwords, tokens, API keys, session IDs, cookies, Authorization headers.
- Personal data beyond what is needed. Hash or redact user identifiers where possible.
- Full request bodies on authenticated endpoints.
- Card numbers, in any form.

**Sampling**

- Sample high-volume successful requests. Never sample errors.
- Sample per route, not per message, so a route's sample is coherent.
- Keep 100% of anything at `warn` and above.

## Tracing

- A trace is one request end to end. A span is one operation within it.
- Propagate the trace context through HTTP headers (`traceparent`) and message headers.
- Instrument the boundaries: inbound request, outbound call, database query, queue publish.
- Name spans with the operation and the target: `GET /orders`, `SELECT orders`, `POST payments`.
- Record attributes: the order ID, the customer tier, the cache hit. Not the whole payload.
- Sample a percentage of successful traces and 100% of errors.

## Dashboards

One dashboard per service. Top row, so it answers the first question:

- Request rate
- Error rate
- p95 and p99 latency
- Saturation of the scarcest resource

Then the detail: dependency latency, queue depth, cache hit rate, business counters.

- Link a dashboard from the runbook for each alert.
- A dashboard nobody opens is a dashboard nobody maintains.

## Alerting

**Alert on symptoms, with a burn rate.**

```yaml
# multi-window burn rate: 5% of traffic failing for 1h, or 2% for 6h
- alert: CheckoutErrorBudgetBurn
  expr: |
    (
      sum(rate(http_requests_total{job="checkout",status=~"5.."}[1h])) / sum(rate(http_requests_total{job="checkout"}[1h])) > 14.4*0.001
      and
      sum(rate(http_requests_total{job="checkout",status=~"5.."}[5m])) / sum(rate(http_requests_total{job="checkout"}[5m])) > 14.4*0.001
    )
  for: 2m
```

- **Page on user impact**, not on a threshold. A 5% error rate on a low-traffic service matters less than 0.1% on a high-traffic one.
- **Burn rate** alerts tie the threshold to the error budget, so they fire early and stop firing when the budget recovers.
- Every page has an owner, a runbook, and a severity.
- **Warning alerts** go to a ticket or a dashboard, not to a phone.

**SLOs**

- Define an SLI (a measured thing), an SLO (a target for it), and an error budget (the allowed failure).
- Start with availability and latency for the critical path. Do not define fifty SLIs.
- Track the budget burn rate on a dashboard even when there is no alert.

## Logging infrastructure

- **journald** on systemd hosts: `journalctl -u <svc> --since "1 hour ago" -p err`.
- **logrotate** for file logs: daily or weekly, compress, keep N rotations, `copytruncate` for apps that do not reopen the file.
- **Ship to a central system** (Loki, Elasticsearch, Splunk) so logs survive the host and can be correlated across services.
- A container that writes to a file writes to a layer that fills the disk. Log to stdout/stderr.
- Set a retention policy. Logs are not a permanent archive, and they contain personal data.

## Common anti-patterns

- A dashboard with 40 graphs and no hierarchy.
- Alerts on CPU, memory, and disk utilisation with no user impact.
- Averages instead of percentiles.
- Log messages without any identifier, so nothing can be correlated.
- Logging at `info` everything, then nobody reads it.
- High-cardinality labels (user ID, request ID) in metrics. Use them in logs and traces.
