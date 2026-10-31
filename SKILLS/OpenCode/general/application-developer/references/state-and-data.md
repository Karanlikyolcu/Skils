# State and Data

## The three kinds of state

| Kind | Source of truth | Persisted? | Lifetime |
|------|-----------------|------------|----------|
| Server state | The server | Cached locally | Until invalidated |
| Local persistent | The device | Yes | Across launches |
| Ephemeral UI | In memory | No | Until the screen closes |

Mixing these is the most common source of app bugs. A bug is usually one of these:

- The same value stored in two places, and only one is updated.
- Server data copied into local state and never re-synced.
- Ephemeral state written to disk, so a stale screen is restored.

## State containers

- A state holder per screen (ViewModel, Presenter, Store, Controller). Scoped to the screen.
- A global store only for truly global state: session, theme, feature flags, locale.
- A repository layer that owns server data and its cache.
- Do not put a global store in charge of everything. Every extra global field is a recomposition trigger and a coupling point.

## Local persistence

Choose by data shape:

| Data | Store |
|------|-------|
| Settings, flags, small values | Key-value (SharedPreferences, UserDefaults, NSUserDefaults) |
| Relational, queryable, large | SQLite / Room / Core Data / Realm |
| Blobs, media, documents | Files on disk |
| Secrets | Keychain / Keystore / EncryptedSharedPreferences |
| Large caches | Files, or a cache directory the OS can evict |

- Version every persisted schema. Write a migration for each version bump.
- A migration must be tested against the previous version's actual data, not just an empty database.
- Encrypt sensitive local data with a key from the platform keystore. Never hardcode the key.
- Never store large blobs in preferences. Store the metadata in the database and the bytes on disk.
- Handle a corrupt database: detect it, and recover rather than crash-looping.
- Handle a full disk: catch the error and tell the user, instead of a silent write failure.

## Offline-first architecture

The local database is the source of truth for the UI. The network is a sync source.

```text
UI  <->  Repository (local DB)  <->  Sync engine  <->  Network
```

- Every read goes to the local database.
- Every write goes to the local database first, plus an outbox entry.
- A background sync engine drains the outbox.
- The UI observes the local database, so it is always consistent with what is stored.

## Outbox and sync

```text
Write request:
  1. Apply the change to the local database (in one transaction).
  2. Insert an outbox row {id, type, payload, attempts, nextAttemptAt}.
  3. Return success to the UI immediately.

Sync worker:
  for each due outbox row:
    send to the server
    on success:  delete the row
    on retryable failure: attempts++, nextAttemptAt = now + backoff(attempts)
    on permanent failure: move to a dead-letter table, surface it in the UI
```

- The outbox must be durable: it survives process kill, reboot, and network loss.
- Idempotency: the server must accept a duplicate request safely. Send a client-generated idempotency key.
- Backoff: exponential with jitter, capped (e.g. 5 min). Do not hammer the server on a flaky network.
- Sync triggers: app open, user action, connectivity regained, and a periodic interval as a backstop.
- Do not sync on every keystroke. Batch.

## Conflict resolution

The hard part. Pick a rule per data type and apply it consistently.

| Strategy | Use when | Risk |
|----------|----------|------|
| Last-write-wins (per field) | Independent fields, low stakes | Silent loss of a concurrent edit |
| Server wins | The server has the canonical value | The user's offline edit is lost |
| Client wins | The user must not lose edits | Overrides newer server data |
| Manual merge | Collaborative or high-stakes data | Requires a conflict UI |
| CRDT / operational transform | Concurrent text and collaborative edits | Complexity, metadata growth |

- Never let conflict resolution be accidental. Make the rule explicit per entity type.
- Track a version or a logical clock per record. Without one, "which is newer" is a guess based on clock skew between devices.
- Compare versions, not wall-clock timestamps. Device clocks are wrong.
- When a conflict is detected and cannot be resolved automatically, surface it. Do not silently discard the user's work.
- Test the conflict path explicitly: two devices, one offline edit, one online edit, then sync.

## Data binding and observation

- The UI observes a reactive query to the local database. No manual refresh calls.
- Write to the database, and the UI updates itself. This removes a whole class of "the screen did not update" bugs.
- Use a stable flow, not a one-shot read, so the UI stays in sync.
- In the presentation layer, map the database model into a UI state model. Do not leak database entities (with their columns) into the UI.

## Caching server data

- Cache the last known server response with a timestamp.
- Serve stale data immediately, then refresh in the background. Stale data with a "last updated" indicator beats a spinner.
- Use an HTTP cache validator (ETag / Last-Modified) to avoid downloading unchanged data.
- Evict by age and by size limit. LRU for the hot set, TTL for freshness.
- Be explicit about the policy: how long is data considered fresh, and what does "fresh" mean for the user.

## Background work and lifecycle

- The platform kills background work. Assume any job can stop at any point.
- Persist the job's state so it can resume.
- Make every task idempotent.
- Do not rely on timers firing on time. Re-check the elapsed time inside the task.
- Use platform-appropriate triggers: work manager, background fetch, background transfer.
- Respect the user's battery and data settings. Ask for background sync permission explicitly.

## Data validation

- Validate data at every boundary, including data read back from the local database. A database written by an older app version may contain shapes the current code does not expect.
- Migrate on read as a fallback.
- Use a schema for anything that crosses a process boundary (network, deep link, notification).

## Privacy

- Collect the minimum. Delete on request.
- Do not log personal data. Redact at the source.
- Respect the platform privacy manifest requirements (iOS) and permission declarations (Android).
- Do not send personal data to third-party analytics without disclosure and consent.
- Sensitive fields should be excluded from the local database entirely when possible.
