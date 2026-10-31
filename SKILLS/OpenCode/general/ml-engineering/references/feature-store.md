# Feature Store

## Why

The problem is **training-serving skew**: the model was trained on features computed one way and is served features computed another way. The offline metric looks great; production does not.

A feature store solves it by making one definition the single source for both paths.

```text
                 feature definition
                         |
              +----------+-----------+
              |                      |
        offline path            online path
     (materialised view)      (fetched at request time)
              |                      |
        training data            live features
```

- The **offline path** materialises features into a table for training, with a point-in-time-correct history.
- The **online path** serves the latest value from a low-latency store.
- Both are produced by the **same definition**. The code is shared, not the values.

## Feature definitions

```python
from feast import FeatureView, Field, Entity
from feast.types import Float32, Int64

customer_features = FeatureView(
    name="customer_features",
    entities=[Entity(name="customer_id", join_keys=["customer_id"])],
    schema=[
        Field(name="lifetime_value_cents", dtype=Int64),
        Field(name="tenure_days", dtype=Int64),
        Field(name="avg_order_value_cents", dtype=Float32),
    ],
    source=customer_feature_source,
    ttl=timedelta(days=3),
)
```

- A feature definition lives in code, versioned with the repo. Not in a UI that nobody reviews.
- Each feature has a **type**, a **description**, an **owner**, and an **expected freshness (TTL)**.
- The TTL defines what "missing" means. A feature older than its TTL should be treated as missing, not as a stale value.

## Point-in-time correctness

The join between features and labels is where leakage enters.

**Wrong** - joins on the current value of the feature:

```sql
select f.customer_id, f.lifetime_value_cents, o.order_id, o.label
from features f join orders o on f.customer_id = o.customer_id
```

The feature value here is the value *today*, not the value at the time of the order. If `lifetime_value_cents` grows with every order, the model learns to use a number that includes the answer.

**Right** - point-in-time join:

```sql
select
    o.order_id,
    o.label,
    f.lifetime_value_cents,
    f.tenure_days
from orders o
left join features_history f
  on f.customer_id = o.customer_id
 and f.event_ts <= o.order_ts      -- the feature as of the event time
qualify row_number() over (
    partition by o.order_id order by f.event_ts desc
) = 1
```

- The feature timestamp must be at or before the event timestamp.
- If several feature rows match, take the most recent one before the event.
- This is what every training-set builder in a feature store does for you. If you build the training set by hand, this is the step you will get wrong.

## Offline and online parity

The same definition, but the two paths have different constraints:

| | Offline | Online |
|---|---------|--------|
| Latency | Minutes to hours | Milliseconds |
| Volume | Billions of rows | Key-value lookup |
| Storage | Columnar warehouse | Redis, DynamoDB, Cassandra |
| Access | Time-travel join | Latest value per key |

Parity breaks when:
- The offline transform uses a different library or version than the online one.
- A UDF behaves differently in the two engines.
- Time handling differs: the offline path uses UTC, the online path uses the server's local time.
- Null handling differs: the offline path fills with a median, the online path returns null.
- The offline path includes a row that the online path has not written yet.

**Parity test**: take a sample of online feature fetches, log them, and compare against the offline computation for the same entity and timestamp. Run it in CI or on a schedule. This is the test that catches skew.

## Feature freshness

- Every feature has a TTL. The online store returns the value plus its timestamp, and the serving code decides whether it is too old.
- Monitor the write lag: the time between the source event and the feature store write.
- A stale feature is often worse than a missing one. A missing feature can be imputed or handled; a stale feature is silently wrong.
- If a feature's freshness cannot be guaranteed, do not use it. Use a real-time source instead.

## Feature reuse

- A feature used by many models should live in the store. A feature used by one model can live in that model's pipeline.
- More features means more maintenance, more leakage risk, and more drift surfaces. Every feature must justify its place.
- **Feature debt** is real: features that were added for one model and never validated again.

## Feature monitoring

For every feature, continuously track:

| Signal | Detects |
|--------|---------|
| Null rate | Upstream break, a schema change |
| Value range and quantiles | A unit change, an impossible value |
| Distribution vs the training baseline | Concept-relevant drift |
| Freshness (age of the latest value) | A stalled pipeline |
| Uniqueness of the entity key | A broken join |
| Cardinality of a categorical | A field that changed meaning |

Alert on a change, not on an absolute value. A feature that was 3% null and is now 3% null is fine; 3% to 30% is an incident.

## Storage layout

- **Offline**: a table per feature group, partitioned by the event timestamp, with an entity key index.
- **Online**: a key-value store keyed by the entity, holding the latest value and its timestamp.
- The write path is **upsert** on the entity key. The read path is a point lookup.
- Keep the online store small. It holds the latest value per entity, not the history.

## Ownership

- Every feature has an owner and a description.
- Changing a feature definition is a **breaking change** for every model that uses it. Version the definition, and require a consumer check before the change lands.
- Deprecate features rather than deleting them. A model still in production may depend on them.

## When not to use a feature store

- One model, one pipeline, one team. A feature store is a lot of infrastructure for one use case.
- Features computed inside the training job already, with no online serving requirement.
- The team is small and the serving path is a single service. A shared transformation library plus a Redis cache does the same job with less machinery.

Use a feature store when there are many models, many features, and a real risk of skew.

## Anti-patterns

- Joining features to labels without a point-in-time condition. This is the number one cause of leakage.
- A feature definition maintained in a UI, outside version control.
- No TTL on a feature, so a stale value is served indefinitely.
- Adding every available feature to every model.
- Changing a feature definition without checking who consumes it.
- Assuming the feature store guarantees parity. It guarantees a shared definition, not identical behaviour.
