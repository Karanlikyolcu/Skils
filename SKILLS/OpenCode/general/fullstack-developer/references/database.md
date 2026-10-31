# Database Engineering

## Schema design

- Model the domain. A table is an entity, a column is a property, a foreign key is a relationship.
- Every table: primary key, created_at, updated_at (UTC). Soft-deleted tables also need deleted_at and it must be in every uniqueness constraint.
- Use the right type for the job:

| Data | Type | Notes |
|------|------|-------|
| Text | `text` / `varchar(n)` | Always bound the length |
| Integer count | `integer` | |
| Big counter | `bigint` | |
| Money | `bigint` (minor units) or `numeric(12,2)` | Never `float` |
| Percentage | `numeric(5,2)` | |
| Boolean | `boolean` | |
| Timestamp | `timestamptz` | Store UTC |
| Duration | `interval` | |
| JSON | `jsonb` | Only for genuinely schemaless data |
| Enum | enum type or lookup table | A lookup table is easier to change |
| UUID | `uuid` | Or a sortable id (UUIDv7, ULID) |
| Hash/binary | `bytea` | |

- `NOT NULL` by default. Nullable means "sometimes absent", and that is a decision, not an oversight.
- Add a `CHECK` constraint for every rule you would otherwise validate in code. The database is the last line of defense, and it is never bypassed.
- Foreign keys with an explicit `ON DELETE` behavior. `RESTRICT` by default; `CASCADE` only when the child truly cannot exist without the parent.
- Unique constraints on the business key, not just the surrogate id. Two users cannot have the same email, enforced by the database.

## Normalization

- Normalize until it hurts, then denormalize what you measure to be slow.
- Keep a canonical normalized model. Add a read-optimized table or view for a specific query pattern, with the mechanism to keep it in sync.
- Do not denormalize before you have a measurement.

## Indexing

- Every foreign key used in a join or a filter gets an index (most engines do not create one automatically).
- Index the columns you actually filter and sort by, in the order the query uses them.
- Composite index column order matters: equality columns first, then the range or sort column.
- Covering index (`INCLUDE` columns) can make an index-only scan possible.
- Partial index for a subset: `WHERE deleted_at IS NULL`, or only active rows.
- Expression index for a computed or normalized value: `lower(email)`.
- **Uniqueness needs an index**, and it is the one case where the index is not optional.
- Do not index a low-cardinality column alone (a boolean or a status with three values). It rarely helps and costs writes.
- Every index costs write throughput and storage. An unused index is pure cost. Find and drop them.

Check the plan:

```sql
EXPLAIN ANALYZE SELECT ...;
```

Look for sequential scans on large tables, wrong join order, and estimates far off from actual row counts.

## N+1 and query patterns

The most common performance bug in web applications:

```python
for order in orders:
    print(order.customer.name)      # one query per order
```

Fix by eager loading or by an explicit batch query:

```sql
SELECT * FROM orders WHERE customer_id IN (...);
```

Also watch for:

- Loading a full entity to read one column. Select only the columns you need.
- `SELECT *` on a wide table into a hot loop.
- A count query per page to render pagination. Cache it or use an approximate count.

## Transactions and locking

- One transaction per logical operation, kept short.
- Default isolation is usually fine. Know what your engine's default actually is (PostgreSQL: READ COMMITTED).
- `SELECT ... FOR UPDATE` locks the selected rows. Use it when you must serialize a read-modify-write.
- Lock in a consistent order across the codebase to avoid deadlocks.
- Deadlocks are a retry signal: catch, back off briefly, retry.
- Optimistic concurrency with a `version` column avoids most locking: `UPDATE ... WHERE id = ? AND version = ?`, and check that a row was actually affected.
- Use `SKIP LOCKED` for a work queue so workers do not block each other.

## Pagination

- Offset: `LIMIT n OFFSET m`. Simple, but deep offsets scan and skip rows, and the result set shifts under concurrent inserts.
- Cursor: `WHERE (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC LIMIT n`. Stable, fast, and consistent. Use a unique, sortable tuple as the cursor.
- Always pair `ORDER BY` with a unique tiebreaker (`id`) or the order is not deterministic.
- Keyset pagination is the right choice for infinite scroll and for large tables.

## Migrations

Rules:

- A migration is applied exactly once, in order, and is tracked in a migrations table.
- Never edit an applied migration. Add a new one.
- Make migrations backward compatible with the currently deployed code, so deploy and migrate can happen in either order without downtime. Expand, migrate, contract.
- Do not rename a column in one step. Add the new column, dual-write, backfill, switch reads, drop the old one in a later release.
- Set an explicit lock timeout so a migration cannot wait forever and block the database.
- For large tables, batch the backfill (chunks of a few thousand rows) instead of one giant update.
- Keep the rollback path defined, or mark the migration explicitly as one-way with a note.
- Test the migration against a copy of production-like data, including the row counts, before shipping.

## Schema changes without downtime

1. **Expand**: add the new column/table, nullable or with a default. Old code ignores it.
2. **Migrate**: dual-write, and backfill in batches.
3. **Switch**: read from the new source.
4. **Contract**: drop the old column in a later release.

## Constraints and defaults

- Use `DEFAULT` for columns the application always sets the same way. It reduces inconsistency, but it hides missing values from the client - be deliberate.
- Use `NOT NULL` for anything that is genuinely required.
- `CHECK` constraints for ranges, formats, and cross-field rules.
- Database-level uniqueness for business keys.

## Connection management

- Use a pool. Size it from the database's connection capacity: `pool_size x instances < max_connections`.
- Set a statement timeout so a runaway query cannot hold a connection forever.
- Retry transient failures (deadlock, serialization failure, connection reset) with backoff.
- Ensure connections are returned to the pool on every path, including exceptions.

## Query performance checklist

1. Is it an N+1?
2. Is the query plan using indexes?
3. Is the result set bounded?
4. Are only the needed columns selected?
5. Is the filter applied as early as possible?
6. Is the sort using an index, or is it sorting in memory?
7. Are there unnecessary joins to tables whose columns are not used?
