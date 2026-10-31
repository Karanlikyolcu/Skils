# Contributing to Skils

Thanks for adding to the directory. The repository collects agent skills, CLI tools, agents
and frameworks. This guide covers skills first; the other collections follow the same pattern
of a catalog README, a license and attribution.

## Before you start

- Search the existing collections to avoid duplicates.
- Open an issue for a new collection or a large change. Small skill additions can go straight
  to a pull request.
- Keep one pull request focused. A PR that adds one skill is easier to review than a PR that
  adds twenty.

## Adding a skill

### 1. Pick the ecosystem and category

```text
SKILLS/
└── OpenCode/
    └── general/
        └── <skill-name>/
            ├── SKILL.md
            ├── references/     # optional
            └── scripts/        # optional
```

Use lowercase, hyphenated folder names. The folder name should match the skill name in the
frontmatter.

### 2. Write `SKILL.md`

Start with YAML frontmatter:

```yaml
---
name: code-review
description: Use when reviewing a diff, pull request or patch. Covers correctness, security, tests, performance and API changes.
license: MIT
---
```

Rules:

- `name` is required and must match the folder name.
- `description` is the trigger. Say **when** to use the skill, not only what it contains.
  This is the text the agent matches against, so make it specific and searchable.
- `license` is required. Use an SPDX identifier such as `MIT` or `Apache-2.0`.
- Keep the body practical. Prefer a workflow, decision rules and concrete examples over
  general advice.
- Put long material in `references/` and link it from `SKILL.md`. Do not duplicate the same
  content in both places.
- Use relative links inside the skill folder so it keeps working after installation.

### 3. Keep it safe

- No credentials, tokens, private keys, personal phone numbers or private hostnames.
- No `curl | sh`, `wget | sh` or unpinned remote script execution. If a skill needs an
  installer, link to the official documentation and let the operator decide.
- No destructive command without a guard: a dry run, a backup, a confirmation step, or a
  clearly documented rollback.
- Scripts must be readable, fail closed and avoid `sudo` unless the skill is explicitly about
  privileged administration. Say what the script changes before it changes it.
- Do not add a background service, cron job or shell hook that runs without the operator
  asking for it.

### 4. Test it

Copy the skill into a scratch OpenCode config and check that it loads:

```sh
mkdir -p /tmp/opencode-skills-test
cp -r SKILLS/OpenCode/general/<skill-name> /tmp/opencode-skills-test/
```

Point a test config at the folder, or copy it to `~/.config/opencode/skills/` and start a new
session. Ask the agent a task that should match the description and confirm the skill is
selected. If the skill has scripts, run the read-only path first.

Check the frontmatter parses:

```sh
python3 - <<'PY'
import yaml
text = open("SKILL.md", encoding="utf-8").read()
front = text.split("---", 2)[1]
print(yaml.safe_load(front))
PY
```

### 5. Add the catalog entry

Add a row to the relevant table in `SKILLS/<Ecosystem>/README.md`:

```markdown
| [skill-name](general/skill-name/SKILL.md) | One sentence on what it does. | MIT |
```

If the skill comes from another project, add it to `ATTRIBUTION.md` with the upstream link and
license. Do not remove an existing author or source field.

## Pull request checklist

- [ ] One skill or one coherent collection per PR.
- [ ] `SKILL.md` frontmatter parses and contains `name`, `description` and `license`.
- [ ] Folder name matches the skill name.
- [ ] Catalog table updated.
- [ ] Attribution added for third-party work.
- [ ] No secrets, personal data or private hostnames.
- [ ] No unpinned remote execution or unguarded destructive command.
- [ ] Relative links resolve inside the skill folder.
- [ ] The skill was loaded in a test session, or the PR says why that was not possible.

## Commit messages

Use conventional commits:

```text
feat(skills): add code-review skill
docs(skills): add OpenCode catalog
fix(skills): correct broken reference link
```

Keep the subject under 72 characters. Explain the reason in the body when it is not obvious.

## Attribution and licensing

By contributing, you agree that your contribution is licensed under the license declared in
the skill's frontmatter. If you are adding someone else's work, keep their copyright notice,
link the upstream repository, and confirm that the license allows redistribution.

## Review

A maintainer will check the skill for scope, safety, duplicate content and catalog quality.
Reviews may ask for a smaller skill, a clearer description, or a safer script. That is normal;
the goal is a collection people can trust.
