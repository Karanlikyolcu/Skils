# Technical Debt

## The four quadrants

Classify every item before deciding what to do with it.

| | **Low value** | **High value** |
|---|---|---|
| **Low risk** | Opportunistic cleanup | The good stuff: fix it now |
| **High risk** | Ignore entirely | Plan and pay down deliberately |

- **Low value, low risk**: delete it when you touch it. Do not schedule work for it.
- **High value, low risk**: fix immediately. These are cheap wins and they keep paying.
- **Low value, high risk**: leave it. A risky change for no benefit is not a cleanup, it is a new risk. Do not even schedule it.
- **High value, high risk**: these need a plan, a budget, and a dedicated window. They are the ones worth arguing about in a planning meeting.

## Prioritization

```
priority = (blast_radius x pain_frequency x change_rate) / fix_cost
```

Where:

- **blast_radius**: how many modules, users, or systems break if this stays broken. 1 = local, 10 = system-wide.
- **pain_frequency**: how often this actually causes a problem (bug reports, workarounds, blocked features, slow deploys). Not how annoying it looks.
- **change_rate**: how often the code is touched. Debt in code that changes weekly compounds; debt in dead code does not.
- **fix_cost**: engineer-days including testing and rollout risk. Be honest here, it is where estimates go wrong.

## Sources of debt

- **Shortcut taken under deadline pressure.** Usually the cheapest to pay back, because the context is known.
- **Knowledge never captured.** The reason for a design lived in someone's head. Fix with a comment or an ADR.
- **Missing tests.** Makes every future change riskier. High change_rate makes this quadratically bad.
- **Duplication.** Fine at two instances, costly at five. Watch for the third.
- **Stale abstraction.** A generic layer built for a case that never arrived. Removing it is usually quick.
- **Dependency rot.** A library two versions behind, or an internal module nobody owns.
- **Process debt.** Slow CI, manual release steps, no rollback. Sometimes the highest-leverage fix in the repo.

## Common debt items and the right response

| Item | Response |
|------|----------|
| Duplicated code in 2 places | Leave it. Wait for the third. |
| Duplicated code in 4 places | Extract now. |
| Unused code | Delete it. Git remembers. |
| Function over 200 lines | Split, but only if you are already in the file. |
| Messy test setup | Extract a builder or fixture. High leverage. |
| Missing type annotations | Add where the type is unclear, not everywhere. |
| Outdated dependency | Bump in a separate commit, run the tests. |
| Slow test suite | Fix the setup, not the assertions. |
| Feature flag with one user | Remove the flag, keep the branch simple. |

## The 20% rule

When you touch a file for an unrelated reason, you are allowed to clean up that file. Not the codebase - the file.

This is the most reliable debt payment mechanism in practice, because the context is loaded and the tests exist. It fails when applied as a pretense for unrelated refactoring in a bugfix commit. Keep it separate: a cleanup commit that changes only readability, no behavior.

## Refactoring strategies

**Extract function** - pull a block into a named unit. The safest first move.

**Inline function** - the opposite. Use when a function has one caller, a confusing name, and no useful abstraction.

**Extract variable** - name an expression. Almost always an improvement.

**Replace conditional with polymorphism** - replace a switch on type with a type that owns the behavior. Do it when the switch keeps growing.

**Move method** - move behavior to the class that owns the data.

**Introduce parameter object** - collapse a long parameter list.

**Replace magic with constant** - name it, put it in one place, and make it configurable only if it genuinely varies.

**Replace magic with function** - when the expression has a name and a meaning.

**Introduce facade** - when a legacy module is used in many places and you want one stable entry point to change later.

**Replace conditional with guard clause** - flatten nested `if` logic. Prefer early returns.

## When NOT to refactor

- While debugging a production incident. Fix, deploy, then refactor separately.
- When the test suite is not green. You cannot refactor safely without tests.
- Right before a deadline with no post-deadline time for the cleanup.
- When you do not understand why the code is the way it is. Read, find out, then change it.
- Across more than a couple of modules in a single change. Split the work.

## Paying it down

1. Write the intent down. What breaks if we do nothing, and when will that start to hurt?
2. Get a test around the behavior you are about to change. Characterization tests if there are none.
3. Do it in small steps, each one green.
4. Verify with the real checks, not by inspection.
5. Update the documentation that described the old behavior.

## Tracking

Keep a short list, not a spreadsheet. Each entry: what, why it matters, rough cost, and the trigger that says to fix it now ("when we next touch the payments module"). If nobody can name the trigger, it belongs in the ignore list.

Revisit the list quarterly and delete entries that no longer matter. A debt list that only grows stops being a decision tool.
