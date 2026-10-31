---
name: ui-ux-design
description: "Use when designing or reviewing a user interface or experience - screen flows, dashboards, forms, tables, wizards, prototypes, accessibility, inclusive design, and complex-application interaction rules. Rulebook from the operator's design library; see application-developer for implementation and technical-writing for docs."
license: MIT
metadata:
  portable: true
  compatible_with: [claude-code, codex]
  invocation: implicit
  opencode/autoinvoke: true
  author: BOB
  author_url: https://github.com/MAKHMUDuz
  author_contact: https://github.com/MAKHMUDuz
---

# UI/UX Design

The rulebook for every UI/UX task, compiled from the four documents in the operator's
design library (`~/Documents/design/`):

1. *8 Design Guidelines for Complex Applications* (article, local copy).
2. *UX Strategies for Complex-Application Design* (article, local copy).
3. Fu, K. K., Yang, M. C., & Wood, K. L. (2015). *Design Principles: The Foundation of Design*.
   ASME IDETC/CIE 2015, DETC2015-46157.
4. Kimseng, N., Kurniab, D. A., Vuthy, I., Arifin, R. W., & Setiyadi, D. (2023).
   *UI/UX Development Using Figma based on Inclusive Design*. JINAV 4(2), 227-234.

Read the rulebook below before drawing, editing, reviewing or generating any interface.
Depth for each area sits in `references/`.

<!-- dual-compat-start -->
## Use When

- Creating or redesigning a screen, page, flow, form, table, dashboard, wizard or navigation.
- Reviewing an existing interface for usability, clutter, salience, accessibility or honesty.
- Producing wireframes, low-fidelity prototypes, clickable flows or design specs (Figma or markup).
- Deciding information architecture: what is primary, what is deferred, how a user moves between them.
- Applying inclusive or accessible design rules, or checking contrast, targets, labelling and motion.
- Designing for trained users, expert workflows, long-running or interrupted tasks, or high-stakes actions.
- Translating a vague product request into a defensible screen layout before implementation starts.

## Do Not Use When

- The task is UI implementation already decided - component structure, state, data flow: use
  `application-developer` or `fullstack-developer`, and keep this skill's rules as the acceptance bar.
- The task is reviewing a diff or patch for code correctness: use `code-review`.
- The task is writing documentation rather than designing an interface: use `technical-writing`.
- The work is visual identity, logo, brand palette or marketing copy: state that it is out of scope
  for this skill rather than improvising brand rules.
- The task is a read-only security or performance review of a running system: use the matching
  `linux-*` or `security-audit` skill instead.

## Required Inputs

| Artefact | Source/provider | Required? | If absent |
| --- | --- | ---: | --- |
| Design target (screen, flow or component) | Operator request, repo, existing UI | Yes | Identify the smallest defensible scope from the repo and log the assumption |
| Users, domain and stakes | Repo docs, product context, operator | No | Assume trained users and a non-critical domain; record the assumption in the decision log |
| Existing design system, tokens, theme | Repository CSS/theme files | No | Follow the patterns already in the product; introduce a minimal token set rather than restyling |
| Accessibility target | Operator | No | Default to WCAG 2.1 Level AA and say so in the hand-off |
| Prototype medium | Figma availability, repo, request | No | Work in markdown wireframes or a static HTML mock-up; do not invent a tool dependency |
| Safety gate (AGENTS.md section 0) | Always in force | Yes | A mutation failing the gate is skipped and reported; design work continues read-only |

## Workflow

1. **Understand the work, not just the screen.** Learn the domain terms, roles and constraints that
   the interface serves before proposing layout. Observe real conditions where they are known:
   interruptions, long waits, hand-offs between roles, existing tools in the loop.
2. **Frame the constraints in writing.** Regulation, risk tolerance, data volume, integration points
   and expert-versus-novice audiences become the boundaries of the idea space, not objections raised
   after a design exists.
