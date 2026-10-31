# The Design Lifecycle for Complex Applications

Source: *UX Strategies for Complex-Application Design* (local copy in
`~/Documents/design/`). Paraphrased, not reproduced.

Complex domains - healthcare, finance, logistics, defence - need no new process. They need the
ordinary design-thinking process, adjusted at each phase for expert users, layered institutions and
high-stakes decisions. The three phases below overlap and cycle; use them as a lens on whatever
process is already in place.

## Understand: research the work, not just the user

Conventional UX training studies a user's goals and behaviour. In a specialised domain behaviour is
shaped by jargon, institutional policy, regulation and domain reasoning, and expert users are hard
to reach in regulated or high-pressure settings. Understanding the *domain* therefore comes before
understanding the *interface*.

1. **Study the domain independent of the application.** Before looking at any screen, learn the
   goals, terminology, roles and constraints of the field the software serves - for a clinical tool,
   that means how care decisions are actually made and which documents carry authority, not how the
   form is filled in.
2. **Study the work in its own environment.** Isolated usability sessions miss interruptions,
   shared equipment, lighting, noise, mobility and cross-team coordination. Watching a real shift
   reveals constraints a lab can never produce, and those constraints drive layout, notification
   timing and visibility decisions.
3. **Triangulate methods and involve more actors.** No single person holds the whole picture.
   Combine interviews, workflow mapping and observation, and combine roles: frontline users,
   supervisors, adjacent teams. Layering perspectives exposes how work actually moves across people
   and organisational boundaries.

## Explore: generate ideas inside real constraints

Ideation in complex products is heavily constrained - compliance, integration with other tools, deep
domain workflows. Teams either think too narrowly for fear of proposing something infeasible, or
propose something unsafe. Prototyping is also harder: full data-rich systems cannot be simulated
quickly, and stakeholders from different professions speak different languages.

1. **Make the constraints generative.** Write down what makes a solution viable - regulatory limits,
   risk tolerance, workflow integration, data needs - and treat that list as the frame for
   creativity rather than as a list of objections. Ideas born inside the frame are both freer and
   feasible.
2. **Prototype at the fidelity the current question needs.** High fidelity is usually premature.
   Sketches, storyboards and clickable wireframes answer "is this the right flow" without
   committing to pixels; a simulated scenario can test an escalation path that would otherwise need
   live data.
3. **Co-create with domain experts.** Bring an expert in to diagram their current process, mark the
   friction points, and react to early concepts. Their response often reveals that a small change -
   one visualisation, one ordering - materially changes decision time.

## Materialize: test and refine in the real world

Testing is where complex products expose the gap between usability in theory and use in practice.
Domain-specific problems can appear in a session without being recognised; classic task-based
usability testing was built for simpler, more repeatable work; and expert participants are scarce
and expensive.

1. **Adapt existing evaluation methods.** Keep task-based testing but add what surfaces reasoning:
   scenario-based interviews, think-aloud discussion, longer contextual observation. Assess
   usefulness and alignment with domain expectations, not only whether the task was completed.
2. **Elicit expertise through collaboration.** You do not need to become the expert; you need
   partners who are. Review sessions, workshops and informal loops catch edge cases, unseen risks
   and mismatches between the UI's assumed mental model and the team's real one - often before a
   single line of production code.
3. **Break testing rules when you must.** When real experts are unavailable, internal staff with
   relevant knowledge give useful early input, provided the limitation is stated and the findings
   are re-validated with actual users later. A training session can double as structured feedback.

## Summary of the adaptations

- Ground research in the real work, in the real place, across the real roles.
- Generate ideas within explicitly stated constraints, at the lowest fidelity that answers the
  question.
- Tailor evaluation so it reveals expert reasoning, not only task completion, and be pragmatic about
  who is available to test.

Related: [complex-app-guidelines.md](complex-app-guidelines.md) for the interface-side rules,
[inclusive-design.md](inclusive-design.md) for the empathise-define-ideate-prototype-test cycle and
accessibility floor.
