# OpenCode Skills

A curated collection of 21 OpenCode-compatible agent skills. Each skill is a folder with a
`SKILL.md` entrypoint and optional `references/` and `scripts/` resources.

OpenCode loads a skill when its description matches the task, or when you name it explicitly.
The skills are plain Markdown, so they also work with other agents that read `SKILL.md` files.

## Install

Global install, all skills:

```sh
git clone https://github.com/Karanlikyolcu/Skils.git
cp -r Skils/SKILLS/OpenCode/general/* ~/.config/opencode/skills/
```

Install one skill:

```sh
cp -r Skils/SKILLS/OpenCode/general/code-review ~/.config/opencode/skills/
```

OpenCode discovers each `SKILL.md` under the skills directory. Start a new session after
copying so the catalog is rescanned.

> These skills are instructions, not a sandbox. Review a bundled `scripts/` file before
> running it, especially when it touches services, credentials or the network.

## Catalog

### Engineering and architecture

| Skill | What it does | License |
|---|---|---|
| [application-developer](general/application-developer/SKILL.md) | Mobile, desktop and packaged web apps: architecture, state, offline sync, UI, performance and release. | MIT |
| [fullstack-developer](general/fullstack-developer/SKILL.md) | End-to-end web work: API design, schema and migrations, auth, frontend state, forms, caching and jobs. | MIT |
| [game-developer](general/game-developer/SKILL.md) | Game loop, ECS, physics, rendering, input, animation, audio, netcode and frame budgets. | MIT |
| [ml-engineering](general/ml-engineering/SKILL.md) | Datasets, training pipelines, evaluation, serving, feature stores, drift and LLM/RAG systems. | MIT |
| [data-engineering](general/data-engineering/SKILL.md) | Streaming and batch pipelines, warehouse modeling, dbt, data quality, CDC and backfills. | MIT |
| [devops](general/devops/SKILL.md) | CI/CD, containers, Kubernetes, IaC, cloud config, observability, deployment and incident response. | MIT |
| [senior-engineer](general/senior-engineer/SKILL.md) | Architecture decisions, refactoring, debt triage, data/API modeling, scalability and trade-offs. | MIT |
| [software-development](general/software-development/SKILL.md) | Explore, implement, fix, refactor and test in an existing codebase; scope and verify changes. | MIT |

### Review, security and quality

| Skill | What it does | License |
|---|---|---|
| [code-review](general/code-review/SKILL.md) | Review diffs and PRs for correctness, security, tests, performance and API changes. | MIT |
| [cybersecurity](general/cybersecurity/SKILL.md) | Threat modeling, secure code review, auth/session design, injection defenses, secrets and supply chain. | MIT |
| [security-audit](general/security-audit/SKILL.md) | Auth flaws, exposed secrets, OWASP risks and dependency/supply-chain threats. | MIT |

### Systems and operations

| Skill | What it does | License |
|---|---|---|
| [arch-linux](general/arch-linux/SKILL.md) | Arch, CachyOS, EndeavourOS and Manjaro administration: pacman, AUR, boot, GPU and desktop. | MIT |
| [debian-ubuntu](general/debian-ubuntu/SKILL.md) | Debian, Ubuntu, Mint and Pop!_OS administration: apt, dpkg, upgrades, boot and drivers. | MIT |
| [rhel-fedora](general/rhel-fedora/SKILL.md) | Fedora, RHEL, Rocky, AlmaLinux, CentOS and Amazon Linux: dnf, SELinux, boot and desktop. | MIT |
| [networking](general/networking/SKILL.md) | Linux DNS, reverse proxies, VPN/WireGuard, VLANs, nftables and routing. | MIT |
| [performance-debugging](general/performance-debugging/SKILL.md) | CPU, heap, allocation, lock and latency regressions with profiles and baselines. | MIT |
| [shell-scripting](general/shell-scripting/SKILL.md) | Bash, Zsh, POSIX sh and Fish: quoting, dotfiles, completions and debugging. | MIT |
| [git](general/git/SKILL.md) | Commits, branches, rebases, conflicts, PRs/MRs, tags, releases and forge workflows. | MIT |

### Writing and design

| Skill | What it does | License |
|---|---|---|
| [technical-writing](general/technical-writing/SKILL.md) | ADRs, RFCs, READMEs, API references, tutorials, runbooks and changelogs. | MIT |
| [ui-ux-design](general/ui-ux-design/SKILL.md) | Screen flows, dashboards, forms, tables, wizards, accessibility and complex-app interaction rules. | MIT |

### Agent operations

| Skill | What it does | License |
|---|---|---|
| [unattended-delivery](general/unattended-delivery/SKILL.md) | Run a job to completion without questions and survive model quota exhaustion. | MIT |

## External packs

These are not vendored here. Install them from their upstream repositories.

| Pack | What it covers | License |
|---|---|---|
| [linux-skills](https://github.com/peterbamuhigire/linux-skills) | Debian/Ubuntu and RHEL-family operations: provisioning, hardening, services, networking, databases, containers, backups, performance and compliance. | MIT |

## Adding a skill

See [CONTRIBUTING.md](../../CONTRIBUTING.md). Keep one skill per folder, declare `name` and
`description` in the frontmatter, and include the license and source for anything you did not
write.

## License and attribution

The collection is distributed under the MIT license. Third-party skills keep their original
notices. See [ATTRIBUTION.md](ATTRIBUTION.md) and [LICENSE](LICENSE).
