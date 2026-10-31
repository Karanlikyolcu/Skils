# Data Quality

## The model

A pipeline that publishes wrong data quietly is worse than one that publishes nothing. Quality checks are the control.

Five classes of check, in order of value:

| Class | Question | Cost | Value |
|-------|----------|------|-------|
| Freshness | Is the data there yet? | Cheap | Highest |
| Schema | Is the shape what we expect? | Very cheap | High |
| Volume | Is the row count plausible? | Cheap | High |
| Distribution | Do the values look normal? | Medium | High |
| Business invariants | Is the data correct? | Expensive | Highest accuracy |

## Freshness

The single most valuable automated check. Stale data with a fresh timestamp is the worst failure mode, because everything looks healthy.

```sql
select
  max(loaded_at)               as last_load,
  current_timestamp - max(loaded_at) as age
from fact_orders;
```

- Compare against the SLA: `age < interval '1 hour'`.
- Alert when the SLA is missed, and page only if it is missed twice in a row (a single miss is often a rerun).
- Track freshness per table, not per pipeline. A pipeline with 20 outputs has 20 freshness signals.

## Schema checks

- Expected columns present, with the expected types.
- No unexpected columns. A new column in the source is a signal, not a nuisance.
- Nullability respected: a column that must not be null is not null.
- Column names match the contract exactly. A rename upstream is a breaking change that a schema check catches before the consumers do.

```yaml
models:
  - name: stg_orders
    columns:
      - name: order_id
        tests: [not_null]
      - name: status
        tests:
          - accepted_values:
              values: ['created', 'paid', 'shipped', 'cancelled']
```

## Volume checks

```sql
-- row count against the recent history
select
  date_trunc('day', ordered_at) as day,
  count(*)                       as n
from fact_orders
where ordered_at > current_date - interval '30 days'
group by 1
order by 1;
```

- Compare today against the median of the last N days, not against yesterday. Yesterday may have been an outlier.
- A zero-row day is almost always a broken pipeline, not a business event.
- Alert on a large relative deviation, e.g. more than 50% below the 7-day median.
- Per-segment volume checks catch a partial failure that a global check misses (one region out, 2% of rows lost).

## Distribution checks

- **Range**: a value that should be 0-100 now spans 0-1000. A schema change upstream.
- **Null rate**: a feature that suddenly becomes 50% null means the source broke.
- **Cardinality**: a categorical column that suddenly has 1000 distinct values instead of 5 means the field changed meaning.
- **New and disappearing categories**: a status value nobody has seen before.
- **Statistical drift**: compare the distribution against a baseline window (PSI, KS test, or a simple quantile comparison).

```sql
-- null rate per feature, against the previous week
select
  feature_name,
  count(*) filter (where value is null)::float / count(*) as null_rate
from features
where event_date > current_date - interval '7 days'
group by 1;
```

## Business invariants

The checks that know what the data is supposed to mean.

- A refunded order must have a matching refund record.
- `order_total_cents` must equal the sum of its line items.
- An order with `status = 'shipped'` must have a `shipped_at` timestamp.
- A customer in the `enterprise` segment must have a contract record.
- `delivered_at >= shipped_at >= ordered_at`.

Write these as singular tests. They are the ones that catch a real business bug.

```sql
-- tests/assert_order_total_matches_lines.sql
select o.order_id
from {{ ref('fct_orders') }} o
join {{ ref('fct_order_lines') }} l using (order_id)
group by o.order_id, o.order_total_cents, o.currency
having sum(l.line_total_cents) <> o.order_total_cents
```

## Where checks live

| Layer | What it catches |
|-------|-----------------|
| Ingestion | A malformed source file, a broken extract |
| Transformation | A modelling bug, a join fan-out |
| Load | A constraint violation, a schema drift |
| Consumption | A consumer reading something it should not |

- Run ingestion checks before writing anything. Reject a bad batch at the door.
- Run transformation checks after the model, before publishing.
- Do not publish data that failed a hard check. Publish to a quarantine path and alert.

## Quarantine

```text
good records  -> the target table
bad records   -> quarantine table + alert with the failure reason
```

- A quarantine table holds the rejected rows with the check that failed and the batch identifier.
- The alert says which check failed and how many rows were quarantined.
- Quarantined rows are reprocessed after the cause is fixed.
- Silently dropping rows is the worst outcome: the pipeline looks healthy and the data is incomplete.

## Alerting

- **Fail loudly on a hard violation.** A broken referential integrity is a pipeline failure, not a warning.
- **Warn on a soft violation.** A mild distribution shift is information, not an outage.
- Route to the owning team. A quality alert to a channel nobody reads is wasted.
- Every alert says: which table, which check, how many rows, since when, and what to do.
- Rate-limit alerts. A backfill that legitimately breaks a freshness check should not page 400 times.

## Schema evolution in the pipeline

- **Additive**: a new nullable column. Safe.
- **Widening**: `int` to `bigint`, `varchar(100)` to `varchar(200)`. Usually safe, but verify the downstream type.
- **Breaking**: removing a column, renaming, tightening nullability, changing the unit or the meaning. Not safe.

For a breaking change:

1. Add the new column, backfill it.
2. Dual-write.
3. Switch consumers to the new column.
4. Drop the old one in a later release.

A **semantic change with the same name and type** is the most dangerous: it passes every schema check and breaks every consumer. Guard it with a business invariant check, and version the semantics in the contract.

## Testing the pipeline

- **Unit test** the transformation logic on a small fixture.
- **Integration test** against a real database with representative data, including edge cases: nulls, unicode, very large numbers, negative amounts, timestamps at boundaries.
- **Golden test**: run the pipeline on a fixed input and assert the output matches a stored expectation. The most effective regression test for a transformation.
- **Test the failure path**: a malformed record, a missing column, a null key.

## Common mistakes

- Checking only that the pipeline ran, not that the data is right.
- A freshness check on the pipeline, not on each output table.
- Treating a zero-row day as normal.
- No quarantine path, so bad rows are either dropped or published.
- Alerting on every minor deviation, so the real one is ignored.
- No golden test, so a modelling change silently alters the numbers.
- Validating only at the end of the pipeline, after the bad data is already written.
