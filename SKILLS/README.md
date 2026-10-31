# Skills

Reusable agent skills, organized by ecosystem. Each ecosystem directory has its own catalog,
install notes and attribution.

| Ecosystem | Status | Path |
|---|---|---|
| OpenCode | 21 skills | [OpenCode](OpenCode/) |
| Claude Code | Planned | `Claude-Code/` |
| Codex | Planned | `Codex/` |
| Universal | Planned | `Universal/` |

## Format

A skill is a folder with a `SKILL.md` entrypoint:

```text
<skill-name>/
├── SKILL.md          # required: frontmatter + instructions
├── references/       # optional: deeper material loaded on demand
└── scripts/          # optional: helpers the skill may run
```

`SKILL.md` starts with YAML frontmatter:

```yaml
---
name: code-review
description: Use when reviewing a diff, pull request or patch.
license: MIT
---
```

The `description` is the trigger. It should say when to use the skill, not just what it is.

## Adding a collection

Create `SKILLS/<Ecosystem>/` with a `README.md` catalog, an `ATTRIBUTION.md` when the skills
come from elsewhere, and a `LICENSE` when the collection has its own license. Then add the
ecosystem to the table above and to the root `README.md`.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the review checklist.
