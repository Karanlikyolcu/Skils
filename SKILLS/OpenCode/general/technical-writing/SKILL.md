---
name: Technical Writing
description: Use for writing technical documentation - architecture decision records, RFCs and design docs, READMEs, API references, tutorials and how-to guides, runbooks, changelogs and release notes, and developer documentation. Also covers information architecture, audience calibration, doc-as-code, and reviewing documentation for accuracy.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Technical Writing

Documentation is a product with users. Its users are engineers who need an answer at a specific moment, under pressure, with incomplete context.

## 1. Know the audience and the job

Before writing a word, answer:

- **Who reads this?** A junior running a command for the first time, a senior reviewing a design, a user integrating an API, an on-call engineer at 3am. Each needs different depth, vocabulary, and structure.
- **What job are they doing?** Looking something up, learning something, making a decision, or doing a task. The job determines the format.
- **What do they already know?** Assume the domain, not the tool. Skip what a competent engineer in the field already knows.
- **What must they be able to do afterwards?** Write the goal as an action, not a topic.

| Job | Format |
|-----|--------|
| Look something up | Reference: alphabetic or task-ordered, scannable, no narrative |
| Learn a concept | Explanation: prose, with a worked example |
| Make a decision | Decision record: context, options, decision, consequences |
| Do a task | How-to: numbered steps, with expected output and verification |
| Understand the system | Architecture doc: components, boundaries, flows, diagrams |

Mixing these in one document is the most common documentation failure. A user who wants to do a task should not have to read an essay first.

## 2. Structure that gets found

- **Put the answer first.** Lead with the conclusion, the command, or the decision. Background comes after, if it is needed at all.
- **One topic per document.** A page with three topics has three audiences and satisfies none.
- **A heading is a promise.** If the heading says "Configure TLS", the section must configure TLS.
- **Use headings a reader would search for.** The words someone types into a search box, not your internal project jargon.
- **Front-load the summary.** A short "what this is and when to use it" at the top, then the detail.
- **Length is not a virtue.** Cut everything that does not help the reader do the job. A short doc that answers the question beats a long one that buries it.

## 3. Writing the thing

**Prose**

- Short sentences. Active voice. Concrete nouns.
- Address the reader as "you" and the system as "it".
- Say the specific thing, not the category of thing. "The service restarts every 60 seconds" not "the service has a restart policy".
- Cut throat-clearing: "It is important to note that", "As you may already know", "In this document we will".
- Use the second person for instructions and the third person for descriptions.

**Instructions**

- Number the steps. Each step is one action.
- Show the exact command, with the real flags, not a placeholder in the dangerous position.
- Show the expected output after the step, so the reader knows it worked.
- Include the permission requirement (`sudo`) in the command, not as a separate note.
- Mark anything destructive or irreversible clearly, and say how to undo it.
- One command per line. No `&&` chains of five commands.
- State the prerequisites before the steps, not as a surprise at step 4.

**Code examples**

- Complete and runnable. No `...` in the middle of a critical line.
- Show the imports, the error handling, and the realistic data.
- Name things meaningfully. `foo`, `bar`, `data1` teach nothing.
- Include the language and the file path when it matters.
- Keep the example to the minimum that demonstrates the concept.

**Reference**

- One entry per item, alphabetically unless a task order is more useful.
- Each entry: what it is, its type, its default, its allowed values, and an example.
- Consistent structure across entries, so the reader learns the shape once.
- Mark required, optional, and deprecated explicitly.

## 4. Accuracy and honesty

- **Verify every command and every code sample.** Run them. A doc with a wrong flag is worse than no doc, because it is trusted.
- **Version every claim.** "In OpenCode v2, skills live in..." The version tells the reader whether it applies to them.
- **Do not invent details.** If a flag's behaviour is uncertain, check the source or the `--help` output, or say it is unverified.
- **Mark what is not verified.** A statement you could not confirm should be labelled, not stated confidently.
- **Do not document a wish.** If a feature does not exist yet, do not write documentation for it, unless it is clearly marked as planned.
- **Date anything that goes stale.** A status page, a compatibility table, a version list.
- **Link, do not duplicate.** If the reference is generated from the code, link to the generator's output rather than copying it.

## 5. Maintenance

Documentation rots because nothing fails when it does.

- **Doc-as-code.** Keep docs in the repository, in version control, reviewed like code.
- **A doc change is part of the code change.** A PR that changes behaviour and does not update the docs is incomplete.
- **CI checks.** A link checker, a code-block linter, a check that documented commands still run against a test environment.
- **One owner.** Every doc has a team or a person responsible for it.
- **Review dates.** A page older than a year gets re-verified or archived.
- **Archive, do not delete.** Old versions stay reachable; the current version is obvious from the index.

## 6. Document types

**Architecture decision record (ADR)** - a decision, its context, the alternatives, and the consequences. Write one when a decision is expensive to reverse, surprising, or the result of a real trade-off. It is short, dated, and immutable once accepted (a later ADR supersedes it).

**RFC / design doc** - the proposal before the decision. Problem, goals, non-goals, design, alternatives, rollout plan, open questions. It is a living document until accepted.

**README** - what this is, why it exists, how to get it running, and where to go next. It is the entry point, not the manual.

**How-to guide** - a task, start to finish, with verification. Written for someone who already has the context.

**Tutorial** - a learning path. The reader builds something that works. Slower and more forgiving than a how-to.

**Reference** - exhaustive and organized for lookup, not for reading.

**Runbook** - what to do when this breaks. Symptoms, diagnosis, mitigation, escalation. Written for the worst moment of someone's life.

**Changelog / release notes** - what changed, for whom, and what to do about it. Not a git log.

## 7. Diagrams

- Use a diagram only when the relationship is genuinely spatial or structural, and prose would be worse.
- One idea per diagram. If it needs a legend the size of the diagram, split it.
- Label everything. A box with no label forces the reader to guess.
- Keep the visual vocabulary consistent across a document set.
- A sequence diagram for a flow over time, a component diagram for a structure, a state diagram for a lifecycle. Pick the right one.
- Always accompany a diagram with a short prose summary, so the meaning survives when the image does not.

## 8. Reviewing documentation

- Run every command. A broken example is the most common defect.
- Follow the steps in order, on a clean environment, exactly as written.
- Check the links. Both internal and external.
- Check that a newcomer could follow it. If it assumes unstated knowledge, it is incomplete.
- Check that it says what it promises in the first paragraph.
- Look for: "simply", "just", "obviously", "of course" (all assume the reader does not know something), "e.g." used as "for example", and mixed terminology.
- Check that the code samples use the same names as the prose.

## 9. Style checklist

- Sentence case for headings, unless the product has a convention otherwise.
- No exclamation marks in technical documentation.
- Write "does not" rather than "doesn't" in formal docs. Be consistent, whatever you choose.
- Use the serial comma consistently.
- Numbered lists for ordered steps, bullets for unordered items.
- Code in backticks, with the language for longer blocks.
- Bold sparingly, for the one phrase that matters. If everything is bold, nothing is.
- Link text that describes the destination, not "click here".
- A table when the information is genuinely tabular. Not a table of two rows.
- Define the acronym on first use, then use it consistently.

## Supporting files

- `references/adr-rfc.md` - ADR and RFC templates, when to write one, review flow.
- `references/api-docs.md` - API reference structure, OpenAPI, examples, versioning docs.
- `references/guides.md` - README, tutorial, how-to, and runbook structures and templates.
- `references/changelog.md` - changelog formats, release notes, semantic versioning communication.
- `references/style.md` - sentence-level style rules, terminology, and a review checklist.
