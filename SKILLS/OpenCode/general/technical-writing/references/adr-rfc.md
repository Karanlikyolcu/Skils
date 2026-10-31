# ADRs and RFCs

## Architecture Decision Record (ADR)

An ADR records a decision that was made, in a context that a future reader will not have.

Write one when:

- The decision is expensive to reverse (a data store, a public API, a language, a service boundary).
- The decision is surprising. A newcomer would choose differently and needs to know why.
- A real trade-off was weighed, and the losing options have value to know about.
- The decision constrains future work, and that constraint should be visible.

Do not write one for a routine implementation choice.

## Format

```markdown
# ADR-0007: Use PostgreSQL for the primary datastore

- Status: Accepted
- Date: 2026-01-14
- Deciders: <names or team>
- Supersedes: ADR-0003
- Superseded by: (none)

## Context

The forces at play, stated without arguing for a conclusion.

- Product needs transactional writes across three related entities.
- The team has operational experience with MySQL but not Postgres.
- Existing read volume is 200 queries/second and growing 30%/month.
- A managed Postgres service is available at comparable cost.
- Two team members have raised that SQLite will not satisfy the write
  concurrency requirement.

## Decision

We will use PostgreSQL 16 as the primary datastore, with the managed
service in all non-production environments.

## Alternatives considered

### MySQL (existing provider)
Rejected. The team knows it, but the operational fit is worse and the
managed offering is more expensive at our projected volume.

### SQLite
Rejected. It does not support concurrent writers, and the roadmap has
multi-tenant write isolation in the next two quarters.

### DynamoDB
Rejected. Our access patterns are relational and the query flexibility
would be lost. Revisit if the access pattern becomes key-value.

## Consequences

### Positive
- Transactional integrity for the order workflow.
- A managed service removes the on-call burden of patching and failover.
- The team can hire for either ecosystem.

### Negative
- New operational surface: connection pooling, migration ordering, and
  vacuum behaviour all need attention.
- Two team members need Postgres-specific training before their first
  production change.

### Follow-up work
- Connection pool sizing and limits (owner: <name>, due <date>)
- Migration runner selection (owner: <name>, due <date>)

## Revisit when

- Write concurrency exceeds 500/s sustained.
- The managed service cost exceeds 3x the alternative.
- The access pattern becomes predominantly key-value.
```

## Rules

- **Immutable once accepted.** Do not edit an accepted ADR to reflect a new decision. Write a new ADR and mark the old one as superseded. The history is the value.
- **Status values**: Proposed, Accepted, Rejected, Deprecated, Superseded.
- **One decision per ADR.** Two decisions in one document get accepted or rejected together.
- **Date it.** The date tells the reader how stale the context is.
- **Name it with a number.** `ADR-0007`. The ordering shows the sequence.
- **Keep it under two pages.** If it is longer, the decision is probably two decisions.
- **Record the loss.** The rejected alternatives are often more useful than the decision, because a future team will re-propose them.

## Where they live

```text
docs/
  adr/
    0001-use-postgresql.md
    0002-choose-async-queue.md
    README.md        <- index: number, title, status, date
```

The index is what makes the set navigable. Keep it current.

## Review flow for an ADR

1. Author writes it as **Proposed** and opens it as a pull request.
2. Reviewers check the context is complete and the alternatives are genuinely considered.
3. Discuss in the PR. Change the ADR in place while it is still Proposed.
4. Someone with authority accepts it. The author updates the status and the date.
5. The index is updated.
6. The decision is implemented. If implementation reveals a new fact, that is a new ADR.

## RFC (design proposal)

An RFC is the document *before* the decision. It is a discussion tool, not a record.

```markdown
# RFC-0012: Introduce a read-only replica for reporting

- Status: Draft
- Author: <name>
- Date: <date>
- Target decision date: <date>

## Summary

Two paragraphs. What is proposed and why.

## Motivation

The problem, with evidence. Numbers, not adjectives.

## Goals
- Each goal is a measurable outcome.

## Non-goals
- Each non-goal is an explicit boundary. This section prevents scope creep.

## Design

The proposed design. Components, data flow, interfaces, schema.

## Alternatives considered

Each with the reason it was rejected.

## Migration plan

How existing systems move to the new design. Expand, migrate, contract.

## Rollback plan

How this is undone if it goes wrong.

## Security and privacy

New data flows, new permissions, new attack surface.

## Observability

How this is monitored. Metrics, logs, alerts.

## Open questions

The things that are genuinely undecided. Each with an owner.

## Alternatives to this proposal
```

## ADR versus RFC

| | ADR | RFC |
|---|------|-----|
| When | After the decision | Before |
| Audience | Future maintainers | Current reviewers |
| Tone | Record of what was decided and why | Argument for a proposal |
| Mutability | Immutable once accepted | Edited freely until decided |
| Length | Under two pages | As long as needed |
| Outcome | A superseding ADR, or nothing | An ADR, if accepted |

An accepted RFC becomes an ADR. Keep the RFC as the discussion record and write a short ADR pointing at it.

## Anti-patterns

- **ADRs as fiction.** Writing one to look rigorous, then never following it. The cost is that people stop trusting the set.
- **ADRs that justify.** Written to support a decision already made, with the alternatives strawmanned. A future reader cannot tell that happened.
- **No index.** Fifty ADRs in a flat directory with no index is an archive, not a decision log.
- **Editing history.** Changing an accepted ADR erases the context that made the decision understandable.
- **Skipping the negative consequences.** An ADR with only benefits is a sales pitch, not a decision record. The negative consequences are where the next team gets the most value.
- **Revisit conditions omitted.** Without one, a decision becomes superstition and is never questioned.
