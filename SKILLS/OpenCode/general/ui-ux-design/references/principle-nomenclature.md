# Naming a Design Rule: Principle, Guideline or Heuristic

Source: Fu, K. K., Yang, M. C., & Wood, K. L. (2015). *Design Principles: The Foundation of
Design*. ASME IDETC/CIE 2015, DETC2015-46157 (local copy in `~/Documents/design/`).
Paraphrased, not reproduced.

Designers of heuristics, guidelines and design rules borrowed each other's vocabulary for decades.
The paper's value for this skill is the formal separation, because it sets how firmly a rule may be
stated and what evidence it must carry.

## The three formal definitions

- **Principle** - a fundamental rule or law, induced from extensive experience and/or empirical
  evidence, giving design-process guidance that raises the chance of a successful solution.
- **Guideline** - a context-dependent directive, based on extensive experience and/or empirical
  evidence, giving design-process direction toward a successful solution.
- **Heuristic** - a context-dependent directive, based on intuition, tacit knowledge or experiential
  understanding, giving design-process direction toward a *satisfactory but not necessarily optimal*
  solution.

Common threads the authors observed across the literature: principles are never universally true -
they hold in a given context; they rest on experience, examples or evidence; they are more
generalisable than a single anecdote; and they serve as a foundation for building methods and tools.

## The four dimensions that order them

| Dimension | Ordering, weakest first |
| --- | --- |
| Supporting evidence or validation | heuristic -> guideline -> principle |
| Granularity / specificity | heuristic -> guideline -> principle |
| Formalisation | heuristic -> guideline -> principle |
| Prescriptive -> descriptive | guideline and heuristic are prescriptive; principles sit closer to the descriptive, algorithmic end |

Two further properties matter when stating a heuristic: it reduces search time rather than
guaranteeing an optimal result, and its value is usefulness in a specific context. A heuristic is
generally reliable but fallible, may contradict another heuristic, never guarantees a solution, and
is replaced when another one does the job better in a given context. It does not die; it fades from
use.

## The rest of the family (keep the distinctions)

- **Rule / commandment** - rules divide into algorithmic (cause and effect known, predictable
  results) and heuristic (anything that cannot be converted into an algorithm). Commandments are
  prescriptive, belief-based, and written to spark discussion rather than to constrain.
- **Standard** - a documented agreement carrying precise, consistently applied technical criteria,
  typically backed by regulation. The firmest of the family.
- **Axiom** - a generalisable principle governing system behaviour, self-evident with no
  counterexamples (Suh's Axiomatic Design). More stringent than a principle.
- **Algorithm** - a prescription of the design process whose outcome can be derived.
- **Ontology** - an explicit specification of a conceptualisation: the vocabulary of a domain.
- **Strategy / rule of thumb** - a careful plan over time; a procedure based on experience and
  common sense, roughly correct but not scientifically accurate. In practice used as a synonym for
  principle or heuristic, which is exactly the slippage to avoid.

## How to phrase a rule in a UI/UX task

1. **Name it honestly.** Call a rule a *principle* only when it rests on broad evidence; call it a
   *guideline* when it is context-dependent but evidence-based; call it a *heuristic* when it is
   experience-based and may fail.
2. **State the context.** Say where it applies - expert users, high stakes, dense data, mobile - and
   any condition that voids it.
3. **State the time stamp and intended users.** Design rules go stale as platforms and populations
   change; note the version, the platform or the year, and the background a user needs to apply it.
4. **Show the rationale.** A guideline in the literature has at least four parts: the issue it
   addresses, the context link, the recommended action and the rationale. Carry all four when the
   rule is used to reject a design.
5. **Expect conflict.** Principles can advance or undermine each other; when two rules collide, name
   both and record which one won and why.

## Deriving and validating a rule

From the review of 66 sources in the paper:

- **Derivation methods** observed in the literature: analysis of existing designs (most common -
  products, patents, nature, software), derivation from design practice, laboratory-based design
  studies, observation of expert designers, direct experience of expert authors, and existing
  principles from prior literature. The most common sources were existing designs, then principles
  by others (a deductive route), then experts' written experience.
- **Validation methods**: design project or task (usually 1-3 problems solved with the rule), analysis
  of existing designs, convergence/asymptotic analysis (collect examples until the count of principles
  plateaus), expert observation, and experience. The paper found that most publications never state
  how - or whether - their principles were validated, and that a large share report neither method,
  source nor sample size.

**Consequence for this skill:** when you assert a design rule as settled, say how it was validated or
say that it was not. Unvalidated experience is still usable - it is a heuristic - but it must be
labelled as one.

Related: [complex-app-guidelines.md](complex-app-guidelines.md) for the rules themselves and
[ux-lifecycle.md](ux-lifecycle.md) for when to apply them.
