# Architecture Decisions

## Heuristics that hold up

**Cohesion beats cleverness.** A module should do one thing that you can name in a short phrase. If you cannot, it is two modules.

**Coupling should be visible and few.** Every dependency is a claim that the two things change together. Count them before adding one.

**Depend on abstractions only at genuine seams.** Interfaces with a single implementation, created for hypothetical future flexibility, are pure overhead. Introduce an interface when there are two implementations, or when the boundary must be crossed in a testable way.

**Push knowledge into the code.** If the rule "orders over 100 need manual approval" appears in three files, it belongs in one place that all three call.

**The database is a component, not a dumping ground.** Business rules that live only in SQL are invisible to the code, hard to test, and easy to bypass.

**Make illegal states unrepresentable.** A type that can only hold valid combinations removes a whole class of bug. Prefer that to a runtime check plus a comment.

**Boring and proven beats novel.** Every new technology has a carrying cost paid by the whole team, forever. Pay it only when the benefit is measured.

**Design for the second instance, not the third.** Generalize when the second concrete case arrives and you can see what the shared abstraction really is. Generalizing from one example creates the wrong abstraction, which is worse than duplication.

## Boundary patterns

**Layered** - presentation, application, domain, infrastructure. Each depends only on the one below. Simple, familiar, easy to test.

**Ports and adapters (hexagonal)** - the domain defines ports (interfaces); adapters implement them. Best when the domain is rich and the outside world varies (multiple databases, multiple protocols). More ceremony.

**Modular monolith** - one deployable, but each business capability is a module with a strict public API. Other modules reach into internals only through that API. The default for most applications: it keeps deployment simple while preserving boundaries.

**Event-driven** - publish facts, let subscribers react. Good for decoupling and for workflows spanning bounded contexts. Costs: eventual consistency, harder debugging, ordering and idempotency to handle.

**Microservices** - only when there is a real organizational or scaling reason. Each service adds network failure, deployment, versioning, and observability cost. "The codebase is big" is not sufficient; distributed monoliths are the usual outcome.

**CQRS** - separate the write model from the read model. Worth it for complex domains with expensive queries. Overkill otherwise.

## Data flow within a service

For a typical request:

```
HTTP adapter -> validate -> authorize -> application service -> domain logic -> repository -> DB
                                    |
                             domain events -> handlers (email, index, analytics)
```

- Adapters translate between the outside world and the domain. They contain no rules.
- The application service orchestrates: it calls domain operations and repositories, in order, inside a transaction boundary.
- The domain contains the rules and is framework-free.
- Repositories translate between domain objects and persistence.

Events are published after the transaction commits, not inside it. Otherwise a rollback leaves consumers acting on a change that never happened.

## When to introduce a new abstraction

Introducing one is right when:

- The same logic is written a second time and the two versions are genuinely the same concept.
- A dependency must be swapped (different database, different payment provider).
- A boundary must be crossed in a test without the real dependency.
- A policy is changing often and the change should not require touching call sites.

Introducing one is wrong when:

- It is a single-implementation interface with no test seam need.
- It wraps a library one-to-one and adds nothing but indirection.
- It exists because the class diagram in a book had it.

## Coupling metrics

A quick sense of scale:

- **Fan-out**: how many modules depend on this one. High fan-out means a change here breaks many places.
- **Fan-in**: how many modules this one depends on. High fan-in means it is doing too much or sits in a bad layer.
- **Change coupling**: how often two files change in the same commit. The strongest signal of hidden coupling, and the reason `git log --name-only` over the last 200 commits is worth running.

When reviewing, check that a change does not require touching unrelated modules. If it does, either the module boundaries are wrong, or the change is doing two things.

## Data modeling

- Model the domain, not the screen. "Order" means something to the business, not something to the dashboard.
- Use explicit relationships and constraints. Nullable foreign keys to a polymorphic parent are a design smell.
- Prefer a narrow table with clear columns over a generic JSON blob. JSON is fine for genuinely schemaless payloads, bad as a substitute for a decision.
- Separate the write model from the read model only when justified; a duplicated table needs a synchronization mechanism and a reconciliation job.
- Timestamps: store UTC, with timezone. Use a monotonic source for ordering, not wall clock.
- Soft deletes are a business decision, not a technical convenience. If you use them, every query must account for them, and uniqueness must be scoped to active rows.
- Every table needs a primary key that is stable, and a foreign key where a relationship exists. Orphans are silent data corruption.

## Architectural Decision Records

Write an ADR when a decision is expensive to reverse, surprising to a newcomer, or the result of a real trade-off. One file per decision, in `docs/adr/`.

```markdown
# ADR-0007: Use PostgreSQL for the primary datastore

Date: 2026-01-14
Status: Accepted
Deciders: ...

## Context
What forces are at play? What constraints? What is the pain?

## Decision
The choice, stated plainly and specifically.

## Alternatives considered
Each with the reason it was rejected.

## Consequences
What this makes easy, what it makes hard, and what we now have to live with.

## Revisit when
The condition that would invalidate this decision.
```

The "Revisit when" line is what keeps an ADR from becoming superstition. A decision without a revisit condition becomes permanent by accident.

## Design review questions

Before approving a design, ask:

1. What is the failure mode when the slowest dependency is 10x slower than expected?
2. What happens if this is processed twice?
3. What happens if it is processed out of order?
4. Where does the state live, and who is allowed to mutate it?
5. What is the query pattern that will need to be fast, and does the data model support it?
6. How would we add the second implementation of this interface?
7. What does this design make hard to change?
8. What is the simplest version of this that would work today, and what specifically would it break?