3. **Pick the fidelity that answers the current question.** Sketch or wireframe while the question is
   "is this the right flow"; refine to pixels only after the flow is agreed. For a data-rich system,
   a low-fidelity walkthrough with a domain expert beats a polished mock-up nobody can validate.
4. **Apply the rulebook below** - the eight complex-application rules, the inclusive floor, the
   honesty rules and the naming discipline for any rule you state.
5. **Run the accessibility and inclusive pass** from `references/inclusive-design.md`: contrast,
   colour independence, target size, keyboard path, labels, error messaging, motion, plain language.
6. **Verify what you can and mark what you cannot.** Check the layout against the checklist, count
   the checks you actually ran, and label anything unrun as `NOT VERIFIED` with the reason. Stop and
   report if a requested design breaks a hard rule (safety, accessibility floor, dark pattern)
   instead of delivering it.
7. **Hand off the artefact** from the Outputs table, with the decision log and rule citations, so the
   next person can re-open any choice without you. Recovery: any design change must stay reversible -
   iterate on a branch or a copy, never on the only copy.

## Quality Standards

- **Salience first.** Every screen states its one primary piece of information; achieve emphasis by
  removing competing decoration at least as often as by adding weight or colour.
- **No long blind sequences.** A user never performs a long run of actions before seeing the result of
  the first: preview live, autosave, undo, confirm only where loss is real.
- **Staged disclosure.** Advanced options appear when they become relevant, never as a wall of fields;
  capability stays available behind disclosure.
- **Primary-to-secondary without leaving.** Tooltip, peek or side panel carries the detail; the
  working context stays on screen.
- **Flexible pathways.** Skip ahead, loop back, jump between steps, keep progress across navigation;
  no forced linear trap.
- **Working memory is the app's job.** Notes, history, status, breadcrumbs and resume-after-interruption
  are features, not polish.
- **Accessibility floor: WCAG 2.1 AA** - text contrast 4.5:1 (3:1 for large text), non-text and control
  contrast 3:1, meaning never carried by colour alone, targets at least 24x24 CSS px, full keyboard
  operability with visible focus, labelled inputs and errors that name the field and the fix.
- **Honest interaction.** No dark patterns: no confirmshaming, hidden costs, forced continuity,
  misdirection or sneaking items into a basket.
- **Rules are named honestly** - principle, guideline or heuristic as per `references/principle-nomenclature.md`;
  context and any evidence are stated with the rule.
- **Claims are checked.** Any number, contrast ratio or behaviour stated in a hand-off was verified or
  is labelled unverified.

## Anti-Patterns

- Decorating data with illustrative icons that compete with the numbers they surround. Fix: strip the
  ornament and let the value carry the salience.
- Shipping a linear wizard with no way back, forward or sideways once started. Fix: give an interactive
  sequence map that preserves progress.
- Hiding advanced capability entirely to make the screen look simple. Fix: staged disclosure keeps the
  capability reachable in context.
- Learning-by-doing turned destructive: experimentation that loses work or corrupts data. Fix: preview,
  autosave and undo so trial and error is free.
- Meaning carried by colour, position or jargon alone. Fix: pair colour with text or shape, and write
  the label a domain expert would say aloud.
- Presenting a heuristic as a proven principle to win an argument. Fix: label it a heuristic, state the
  context, and note the evidence it rests on.
- Evaluating a design only by whether a task was completed, never by whether the reasoning was supported.
  Fix: ask the domain expert to talk through the decision the screen is meant to serve.
- Reaching for a pixel-perfect prototype before the flow is agreed. Fix: drop fidelity until the
  question is narrow enough for the medium to answer it.

## Outputs

