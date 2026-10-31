# Eight Guidelines for Complex Applications

Source: *8 Design Guidelines for Complex Applications* (local copy in
`~/Documents/design/`). Paraphrased, not reproduced; examples re-expressed for this
skill.

A "complex application" in this sense is software that serves broad, unstructured goals or
non-linear workflows of highly trained users in specialised domains - research, defence, finance,
operations. Such products usually: support trained users with specialised knowledge; handle large
data sets and sense-making; support goals whose sub-tasks are not known in advance; require hand-off
between roles, tools or platforms; and carry stakes where a mistake costs money or worse.

## 1. Promote learning by doing

People start using a system immediately rather than reading about it first - the paradox of the
active user. Trial and error must therefore be safe: experimentation cannot cost work or cause
irreversible damage. Complication: a long chain of actions whose results only appear at the end
breaks this, because the user cannot tell where their intent diverged from the system's behaviour.

**Design implications:** live preview while constructing (a dashboard widget updating as filters are
set); frequent, cheap feedback points; autosave and undo; destructive operations confirmed only when
the loss is real. In safety-critical domains the freedom is bounded, not removed.

## 2. Help users adopt more efficient methods

Left alone, most users plateau at a merely satisfactory level - they satisfice, keeping an
inefficient method that works rather than discovering a better one. Over years of daily use that gap
compounds into a large productivity loss.

**Design implications:** teach the faster path in context, at the moment of the task - a tooltip that
says "you can also drag the file here", a keyboard shortcut revealed beside the menu item, a recent
actions row that suggests a batch operation. Do not rely on a manual the user will never open, and
do not interrupt the work with a tutorial tour.

## 3. Provide flexible and fluid pathways

Users pursue unstructured goals non-linearly; they may not know the end state and are analysing to
find it. Rigid wizards that force start-to-finish sequences with no escape hatch fight the way the
work actually happens.

**Design implications:** allow skipping ahead, looping back, and moving between any two steps; keep
progress when the user jumps; expose an interactive sequence map inside a wizard so steps are
clickable targets in any order; make every step's state recoverable.

## 4. Help users track actions and thought processes

Complex work involves long waits, interruptions and pivots, and users must hold much in working
memory. When attention breaks, the reasoning behind a half-finished analysis is what disappears first.

**Design implications:** let the user record open-ended notes attached to the object being worked on -
a comment on a chart, a rationale on a model, a status flag on a query; show history and recent
actions; support resuming after an interruption with the previous state intact. Notes written today
are the memory of the user who returns in three weeks.

## 5. Coordinate transitions among multiple tools and workspaces

Expert work spans tools: gathering data elsewhere, referencing documents, writing commentary in a
different application, switching to add-ons or sub-environments inside the primary tool.

**Design implications:** design the seams deliberately - export to the format people actually paste
into (spreadsheet, image, clipboard), deep links back into context, copy-visual-as-image on every
chart, import that preserves provenance. Reducing the cost of switching is a feature, not a
concession.

## 6. Reduce clutter without reducing capability

One product serves many scenarios and both novices and experts at once, so the naive interface is a
wall of options that are rarely all relevant at the same moment.

**Design implications:** staged disclosure - show advanced parameters when the related base option is
chosen or the item is in focus; group by task rather than by implementation; search over menus;
remember the user's last configuration. Capability stays; the appearance of overload goes.

## 7. Ease transition between primary and secondary information

Not everything can or should be on the primary surface, yet secondary detail is often what the
primary decision depends on.

**Design implications:** bring secondary detail to the user instead of sending them away - hover
tooltips with precise values, side panels, expandable rows, peek views, and breadcrumbs back. The
rule: a user should never leave the working screen to answer a question the screen itself raises.

## 8. Make important information visually salient

Tables, alerts and dashboards all impose visual search; competing elements make that search slower
and error-prone.

**Design implications:** the guideline cuts both ways - emphasis can be added (weight, colour, size),
but removing non-essential elements is often more effective. Decorative icons next to figures,
uniform weight on critical and trivial rows, and alerts that all shout the same volume all destroy
salience. Decide what must be found first, then clear the field for it.

## How to use these eight

Treat them as the review checklist for any non-trivial interface: run the eight against the design
before hand-off, record each as `PASS`, `FAIL` or `NOT VERIFIED`, and cite the number when pushing
back on a request. See [principle-nomenclature.md](principle-nomenclature.md) for how firmly each
statement may be phrased.
