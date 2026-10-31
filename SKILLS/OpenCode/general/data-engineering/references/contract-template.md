# Dataset Contract and Pipeline Design Template

Fill this in before building a pipeline. If a field cannot be answered, the design is not settled.

---

## Dataset

**Name:** `orders_enriched`

**Owner:** data-platform

**Description:** Orders joined with customer segment and product category, one row per order.

## Grain

**One row per:** <!-- the single most important line in this document -->

> Example: "one row per order, excluding cancelled orders"

**Does the grain change over time?** no

**Can two rows have the same primary key?** no

## Schema

| Column | Type | Nullable | Source | Description |
|--------|------|----------|--------|-------------|
| order_id | string | no | raw.orders.order_id | |
| customer_key | int | no | dim_customer | |
| order_total_cents | int | no | derived | |
| currency | string | no | raw.orders.currency | ISO 4217 |
| status | enum | no | raw.orders.status | created/paid/shipped/cancelled |
| ordered_at | timestamp | no | raw.orders.ordered_at | UTC |
| loaded_at | timestamp | no | ingest | |

**Units:** money in minor units (cents), timestamps in UTC, durations in seconds.

**Primary key:** `order_id`

## Freshness

**SLA:** <!-- e.g. 1 hour -->
**Measured by:** `max(loaded_at)` in the target table
**Alert:** page after 2 consecutive misses

## Volume

**Expected:** <!-- e.g. 2M rows/day -->
**Alert threshold:** 50% below or 200% above the 7-day median

## Consumers

| Consumer | Uses | Owner |
|----------|-------|-------|
| revenue_mart | order_total_cents | finance |
| churn_model | status, customer_key | ml-team |

## Source

| System | Table | Extraction | Mode |
|--------|-------|-----------|------|
| postgres | orders | CDC (Debezium) | append |

**Schema evolution policy:** <!-- e.g. additive only; a breaking change requires a new dataset version -->

## Pipeline

**Orchestrator:** Airflow
**DAG id:** `daily_orders_enriched`
**Schedule:** `0 3 * * *`
**Logical date:** used for the partition key; never `now()`
**Max active runs:** 1

**Steps:**

| # | Task | Reads | Writes | Idempotent how |
|---|------|-------|--------|----------------|
| 1 | extract | raw.orders | staging.orders | Partition overwrite by run date |
| 2 | transform | staging.orders, dim_customer | intermediate.orders | Merge on order_id |
| 3 | load | intermediate.orders | fact.orders | Partition overwrite |
| 4 | validate | fact.orders | - | Asserts; fails the task |

**Backfill:** `airflow dags backfill -s <start> -e <end> daily_orders_enriched`, writes to a staging partition and swaps.

**Late data policy:** <!-- e.g. records older than 3 days go to a corrections partition and trigger a restatement -->

## Quality checks

| Check | Type | Severity | Action on failure |
|-------|------|----------|-------------------|
| order_id is unique and not null | schema | hard | Fail the task |
| row count within 50% of the 7-day median | volume | hard | Fail the task |
| max(loaded_at) within SLA | freshness | hard | Alert |
| every customer_key resolves | referential | hard | Quarantine |
| order_total_cents >= 0 | business | hard | Quarantine |
| status in the allowed set | business | hard | Quarantine |

## Ownership

| Role | Name |
|------|------|
| Dataset owner | |
| Pipeline owner | |
| On-call | |
| Escalation | |

## Change management

- **How is a change proposed:** a PR against the contract file
- **Who approves:** the dataset owner, plus a consumer representative for breaking changes
- **Deprecation window:** <!-- e.g. 30 days, with a usage check before removal -->
- **Notification:** <!-- e.g. a message in #data-announce and an email to consumers -->

## Non-goals

What this dataset deliberately does not contain, so nobody asks for it later.

---

## Review checklist

- [ ] The grain is stated in one unambiguous sentence
- [ ] The primary key is tested for uniqueness and non-null
- [ ] Units and timezones are documented for every measure
- [ ] Every column has a source
- [ ] The freshness SLA has a number and an alert
- [ ] Every task is idempotent
- [ ] The pipeline uses the logical date, not `now()`
- [ ] Business invariants are tested, not just schema
- [ ] There is a quarantine path for rejected rows
- [ ] Consumers are listed and have been consulted
- [ ] The schema evolution policy is stated
