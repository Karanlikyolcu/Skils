# Inclusive Design, the Design-Thinking Cycle and Figma Prototyping

Source: Kimseng, N., Kurniab, D. A., Vuthy, I., Arifin, R. W., & Setiyadi, D. (2023).
*UI/UX Development Using Figma based on Inclusive Design*. JINAV: Journal of Information and
Visualization, 4(2), 227-234. DOI 10.35877/454RI.jinav2257 (local copy in
`~/Documents/design/`). Paraphrased, not reproduced.

## Why inclusive design is the frame

Accessibility in UI/UX has moved from an aesthetic nicety to a social and legal requirement, and the
population it serves includes people with disabilities, situational limitations and varied devices.
Start-ups and self-taught designers routinely lack accessibility training, so the practice has to be
written into the process rather than assumed. The paper's argument: pair a data-driven method with a
user-centric process, and use a prototype tool early enough that expensive implementation is never
committed to an unvalidated idea.

## The design-thinking cycle used in the paper

The flow sits at the intersection of desirability (people), viability (business) and feasibility
(technology) and runs:

1. **Empathise** - immerse in the users' experience to understand needs and difficulties.
2. **Define** - distil the empathise findings into a clear problem statement.
3. **Ideate** - generate many candidate solutions, valuing both quantity and quality.
4. **Prototype** - turn ideas into something tangible and walkable.
5. **Test** - present it, collect feedback, refine, and loop.

Each pass informs the next; the cycle is iterative, not a one-shot pipeline.

## Data sources for the work

- **Primary** - interviews, surveys and observations with the participants who matter: designers,
  developers, and people with disabilities who will actually use the thing.
- **Secondary** - existing research and prior work, used for context and background.
- **Quality gate on both** - assess credibility, relevance and reliability before letting a source
  shape the design, and confirm the material aligns with the project's stated goals.

## Inclusive and accessible practice (the floor this skill applies)

Beyond the WCAG numbers listed in the main rulebook:

- Design for the range of users first, then adapt - the same interface should serve disabled and
  non-disabled users rather than shipping a stripped alternate version.
- Keep the flows short and legible: splash or introduction, authentication, identity entry, then the
  actual task. Every step a user must survive before reaching value is a step someone abandons.
- Label everything in the user's own vocabulary; support resend, retry and recovery inside the flow
  rather than at the end.
- Continue accessibility education as part of the practice - standards move, and a designer's
  knowledge goes stale like any other.

## Deceptive design: the banned list

Dark patterns were named in the early 2010s for tricks that make users do what they did not intend -
forced sign-ups, hidden costs, confirmshaming, misdirection, sneaking items in. This skill treats
them as disqualifying: an interface that needs deception to convert is a design failure, and this
skill will not produce one. Honest defaults, visible prices and reversible actions are the floor.

## Prototyping in Figma (and equivalents)

- Prefer a **horizontal (low-fidelity) prototype** early, so no significant programming effort is
  spent on an idea that has not survived a walkthrough.
- Use **real-time collaboration** as an inclusion mechanism: domain experts and people with
  disabilities edit and comment in the file instead of reviewing a flattened image.
- Standardise with **components, variants and shared styles** so consistency is structural rather
  than remembered.
- The paper recommends going further - automating accessibility evaluation inside the tooling and
  using AI assistance to flag issues during design rather than after. Treat any such check as a
  prompt for human review, not as certification.

## Evaluation: effectiveness, efficiency, satisfaction

The study evaluated a mobile application on three axes - effectiveness, efficiency and satisfaction -
with a survey of 200 participants across staff and students, reporting a high task success rate and
satisfaction split across usefulness, user-friendliness, flow and feedback.

For this skill the transferable part is the method, not the numbers:

- Decide the axes up front: did it work, at what cost, and did it feel trustworthy.
- Ask about *flow* and *feedback* as distinct questions - a product can be useful and still feel
  disorganised.
- Sample sizing needs a deliberate choice of acceptable error; the paper tabulates sample sizes for
  1%, 5% and 10% error ranges from a population, which is the right habit even when the exact table
  is not used.
- Report results honestly: state population, method and limitations. A satisfaction figure without a
  method is decoration.

## Related

- [ux-lifecycle.md](ux-lifecycle.md) - Understand, Explore, Materialize for expert domains.
- [complex-app-guidelines.md](complex-app-guidelines.md) - the interface rules these methods feed.