| Artefact | Consumer | Acceptance condition |
| --- | --- | --- |
| Screen flow or wireframe set | Implementer | Every state, empty case and error path is represented, with the primary information marked |
| Design spec or annotated markup | Implementer | Layout, hierarchy, copy and interaction rules are unambiguous without the designer present |
| Rulebook compliance checklist | Reviewer | Each rule invoked is cited, each check marked run or `NOT VERIFIED` |
| Accessibility notes | Implementer, reviewer | Contrast, targets, keyboard path, labelling and motion each carry a status |
| Decision log | Operator | Assumptions, constraints and rejected options are recorded with the reason |

## Evidence Produced

| Evidence | Artefact and format | Consumer | Acceptance condition |
| --- | --- | --- | --- |
| Rulebook compliance record | Checklist in markdown, embedded in the hand-off | Reviewer | Every applicable rule states `PASS`, `FAIL` or `NOT VERIFIED` with a reason |
| Verification record | Screenshot, executed check, or measured value in the hand-off | Operator | No claim of a test that was not run |

## Capability Contract

Reading the repository, design sources and reference files is always permitted. Editing files,
creating prototypes or generating assets needs the permission granted for the authoring task.
Publishing, deleting a design system, or overwriting someone else's design source needs separate
authorisation.

## Degraded Mode

If a reference file is missing or unreadable, fall back to the condensed rulebook in this file and
record which references were unavailable. If the design library at `~/Documents/design/`
is absent, the rulebook below still stands on its own. If no rendering or browser check is possible,
deliver the design as markup and mark visual verification `NOT VERIFIED`; never report an inspection
that did not happen.

## Decision Rules

| Condition | Action | Failure or risk avoided |
| --- | --- | --- |
| Two layouts both satisfy the task | Keep the one that defers more to secondary detail and removes more decoration | Clutter accumulates silently when every option is defensible |
| A requested element has no job in the primary task | Move it behind staged disclosure or drop it | Visual search degrades and the primary information loses salience |
| Expert and novice needs conflict | Serve both with staged disclosure, not with two interfaces | Capability shrinks for one audience or noise grows for the other |
| Flow cannot be validated at high fidelity | Drop to wireframe and walk it with a domain expert | Polishing an unvalidated flow burns the budget on the wrong idea |
| A hard rule (safety, accessibility floor, dark pattern) is violated | Stop, report the conflict, offer the compliant alternative | Shipping an unusable or manipulative interface |
| A design claim cannot be verified here | Mark it `NOT VERIFIED` with the reason | False confidence in a hand-off nobody re-checks |

## Worked Example

A settings dialog for a collaborative data model. The naive version shows every permission field at
once and loses the user. Applying the rulebook: the primary action sits first; the
"mark this setting as private" checkbox is the primary control; the "give permissions to" sub-setting
appears only after it is checked (staged disclosure); a hover on any permission row reveals who
already holds it (primary-to-secondary without leaving); every destructive change is undoable and
previewed before commit (learning by doing without loss); contrast, focus order and labels pass the
accessibility floor; the dialog states its own status in words, not colour alone.

## References

- [references/complex-app-guidelines.md](references/complex-app-guidelines.md) - the eight
  complex-application guidelines in depth, with the pattern each one implies.
- [references/ux-lifecycle.md](references/ux-lifecycle.md) - the Understand, Explore and Materialize
  phases adapted for expert, high-stakes domains.
- [references/principle-nomenclature.md](references/principle-nomenclature.md) - what makes a rule a
  principle, a guideline or a heuristic, and how rules should be phrased and validated.
- [references/inclusive-design.md](references/inclusive-design.md) - inclusive design, the
  design-thinking cycle, Figma prototyping practice, evaluation methods and dark patterns.
- Sources held in `~/Documents/design/`: the two articles named at the top of this file,
  Fu, Yang and Wood (2015), *Design Principles: The Foundation of Design*, ASME IDETC/CIE paper
  DETC2015-46157, and
  [Kimseng et al. (2023), JINAV 4(2)](https://doi.org/10.35877/454RI.jinav2257).

<!-- dual-compat-end -->
