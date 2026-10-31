# Changelogs and Release Notes

## Two different documents

| | Changelog | Release notes |
|---|-----------|---------------|
| Audience | Developers integrating the library | Users deciding whether to upgrade |
| Scope | Every version, forever | One version |
| Format | Structured, machine-parseable | Prose, focused on impact |
| Written by | Maintainer, often automated | A human, for a notable release |

A changelog is a complete, uniform record. Release notes are a curated summary of what matters for this release.

## Changelog format: Keep a Changelog

```markdown
# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.0] - 2026-01-14

### Added
- `select_orders()` accepts a `status` filter, replacing the need to filter
  client-side. ([#412](https://github.com/org/repo/pull/412))

### Changed
- `create_order()` now raises `ValidationError` for an empty SKU. Previously it
  created the order with an empty SKU and failed at fulfillment. This is a
  breaking change; see the migration notes below.

### Deprecated
- `list_orders_all()`. Use `select_orders()` with pagination. Removal in 3.0.0.

### Fixed
- The `total` field on an order did not include shipping. ([#418](https://github.com/org/repo/pull/418))

### Security
- Session tokens were compared with a timing-variable method. Now uses a
  constant-time comparison. Rotate any session token issued before 2.4.0.

## [2.3.1] - 2025-12-02

### Fixed
- ...
```

Rules:
- **Sections in a fixed order**: Added, Changed, Deprecated, Removed, Fixed, Security.
- **Every entry is a sentence, not a label.** "Fixed a bug" is useless. "The `total` field did not include shipping" tells the reader what changed for them.
- **Link the PR or issue.** It gives the reader the context and the discussion.
- **`Unreleased` at the top.** Changes accumulate there between releases.
- **The format is uniform.** Every version has the same sections, even if a section is empty.
- **Breaking changes are marked** and have a migration note, not just a label.

## Semantic Versioning

| Change | Version bump |
|--------|-------------|
| A bug fix, a patch to existing behaviour | patch (2.4.0 -> 2.4.1) |
| A new, backward-compatible feature | minor (2.4.0 -> 2.5.0) |
| A breaking change | major (2.4.0 -> 3.0.0) |

- **Anything a user could notice is a minor or major.** Behaviour changes, output format changes, performance changes, and default changes all count.
- **A deprecation is a minor bump**, and the removal is a major bump.
- **0.x versions**: the minor is the breaking bump. 0.2.0 to 0.3.0 may break.
- A version number without a changelog entry is a release process bug.

## Release notes

The curated version for a notable release. It answers: **should I upgrade, and what do I need to do?**

```markdown
# v2.4.0

Released 14 January 2026.

## Highlights

**Orders can now be filtered by status at the database level.** `select_orders()`
takes a `status` parameter and the query is now covered by an index, so listing
filtered orders is roughly 10x faster on a large account.

**Empty SKUs are now rejected at creation time.** Previously an order with an
empty SKU was created and failed later at fulfillment, which was the most
common cause of a failed order. `create_order()` now raises `ValidationError`.

## Breaking changes

### `create_order()` rejects an empty SKU

`create_order()` raised `ValidationError` only for a `None` SKU. An empty
string was accepted. It now rejects both.

If you rely on creating an order with an empty SKU, this changes your
behaviour. The check happens before the database write, so no partial order is
created.

## Migration

No action is required unless you create orders with an empty SKU. If you do,
validate the SKU before calling `create_order()`:

```python
if not sku:
    raise ValueError("sku is required")
```

## Other changes

- `select_orders()` gained a `status` filter.
- The `total` field on an order now includes shipping.
- Session token comparison is now constant-time.

## Upgrade notes

- The minimum supported Python version is now 3.10.
- The `orders` table gained an index on `status`. The migration takes
  approximately 30 seconds on a table of 10M rows and takes a write lock. Run
  it during a maintenance window, or use the concurrent index migration.

Full changelog: https://github.com/org/repo/blob/main/CHANGELOG.md
```

Structure:
- **Highlights** first: two to five items, each with the user-facing impact.
- **Breaking changes** in their own section, each with what changed, why, and what to do.
- **Migration** as concrete steps, with code.
- **Other changes** as a short list.
- **Upgrade notes** for the operational impact (minimum versions, migrations, breaking changes in dependencies).
- **A link** to the full changelog.

Do not repeat the whole changelog in the release notes. The changelog is complete; the release notes are curated.

## Generated changelogs

`git-cliff`, `conventional-changelog`, and `git-chglog` generate a changelog from commit messages. This works when the team uses a consistent commit format.

- Conventional Commits (`feat:`, `fix:`, `BREAKING CHANGE:`) map cleanly onto the sections.
- The generated output needs a human pass. The wording is rarely good enough to publish as-is, especially for a minor release.
- A generated changelog is fine for patch releases. For a minor or major, write it.

## Deprecation and removal

```markdown
### Deprecated

- `list_orders_all()`. Use `select_orders()` with pagination. Removal in 3.0.0.
```

Rules:
- **State the replacement.** A deprecation without an alternative is an abandonment.
- **State the version it will be removed in.** A version, not "eventually".
- **Warn at runtime.** Log a deprecation warning when the deprecated function is called, with the replacement named.
- **Announce it** in the release notes, in the changelog, and in the documentation.
- **Do not remove it in the same release you deprecate it.**

## Security releases

- Lead with the vulnerability and its impact, not the fix.
- Say which versions are affected and which are not.
- Say whether any action is required from the user (rotate a credential, regenerate a token).
- Do not publish exploit details until a fix is available and the disclosure window has passed. Coordinate with the reporter.

```markdown
### Security

- Session tokens were compared with a timing-variable method, which could
  allow an attacker with network access to recover a token byte by byte. The
  comparison is now constant-time.

  Affected: 2.0.0 through 2.3.1. Fixed in 2.3.2.

  **Action required**: if your application caches session tokens, they remain
  valid. No rotation is needed unless your deployment is reachable by an
  untrusted network.
```

## Writing rules

- **Write for the reader who is deciding whether to upgrade.** Lead with impact.
- **Every entry is a change in behaviour**, not a description of the code change.
- **No commit hashes in the release notes.** They mean nothing to a user. The changelog can have them.
- **No internal jargon.** "Refactored the OrderRepository to use a Unit of Work" means nothing to a user of the library.
- **The breaking change section is the most-read section.** Make it precise and put the migration code in it.

## Anti-patterns

- A changelog that is a list of commit subjects.
- "Various bug fixes and improvements" as a release note.
- Breaking changes buried in a minor release with no migration section.
- A deprecation with no replacement and no removal version.
- Entries written from the diff's point of view rather than the user's.
- A version bump with no changelog entry.
