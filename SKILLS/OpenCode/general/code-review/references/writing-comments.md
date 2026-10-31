# Writing Review Comments

## The anatomy of a comment

```text
[severity] What is wrong, and why it matters.
[location] file:line
[fix] The concrete change, if you know it.
```

**Example:**

> **[blocking]** This loads every order and filters in Python. At the current volume (~2M rows/month) that will exhaust the worker's memory, and it runs on every request.
> `src/api/orders.py:42`
> Push the filter into the query. The `select_orders(status, limit)` helper already does this and returns the same shape.

Three parts, in that order:
1. **Severity.** Blocking, should fix, or optional.
2. **The problem and its impact.** Not just what is wrong, but what it costs.
3. **The fix.** If you know it. If it is genuinely the author's call, say what you are worried about and ask.

## Severity language

Use the same three words every time, so the author learns them:

- **[blocking]** - a correctness, security, data-loss, or contract break. Must change before merge.
- **[should-fix]** - a real defect or a significant maintainability problem.
- **[optional]** - a suggestion. The author decides.
- **[question]** - you need information, not a fix.

Do not invent new severity words. "Important", "critical", "minor", "nit" all mean nothing to a reader who has to triage.

## Rules

**One issue per comment.** A comment listing six problems gets one response and five surviving bugs.

**Explain why, not only what.**

> Bad: "Use `select_orders` instead."
> Good: "This loads every order and filters in Python, which will exhaust memory at production volume. `select_orders` does the filtering in SQL and returns the same shape."

The second version teaches the author something they can apply next time.

**Be specific.** "This is inefficient" is not reviewable. Name the operation, the data volume, and the consequence.

**Distinguish a question from a defect.**

> Defect: "This crashes with a null `customer`."
> Question: "Is `customer` guaranteed to be non-null here? I cannot see it being set on the path from the webhook handler."

**Do not rewrite the diff.** A review is not a pull request with comments. If the change needs a rewrite, say so and explain why, then let the author decide how to do it.

**Reference the codebase, not a style guide the linter already enforces.** Formatting belongs to the formatter.

**Explain the impact of a change to an invariant.** If a function used to be pure and now writes to the database, that is worth a comment even if the code is correct.

## Praise

Say what was done well, specifically. It tells the author what to keep doing, and it makes the review a conversation rather than a list.

> The error handling here is exactly right - the retry is bounded, the fallback is safe, and the log line has the request ID. Nice.

Do not praise vaguely ("looks good") and do not praise by contrast ("much better than the last PR"), which is not useful feedback.

## Tone

- Assume good intent. The author probably had a reason you do not know yet.
- Attack the code, not the person. "This is wrong", not "you got this wrong".
- Do not use rhetorical questions as a way to make a point ("don't you think this could cause an issue?"). State the concern.
- No sarcasm. It does not survive being read in a diff six months later.
- Do not pad. A short review that matters is better than a long one that does not.

## When to use a thread versus a top-level comment

- **Top-level**: the finding applies to the change as a whole, or to a design decision.
- **Thread**: it applies to one line and the author can resolve it there.
- **A separate issue**: it is not about this diff at all. Do not bury it in a review.

## When you have a lot of comments

- If the diff is large enough that you have 30 comments, the change is too large. Say so at the top, and suggest splitting it. That single comment is worth more than the 29 that follow.
- Group related comments. "Four tests share this setup problem" is one comment with four locations, not four comments.
- Lead with the design-level findings. Line-level nits come last, and can be skipped if the author is out of time.

## Verdict language

**Approve**

> No blocking issues. The two optional notes are not worth holding the PR for.

**Approve with comments**

> No blocking issues. The inline note about the pagination default is worth a follow-up issue, but it does not need to land with this.

**Request changes**

> Requesting changes. The two blocking items are the N+1 in the list handler and the missing tenant filter on the export query. Everything else looks good.

**Need information**

> I cannot finish the review without knowing whether the webhook retries. Can you confirm the retry policy and whether the handler is idempotent?

Do not leave a blocking issue in a review you approved. Fix it or reclassify it.

## Template

```markdown
## Summary

One paragraph: what the change does, and whether it achieves it.

## Blocking

- **[blocking]** <issue> - `<file>:<line>` - <why it matters> - <fix>

## Should fix

- **[should-fix]** <issue> - `<file>:<line>` - <why> - <fix>

## Optional

- **[optional]** <suggestion> - `<file>:<line>`

## Questions

- <question> - `<file>:<line>`

## Verdict

Approve | Approve with comments | Request changes | Needs information
```

Not every review needs the full template. A one-line PR gets three lines. A large PR gets the full structure.

## Reviewing your own work before handing it over

Apply the same checklist to your own diff. It catches most of what a reviewer would catch, and it is much cheaper than a round trip.

```sh
git diff main...HEAD
git diff --stat main...HEAD
```

- Read the diff as if you were a reviewer who has never seen the code.
- Remove unrelated changes.
- Remove debug code.
- Check for secrets.
- Confirm every new behaviour has a test, and that the test fails without the change.
- Run the full suite, lint, and typecheck.
- Confirm the error path is handled and logged.
- Confirm the migration is reversible and its deploy order is clear.

Then write the PR description as if you were the reviewer: what changed, why, how it was verified, and where to look.
