# Style Guide

## Sentence level

**Prefer short sentences.** One idea per sentence. If a sentence needs two commas and a semicolon, split it.

**Active voice.**

> The service retries the request. (active)
> The request is retried by the service. (passive)

Use passive only when the actor is unknown or irrelevant ("the file was deleted").

**Address the reader directly.** "You" for instructions, "we" for the team, "it" for the system.

**Say the specific thing.** Not the category of the thing.

> Bad: The service has a configurable retry policy.
> Good: The service retries a failed request up to three times, with exponential backoff.

**Cut the throat-clearing.** Delete these on sight:

- It is important to note that
- As you may already know
- In this document we will
- Basically, essentially, actually, really, very
- Note that
- Please note
- It should be mentioned that

**Use "must", "should", and "may" precisely.**

| Word | Meaning |
|------|---------|
| must | A hard requirement. Violating it is a bug. |
| should | A strong recommendation. Following it is expected unless there is a reason not to. |
| may | A genuine option. |
| will | A statement of fact about what the system does. |

**Avoid hedges in technical docs.** "This may sometimes cause issues" hides a real behaviour. Say what it does.

## Terms and consistency

- **One concept, one term.** If it is a "customer" in one module and a "user" in another, that is a modelling problem, not a writing preference.
- **Define the acronym on first use.** "The service control manager (SCM) restarts..."
- **Use the product's own terminology.** If the UI says "Workspace", the docs say "Workspace", not "project space".
- **Do not translate the product's names.** "Sign in", not "log in", if the button says "Sign in".
- **Keep a glossary** for a project with more than about ten domain terms.

## Formatting

**Headings**

- Sentence case: "Configure the database", not "Configure The Database".
- Every heading is a promise. If the heading says "Install the agent", the section installs the agent.
- Heading levels describe structure, not size. Do not skip a level.
- A heading should be findable. Use the words someone would search for.

**Lists**

- Numbered lists for ordered steps. Bullets for unordered items.
- Parallel structure: every bullet starts the same way and is the same kind of thing.
- One idea per bullet.

**Code**

- Fenced blocks with a language tag: ```bash, ```python, ```json.
- Long commands on one line. Split with `\` only when necessary, and the continuation must be obvious.
- Show the prompt (`$`) only in interactive walkthroughs, not in copy-paste blocks.
- Never put a secret in a code block, even a fake one that looks real.

**Emphasis**

- Bold for the one phrase that matters. If everything is bold, nothing is.
- Italic for a variable or a term being introduced, sparingly.
- Never bold a whole sentence.
- Use a code span for identifiers, file paths, flags, and literal values.

**Tables**

- Only for genuinely tabular information with a consistent shape.
- Not for two rows. Not for prose.
- A header row that says what each column is.
- Keep it narrow enough to read on a laptop.

**Links**

- Link text describes the destination: "the API reference", not "click here" or "this".
- Relative links for files in the same repository.
- Absolute links for external destinations.

## Punctuation

- **Serial comma.** "a, b, and c".
- **The Oxford comma is optional in prose but keep it consistent.** In a list of three or more items, use it.
- **One space after a period.** Not two.
- **No space before a colon, semicolon, or comma.**
- **Ellipsis: three dots, or the Unicode character.** Pick one.
- **Em dash with no spaces**, or a comma. Not both.
- **Quote marks**: double quotes for strings in prose, backticks for code and literal values.

## Capitalisation

- Sentence case for headings and UI labels.
- Lowercase for function and variable names.
- Capitalise proper nouns: Kubernetes, PostgreSQL, macOS, Linux, JavaScript.
- Do not capitalise the second word of a sentence after a colon unless it is a proper noun.

## Numbers and units

- Spell out numbers below ten in prose, unless the number is a measurement or a specific identifier. "Three retries" not "3 retries" in a sentence; "retry 3" in a log message.
- Always a space between the number and the unit: "20 ms", "3 GB".
- Use SI: MB not Mb, seconds not sec (except in code), 1000 not 1k in prose.
- Times are UTC unless stated. Say so.
- Money: state the currency and the unit. "1,200 JPY" not "1,200".

## Error messages

The user-facing text in an error message follows the same rules as documentation:

- Say what happened, in the user's terms.
- Say what the user can do next.
- No internal identifiers, stack traces, or jargon.
- No blame. "Your session expired" not "Invalid token".

```python
raise ValidationError(
    f"'{field}' must be a valid email address. "
    f"Example: name@example.com",
    field=field,
)
```

## Documentation-specific conventions

- **Code blocks in a tutorial must be complete.** No `...` in a line the reader has to write.
- **Every command in a how-to must be runnable as written**, with the prerequisites installed.
- **Show the expected output** after a command in a walkthrough.
- **Never use a placeholder that looks like a real secret.** Use an obviously fake value
  such as `sk_test_example` or `<your-key>`, not a string copied from a real dashboard.
- **Date anything that goes stale**, and say which version it applies to.

## Words to avoid

| Instead of | Write |
|------------|-------|
| simply, just, easily | the actual instruction, or nothing |
| obviously, clearly | the actual reason, or nothing |
| of course | nothing |
| etc. | the actual list, or "and so on" |
| i.e. | that is |
| e.g. | for example |
| utilize | use |
| leverage (as a verb) | use |
| in order to | to |
| due to the fact that | because |
| at this point in time | now |
| prior to | before |
| subsequent to | after |
| very, really, quite | nothing, or a stronger word |

## Review checklist

- [ ] Every sentence says one thing
- [ ] Active voice, except where the actor does not matter
- [ ] No throat-clearing phrases
- [ ] The specific thing is named, not its category
- [ ] "Must", "should", and "may" are used precisely
- [ ] Every acronym is defined on first use
- [ ] Terminology is consistent with the product
- [ ] Headings are sentence case and are findable
- [ ] Every heading keeps its promise
- [ ] Lists are parallel and one idea per item
- [ ] Code blocks have a language tag and are complete
- [ ] Bold is used sparingly
- [ ] Links describe their destination
- [ ] Units have a space before them
- [ ] No placeholder that looks like a real credential
- [ ] Every command has been run
- [ ] Every link has been checked
