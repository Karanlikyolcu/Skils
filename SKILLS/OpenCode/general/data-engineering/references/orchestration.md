# Batch Orchestration and Spark

## Airflow design

**A DAG is a dependency graph of tasks.** Each task should be independently runnable, idempotent, and retriable.

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta

default_args = {
    "owner": "data-platform",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "execution_timeout": timedelta(hours=2),
    "sla": timedelta(hours=3),
    "email_on_failure": True,
}

with DAG(
    dag_id="daily_revenue",
    start_date=datetime(2026, 1, 1),
    schedule="0 3 * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["finance", "daily"],
) as dag:
    extract = PythonOperator(task_id="extract", python_callable=extract_orders)
    transform = PythonOperator(task_id="transform", python_callable=transform_orders)
    load = PythonOperator(task_id="load", python_callable=load_revenue)
    validate = PythonOperator(task_id="validate", python_callable=validate_revenue)

    extract >> transform >> load >> validate
```

### Idempotency

Every task must be safe to re-run. This is the single most important property of an Airflow pipeline.

- **Write to a partition keyed by the run date**, not an append. Re-running overwrites the same partition.
- **Use a staging table and swap.** Load into `revenue_staging` with the run date, validate, then replace `revenue`.
- **Merge, do not insert.** `MERGE` on the business key, so a re-run updates rather than duplicates.
- **Delete before insert** for a full-refresh table, scoped to the affected date range.

```sql
MERGE INTO revenue r
USING staging s ON r.order_date = s.order_date AND r.country = s.country
WHEN MATCHED THEN UPDATE SET r.revenue_cents = s.revenue_cents
WHEN NOT MATCHED THEN INSERT (order_date, country, revenue_cents) VALUES (s.order_date, s.country, s.revenue_cents);
```

### The run date

**Always use a parameterised logical date, never `now()`.**

```python
def extract_orders(**context):
    run_date = context["logical_date"].date()   # not datetime.now()
    return extract_for(run_date)
```

- `now()` makes a backfill produce the wrong data, and makes a re-run of yesterday's DAG produce today's data.
- `execution_date` is a legacy alias for `logical_date`. Use `logical_date`.
- `ds` is the logical date as a string.

### Retry, timeout, SLA

- Retries with exponential backoff, bounded. A task that retries forever hides a permanent failure.
- `execution_timeout` kills a hung task. Without it, one stuck task holds a worker slot indefinitely.
- `sla` is a missed-deadline alert. It does not stop the task.
- Transient failures (network, a rate-limited API) should retry. A schema error should not.

### Scheduling

- `schedule` as a cron string. `@daily`, `@hourly`, or `0 3 * * *`.
- `catchup=False` for pipelines that do not need history. With catchup enabled, enabling a DAG for the first time triggers a massive backfill.
- `max_active_runs=1` prevents a backlog of runs from overlapping and conflicting on the same partitions.
- `depends_on_past=False` unless the task genuinely needs the previous run's output.

### Backfills

```sh
airflow dags backfill -s 2026-01-01 -e 2026-01-31 daily_revenue
```

- A backfill must not collide with the live run. `max_active_runs=1` plus a distinct backfill job, or a different DAG with a parameter.
- Use the `airflow dags test` command to validate a task against a real database before a full backfill.
- Backfill at a controlled rate so it does not starve the warehouse or the live pipeline.

### Common Airflow mistakes

- Business logic inside the DAG file. Put it in importable modules; the DAG file should be wiring.
- `Variable.get()` inside a task body on every row. Fetch once.
- XCom for anything large. XCom is stored in the metadata database; pass a path instead.
- A task with no timeout.
- Catching exceptions and returning a default, so a failed load looks successful.

## Spark

**Spark is for data that does not fit in memory on one machine.** If it fits, use a database.

### Partitioning

- **Partition by the column the operation needs.** A shuffle is expensive; avoid it.
- `repartition(col)` to align the partitioning with a join key.
- `coalesce` to reduce partition count without a shuffle (only to reduce, not to increase).
- Sort within partitions before a join to make it a sorted merge join.

### Joins

- **Broadcast a small table.** `broadcast(df)` on a table under a few hundred MB avoids the shuffle entirely.
- Otherwise, both sides are shuffled. Make sure the join key is not skewed.
- **Skew** is the most common Spark failure. A hot key sends all its rows to one partition. Mitigations: salting, splitting the hot key, or a skewed join strategy.

```python
from pyspark.sql.functions import broadcast
result = large_df.join(broadcast(small_df), "country", "left")
```

### Caching

- `cache()` only when the DataFrame is used more than once and the recompute is expensive.
- Unpersist when done. A cached DataFrame that is no longer needed still occupies memory.
- `persist(MEMORY_AND_DISK)` for a DataFrame larger than memory.

### Adaptive query execution

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
```

AQE handles partition coalescing and skew joins automatically. Enable it.

### Writing

- **Write to a partitioned dataset**, partitioned by the date, and use a mode that overwrites only the affected partition.
- Delta Lake, Iceberg, or Hudi give you ACID transactions, schema evolution, and time travel.
- Small files ruin performance. Compact them periodically.
- Never write to a path another job is reading without an atomic swap.

### Cluster sizing

- Executors: more, smaller executors usually beat fewer, larger ones.
- Executor memory: 4-8 GB per core is the usual starting point. Too much causes GC pressure and long GC pauses.
- `spark.sql.shuffle.partitions` defaults to 200, which is wrong for most clusters. Set it to roughly 3-5x the total core count.
- Dynamic allocation handles variable load. Set `spark.dynamicAllocation.enabled=true`.

### Common Spark mistakes

- Using Spark for data that fits in a database query.
- Not enabling AQE.
- `collect()` on a large DataFrame, which pulls it all to the driver and OOMs.
- `cache()` without a `unpersist()`.
- Small files from many small writes.
- A `shuffle` of tens of GB, caused by a join that could have been broadcast.
- Spark on a cluster with no executor memory limits, so one job takes down the node.

## Choosing between tools

| Situation | Use |
|-----------|-----|
| Data fits on one machine, one query | Postgres, DuckDB, SQLite |
| Daily multi-step dependency DAG | Airflow or Dagster |
| Large-scale batch over TB of data | Spark |
| Continuous event streams | Kafka + a stream processor |
| Interactive SQL over the warehouse | Trino, Snowflake, BigQuery |
| Simple scheduled SQL | The database's own scheduler, or cron |

Do not use Airflow to run a single SQL query. Do not use Spark for a query Postgres can answer in a second.
