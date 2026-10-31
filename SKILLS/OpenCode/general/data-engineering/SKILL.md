---
name: Data Engineering
description: Use for data platform work - Kafka and streaming pipelines, batch orchestration with Airflow or Dagster, Spark jobs, warehouse and dimensional modeling, dbt transformations, data quality and validation, schema evolution, CDC, data contracts, idempotent and exactly-once processing, partitioning, and backfills.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Data Engineering

Data pipelines fail in ways application code does not: they fail silently, they produce wrong numbers, they double-count, and they are late. This skill is about producing data that other people trust.

## 1. The contract first

Every dataset needs a contract before it is built.

```yaml
name: orders_enriched
owner: data-platform
description: Orders joined with customer and product attributes.
grain: one row per order
primary_key: [order_id]
schema:
  - {name: order_id,        type: string,    required: true}
  - {name: customer_id,     type: string,    required: true}
  - {name: order_total_cents, type: integer, required: true}
  - {name: currency,        type: string,    required: true}
  - {name: ordered_at,      type: timestamp, required: true}
  - {name: status,          type: enum,      values: [created, paid, shipped, cancelled]}
freshness_sla: 1 hour
```

- **Grain** is the most important line. "One row per order", not "order data". If the grain is ambiguous, every downstream query is a guess.
- **Owner** means someone is accountable when the data is wrong.
- **Freshness SLA** is a promise with a number. "Soon" is not a contract.
- **Schema** is explicit, including types, nullability, and allowed values.

Publish the contract. Consumers depend on it. Changing it is a breaking change and needs a deprecation path.

## 2. Idempotency and correctness

Pipelines retry. Networks fail. Jobs restart. Make reprocessing safe.

- **Idempotent writes**: the same input produces the same output. Use a merge or upsert keyed on a stable identifier, not an append.
- **Deterministic partitioning**: the same record always lands in the same partition, so ordering per key holds.
- **Exactly-once is a property of the read-process-write boundary**, not of the transport. A transactional outbox on the producer side plus idempotent consumers is the practical pattern.
- **Never rely on the broker alone.** Design for at-least-once delivery and make the consumer idempotent.
- Deduplicate on a stable event id, not on arrival time.

**Watermarks and late data**

- Each event carries a timestamp. Watermarks estimate how far behind the slowest producer is.
- Late data beyond the watermark needs an explicit policy: a side table, a correction record, or a periodic restatement. Silently dropping it is a data loss bug.
- In the warehouse, use a partition key that bounds the restatement cost, and reprocess a whole partition when needed.

## 3. Streaming with Kafka

**Topics and keys**

- The key determines partitioning and ordering. Key by the entity ID (customer, order) so all events for one entity stay ordered.
- Ordering is only guaranteed within a partition. Cross-key ordering does not exist.
- One logical event type per topic. A catch-all topic becomes unparseable.

**Consumer groups**

- A consumer group partitions the topic across its members. Adding a consumer rebalances the partitions.
- One group per logical consumer. Two groups in the same group id will steal partitions from each other.
- Commits happen after processing, not before. Committing early loses data on a crash; committing late duplicates. Make the processing idempotent so late duplicates are harmless.
- Poll, process, commit. Keep the processing fast, or increase `max.poll.interval.ms`, or the consumer will be evicted.

**Schema management**

- Schemas live in the registry, with a compatibility mode. `BACKWARD` is the safe default; `FULL` is the strict one.
- An incompatible change needs a new topic version and a dual-write or migration plan, not a silent break.
- Avro, Protobuf, or JSON Schema. The schema registry handles compatibility checks.

**Patterns**

- **Consumer group** for work distribution.
- **Publish-subscribe** for fan-out.
- **Outbox pattern** for reliably publishing DB changes: write the event to an outbox table in the same transaction, then a poller publishes it. This removes the dual-write problem.
- **Idempotent consumer** with a dedup table keyed by event id.

**Operations**

- Monitor consumer lag per group. Lag that grows is a backlog, not a metric to ignore.
- Set retention per topic. An event log that never expires is an unbounded cost and a compliance risk.
- Partition count sets the parallelism ceiling. Resizing a partition count is a migration, not a config change.

## 4. Batch pipelines and orchestration

**Airflow / Dagster / Prefect**

- A DAG is a dependency graph of tasks with explicit retry and timeout policies.
- **Idempotent tasks.** A task that can be re-run safely is the norm, not the exception.
- **Retries with backoff**, bounded. A task that retries forever hides a permanent failure.
- **SLA / deadline monitoring** on every task, not just the DAG.
- Use a **sentinel check** (a `dagrun` date) for a run, not a timestamp computed from `now()`. A parameterised run date makes backfills and re-runs reproducible.
- Concurrency limits so a backlog of backfills does not starve the daily production run.
- Airflow's scheduler is not the execution engine. Understand the difference before scaling.

**Spark**

- Partition the data by the key that matters for the operation. A shuffle is expensive; avoid it.
- Use broadcast joins for small tables instead of shuffling the large side.
- Persist only what is reused. Caching is expensive.
- Choose the right number of executors and partitions. Too few partitions wastes the cluster; too many causes overhead.
- Adaptive query execution handles skew in modern Spark; enable it.
- Skew is the most common Spark failure. A hot key turns one partition into the bottleneck.

