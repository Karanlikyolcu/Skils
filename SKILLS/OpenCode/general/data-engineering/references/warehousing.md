# Warehouse Modeling

## Dimensional model

A warehouse is organised around facts (measurements) and dimensions (context).

- **Fact table**: narrow, large, additive measures with foreign keys. `fact_orders(order_id, customer_key, product_key, date_key, order_total_cents, quantity)`.
- **Dimension table**: wide, small, shared. `dim_customer(customer_key, customer_id, name, segment, country, valid_from, valid_to, is_current)`.
- **Conformed dimension**: the same dimension shared across multiple fact tables. This is what makes the warehouse coherent, and what makes a cross-domain report possible.

## Fact table types

| Type | Grain | Additivity | Use |
|------|-------|------------|-----|
| Transaction | One row per event | Fully additive | Orders, payments, clicks |
| Periodic snapshot | Totals at each interval | Semi-additive | Daily balance, inventory level |
| Accumulating snapshot | One row per process, updated | Non-additive | Order fulfillment lifecycle |

- **Transaction facts** are immutable event records. Never update them; correct with a reversing entry.
- **Periodic snapshots** cannot be summed across time. The balance on Monday is not the sum of the daily balances. Use `LAST_VALUE` or `MAX_BY` over the period, never `SUM`.
- **Accumulating snapshots** carry both the process keys and the milestone dates (`ordered_at`, `shipped_at`, `delivered_at`), so fulfilment time is a simple column difference.

## Grain

**The single most important property of a fact table.** Write it as a sentence: "one row per ...".

- If the grain is ambiguous, every downstream query is a guess, and the errors are silent.
- One fact table, one grain. Mixing grains in one table is the most common modelling error, and it does not fail until someone sums a non-additive column.
- A column that is not additive at the fact grain must be marked and documented, or moved to a different table.

## Keys

- **Surrogate key** on every dimension: a generated integer, unique, never reused. Stable across attribute changes.
- **Natural key** kept as an attribute: the real-world identifier (`customer_id`).
- **Degenerate dimension**: a fact column with no dimension table, like `order_id` in `fact_orders`. Acceptable and common.
- The fact table references dimension surrogate keys. It never joins on a natural key.

## Slowly changing dimensions

| Type | Behaviour | Use when |
|------|-----------|----------|
| Type 1 | Overwrite in place | History does not matter |
| Type 2 | New row with effective dates and an `is_current` flag | History matters, and you need point-in-time reporting |
| Type 3 | Keep the old value in a separate column | Only the previous value matters |
| Type 4 | History in a separate history table | You want Type 2 semantics without bloating the main table |

Type 2 mechanics:

```sql
CREATE TABLE dim_customer (
  customer_key   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id    VARCHAR      NOT NULL,
  name           VARCHAR      NOT NULL,
  segment        VARCHAR,
  valid_from     TIMESTAMP    NOT NULL,
  valid_to       TIMESTAMP    NOT NULL DEFAULT '9999-12-31',
  is_current     BOOLEAN      NOT NULL DEFAULT TRUE
);
```

- The fact table joins on `customer_key`, so it is unaffected by attribute changes.
- A point-in-time query joins on the fact's date falling between `valid_from` and `valid_to`.
- Loading: close the current row (`valid_to = <change_time>`, `is_current = FALSE`) and insert the new row with the same natural key. Do this in a single transaction.
- A **type 2 fact** (a fact whose dimension changes mid-life) is a much harder problem. Avoid it in the dimension model; handle it in the fact grain.

## Normalisation vs denormalisation

- Normalise the source of truth. Keep it modelled properly.
- Build **wide marts** for specific consumption patterns, derived from the normalised model.
- The mart is a performance artefact and may be rebuilt at any time. Never build it by hand.

```text
staging (raw, cleaned, renamed, 1:1 with source)
    -> intermediate (joins, business logic, deduplication)
        -> marts (consumption-ready, wide, denormalised)
```

## Marts

- One mart per consumption pattern (a reporting dashboard, a feature set for a model, an export).
- A mart is a view or a table. A table is faster and can have its own indexes; a view is always fresh.
- Document the mart's grain and refresh cadence.
- Materialise only what is queried often.

## dbt layering

```sql
-- models/staging/stg_orders.sql
select
    cast(order_id as varchar)          as order_id,
    cast(customer_id as varchar)        as customer_id,
    order_total_cents / 100.0          as order_total,
    currency,
    ordered_at at time zone 'utc'      as ordered_at
from {{ source('raw', 'orders') }}
where _deleted_at is null
```

- `staging`: rename, cast, and clean. One-to-one with the source. No joins. No business logic.
- `intermediate`: joins, deduplication, business logic. Reusable across marts.
- `marts`: consumption-ready. Wide. This is what the BI tool queries.

### Materializations

| Materialization | Use |
|----------------|-----|
| `view` | Thin passthrough, no performance concern |
| `table` | Small to medium, needs to be fast |
| `incremental` | Large, append-only, with a merge or dedup strategy |

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='incremental', unique_key='order_id') }}
select * from {{ ref('int_orders_enriched') }}
{% if is_incremental() %}
where ordered_at > (select max(ordered_at) from {{ this }})
{% endif %}
```

- An incremental model without a `unique_key` and a merge strategy double-counts. This is the most common dbt bug.
- `full_refresh` for models whose logic changed, on a schedule.
- `on_schema_change` decides what happens when the source schema changes: `fail` (safest), `append_new_columns`, or `sync_all_columns`.

### Tests

```yaml
models:
  - name: fct_orders
    description: "One row per order, with customer and product attributes."
    columns:
      - name: order_id
        description: "Primary key."
        tests: [unique, not_null]
      - name: customer_key
        tests:
          - relationships:
              to: ref('dim_customer')
              field: customer_key
      - name: order_total_cents
        tests: [not_null]
```

- `unique`, `not_null`, `relationships`, `accepted_values` cover most cases.
- **Singular tests** for business invariants that no generic test captures:

```sql
-- tests/assert_refunded_orders_have_a_refund.sql
select r.order_id
from {{ ref('fct_orders') }} r
left join {{ ref('fct_refunds') }} f using (order_id)
where r.status = 'refunded' and f.order_id is null
```

- Document the model and its columns. The description is what the consumer reads.

## Partitioning and clustering

- **Partition** by the column most queries filter on, typically a date. Low-to-medium cardinality.
- Partitioning by a high-cardinality column creates many small files, which is its own problem.
- **Cluster** or **sort** by the columns used in frequent filters within a partition.
- **Compact** small files periodically.

## Storage and cost

- Columnar formats make column selection cheap. Select only what you need.
- Materialise the aggregates that are queried constantly; leave the rest as views.
- Monitor storage by table and cost per query.
- Retention: keep raw at full fidelity for a window, then aggregate or archive.

## Common mistakes

- A fact table with two grains.
- A semi-additive measure (a snapshot balance) summed across time.
- Joining facts to dimensions on a natural key, which breaks the moment a dimension changes.
- An incremental model with no dedup strategy.
- Building a mart by hand instead of deriving it.
- No test on the primary key of a fact table.
- Storing a slowly changing dimension without `valid_to` and `is_current`, so point-in-time queries are impossible.
