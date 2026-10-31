# Streaming with Kafka

## Topics

- One logical event type per topic. A catch-all topic becomes unparseable and forces consumers to filter.
- Name it after the fact: `orders.created.v1`, `payments.captured.v1`. The version lives in the name so a breaking change means a new topic.
- **The key determines partitioning and ordering.** Key by the entity ID (customer, order) so all events for one entity land on one partition and stay ordered.
- Ordering is guaranteed only within a partition. Cross-key ordering does not exist, and cannot be bought.
- Partition count sets the parallelism ceiling. More consumers than partitions means idle consumers.

## Consumer groups

- A group partitions the topic across its members. Adding a consumer triggers a rebalance.
- One group per logical consumer. Two groups with the same ID steal partitions from each other.
- **Commit after processing, not before.** Committing early loses the message on a crash; committing late redelivers it. Make processing idempotent so redelivery is harmless.
- Keep the processing time under `max.poll.interval.ms`, or the consumer is evicted and the partition moves.
- Increase `max.poll.records` or lower the poll interval to control the batch size.

```properties
group.id=orders-projector
enable.auto.commit=false
max.poll.records=500
max.poll.interval.ms=300000
session.timeout.ms=45000
auto.offset.reset=earliest
```

## Offsets and replay

- Offsets are per group per partition, stored in Kafka.
- `auto.offset.reset=earliest` for a new consumer that must process the whole topic; `latest` for one that only cares about new data. This choice is easy to get wrong and hard to notice.
- To reprocess, reset the offsets for the group to an earlier point, or use a new group name.
- Retention is what makes replay possible. A topic with short retention cannot be replayed past the retention window.

## Schema management

- Schemas live in a registry (Confluent Schema Registry, Apicurio, Karapace) with a compatibility mode.
- `BACKWARD` (the safe default): a new schema can read data written by the old one.
- `BACKWARD_TRANSITIVE`: checks against all previous versions.
- `FULL`: both directions, the strictest.
- `NONE`: no checks. Do not use it in production.
- An incompatible change needs a new topic version plus a dual-write or a migration plan, not a silent break.
- Avro for schema enforcement, Protobuf for compactness and wide compatibility, JSON Schema when the payload is irregular.

```json
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.orders",
  "fields": [
    { "name": "event_id",   "type": "string" },
    { "name": "order_id",   "type": "string" },
    { "name": "customer_id","type": "string" },
    { "name": "total_cents","type": "long" },
    { "name": "currency",   "type": "string" },
    { "name": "occurred_at","type": { "type": "int", "logicalType": "timestamp-millis" } }
  ]
}
```

## Exactly-once

**Exactly-once is a property of the read-process-write boundary, not of the transport.** Kafka gives at-least-once delivery plus transactions within Kafka. Anything outside Kafka is not covered.

Two practical patterns:

**Transactional outbox** (the standard)

```text
Producer:                                   Consumer:
BEGIN                                      poll -> process -> write
  write business row                        COMMIT (offset + output)
  write outbox row
COMMIT
                                          outbox poller:
                                            read outbox -> publish to Kafka
                                            mark as published
```

- The business change and the event are in one database transaction, so the event is never lost and never published for a rolled-back change.
- A separate process publishes from the outbox and marks rows as published.
- The outbox table needs an index on `(published, created_at)` and a cleanup job.

**Idempotent consumer** (simpler, works with any broker)

```sql
CREATE TABLE processed_events (
  event_id     TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- Insert the event ID first; if it conflicts, skip. The primary key does the deduplication.
- Or use a deterministic upsert on the business key so replaying the same event produces the same state.

## Patterns

| Pattern | Use when |
|---------|----------|
| Consumer group | Work distribution among consumers |
| Publish-subscribe | Fan-out to independent consumers |
| Outbox | Reliably publishing DB changes |
| Debounce | Collapsing a burst of events into one (state-change topics) |
| Compacted topic | Keeping only the latest state per key |
| Kafka Streams | Stream processing with stateful joins |
| Change data capture | Reading row changes from the DB log (Debezium) |

**Compacted topics** keep only the latest record per key, for a bounded time. Use for a state snapshot topic. Do not use them as an event log; the intermediate states are gone.

**CDC** (Debezium, or a native engine feature) reads the database write-ahead log and publishes row changes. It captures every change with no code on the producer side. Consider:
- The log position as the offset, so it is exactly-once by construction.
- Schema changes become schema changes in the topic. Test them.
- It couples to the database internals and can be sensitive to DDL.

## Operations

**Consumer lag** is the key metric.

```sh
kafka-consumer-groups.sh --bootstrap-server $BROKER --describe --group orders-projector
```

- Lag that grows is a backlog. Alert on the trend, not on an absolute number.
- A sudden lag spike with normal throughput means a slow downstream dependency.
- Lag on one partition only means one key is hot. That is a key-design problem: partition by something with more cardinality, or handle the hot key separately.

**Retention and storage**

- Set retention per topic. An event log that never expires is an unbounded cost and a compliance problem.
- `delete` retention keeps size bounded by time. `compact` keeps size bounded by the number of keys.
- Monitor bytes per partition and the disk usage of the cluster.

**Partition sizing**: a partition is the unit of parallelism and of ordering. Too few partitions limits consumer throughput; too many creates many small files and overhead. A common starting point is a few thousand partitions for a large cluster, not tens of thousands.

**Schema and payload**: use Avro or Protobuf rather than JSON for high-volume topics. The registry enforces compatibility, and the binary encoding is significantly smaller.

## Common mistakes

- Committing the offset before processing. The message is lost on a crash.
- Not making the consumer idempotent, so redelivery duplicates the effect.
- Keying by a high-cardinality field that does not correspond to the ordering you need.
- One group ID for two different consumers.
- `auto.offset.reset=latest` on a consumer that was supposed to backfill.
- No schema registry, so a producer change silently breaks consumers in production.
- Publishing to a topic with no consumer, with no alerting, and assuming the data is being processed.
- Monitoring the average lag across partitions instead of the maximum. The hot partition is the problem.