**Backfills**

- A backfill must be idempotent and must not double-count. Overwrite the target partition rather than appending.
- Backfill with a separate run that writes to a staging location, validate, then swap. Or write with a run-date partition key and adjust downstream queries.
- Rate-limit backfills so they do not degrade the live pipeline.

## 5. Warehouse modeling

**Dimensional model**

- **Fact table**: measurements (orders, payments, page views). Narrow, large, with foreign keys.
- **Dimension table**: context (customer, product, date, geography). Wide, small, shared.
- **Conformed dimension**: a dimension shared across multiple fact tables. This is what makes a warehouse coherent.

**Types of facts**

- **Transaction**: one row per event. Additive.
- **Periodic snapshot**: cumulative totals at each interval. Semi-additive; do not sum across time.
- **Accumulating snapshot**: one row per process, updated as it progresses. Used for order fulfillment.

**Conformance rules**

- Surrogate keys on dimensions, generated and stable.
- A degenerate dimension (an order id with no dimension table) is fine for the fact.
- Consistent grain throughout a fact table. Mixing grains in one table is the most common modeling error, and it is invisible until someone sums a column that is not additive.
- Surrogate vs natural keys: use a surrogate key for the join, and keep the natural key as an attribute.
- SCD Type 2 for history when you need "as of" analysis: version rows with effective dates and a current flag.

**Wide vs narrow tables**

- Narrow (normalized) for the source of truth.
- Wide (denormalized) marts for specific consumption patterns, built by a transformation.
- Build the mart from the normalized model, never the other way around.

## 6. dbt and transformations

- Models are `select` statements in version-controlled SQL. Tests are assertions.
- Layering: `staging` (cleaned, renamed, one-to-one with the source) -> `intermediate` (business logic, joins) -> `marts` (consumption-ready).
- Every model has a description and, for important columns, column-level descriptions.
- **Tests**: `unique`, `not_null`, `relationships`, plus custom singular tests for business invariants (a refunded order must have a matching payment).
- **Materializations**: `table` for small models, `incremental` for large append-only models, `view` for thin passthroughs.
- Incremental models need a reliable incremental predicate and a deduplication strategy. Without a merge or dedup step, they double-count.
- Set a `full_refresh` schedule for models whose logic changes.
- Document the lineage: which models feed which.

## 7. Data quality

Quality is enforced in the pipeline, not by a human noticing.

- **Schema checks**: column types, nullability, unexpected columns, renamed columns.
- **Freshness**: is the data within its SLA? This is the single most valuable automated check.
- **Volume checks**: row count compared to the recent history. A sudden drop means a broken upstream.
- **Distribution checks**: a column that was normally 0-100 now spans 0-1000 means a schema change upstream.
- **Referential integrity**: every foreign key resolves.
- **Custom invariants**: the business rules. "Cancelled orders must have a cancellation reason."

Alerting:

- Fail the pipeline loudly on a hard violation. Do not publish bad data.
- Warn on a soft violation, and record it.
- Route failures to the owning team, with the specific rows or records that failed.
- Every check has an owner and a runbook.

## 8. Schema evolution

- **Additive**: new nullable column. Safe. Backfill later.
- **Widening**: int -> bigint, varchar(100) -> varchar(200). Safe in most engines.
- **Breaking**: remove a column, rename, change a type, tighten nullability, change semantics. Not safe.
- For breaking changes: dual-write, backfill, switch readers, drop the old. The same expand/contract pattern as application code.
- In a warehouse, add the new column, populate it for historical data, switch consumers, then drop the old one in a later release.
- A semantic change with the same name and type is the most dangerous one. It breaks silently. Version the semantics in the contract and in the column name if you must.

## 9. Cost and performance

- Partition by the column most queries filter on. Partitioning by a high-cardinality column creates many small files, which is its own problem.
- Compact small files. Tiny files hurt every engine.
- Cluster or sort by the columns used in frequent filters.
- Select only the columns needed. Columnar formats make this a huge win.
- Materialize only what is queried often. Do not precompute everything.
- Monitor storage by table, and track cost per query.
- Retention: raw data for a defined window, then aggregate or archive.

## 10. Orchestration and operations

- One pipeline, one owner. Ambiguous ownership means data quality declines.
- Backfills and production runs share the same code path, parameterised by the run date.
- Every pipeline is reproducible: given the same input, the same output.
- Alert on SLA misses, not on every task failure. Noise trains people to ignore alerts.
- A "data incident" (wrong numbers published) follows the same process as a production incident: stabilize, communicate, postmortem.

## Supporting files

- `references/streaming.md` - Kafka topics, keys, consumer groups, schema evolution, outbox, patterns.
- `references/orchestration.md` - Airflow, Spark, task design, backfills, idempotency, cost.
- `references/warehousing.md` - dimensional modeling, fact types, SCD, marts, dbt layering.
- `references/data-quality.md` - checks, tests, freshness, volume, distribution, alerting.
- `references/contract-template.md` - dataset contract and pipeline design checklist.
