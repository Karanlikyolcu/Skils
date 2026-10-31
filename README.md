# Skils

All skills, CLI tools and agents in one place.

A centralized directory for AI development resources: reusable agent skills, CLI tools,
autonomous agents and frameworks. The goal is one repository to discover, compare and install
from instead of searching across many.

## Collections

| Collection | Status | What is inside |
|---|---|---|
| [SKILLS/OpenCode](SKILLS/OpenCode/) | Live, 21 skills | OpenCode-compatible engineering, review, security, operations, writing and agent skills. |
| `SKILLS/Claude-Code` | Planned | Claude Code-specific skills. |
| `SKILLS/Codex` | Planned | Codex-specific skills. |
| `SKILLS/Universal` | Planned | Skills that work across agent platforms. |
| `CLI/` | Planned | CLI tools and terminal agents. |
| `AGENTS/` | Planned | Autonomous, coding and multi-agent systems. |
| `FRAMEWORKS/` | Planned | Agent frameworks and orchestration libraries. |

## Quick start

```sh
git clone https://github.com/Karanlikyolcu/Skils.git
cp -r Skils/SKILLS/OpenCode/general/* ~/.config/opencode/skills/
```

Browse the [OpenCode skill catalog](SKILLS/OpenCode/README.md) for descriptions and
single-skill install commands.

## Repository layout

```text
Skils/
├── README.md
├── CONTRIBUTING.md
└── SKILLS/
    ├── README.md
    └── OpenCode/
        ├── README.md
        ├── ATTRIBUTION.md
        ├── LICENSE
        └── general/
            └── <skill>/SKILL.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: one skill per folder, a `SKILL.md`
with `name` and `description` frontmatter, no secrets, no unpinned remote execution, and
attribution for anything you did not write.

## License

The OpenCode collection is MIT-licensed. Each skill keeps its own license and attribution; see
[SKILLS/OpenCode/ATTRIBUTION.md](SKILLS/OpenCode/ATTRIBUTION.md).
