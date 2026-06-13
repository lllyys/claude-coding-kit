# 06 — No Self-Designed UI

Don't invent UI/UX. When a project has a user-facing interface, its visual design comes from a
**design source first** — not from the agent improvising. (For a project with no UI — a CLI,
library, or service — this rule is inert; drop it from your `@import` list.)

## Hard rule

If a feature, bug fix, or slice needs a UI surface that is **not** depicted in a committed
design bundle under `dev-docs/designs/...`, **stop that slice** and file a `needs-design`
issue. The design is produced from your design source (e.g. `claude.ai/design`, a Figma
handoff, or a committed design spec), committed to the repo, and only then does the slice
resume.

Applies to:

- New screens / pages / views, and modals, sheets, dialogs, popovers, alerts, toasts.
- New rows, sections, settings entries, buttons, indicators, or empty states within an
  existing screen.
- New visual states (loading, error, empty, partial, in-progress) not depicted in the design.
- "Placeholder" UI introduced with intent to re-skin later — same prohibition.
- UI affordances introduced by a bug fix (a new confirmation dialog, a new status chip).

## What "designed" means

A surface is **designed** when ALL of the following hold:

1. A committed design bundle exists at `dev-docs/designs/<bundle-name>/`.
2. The specific surface (screen, sheet, popover, interaction state) is depicted in that bundle
   — by name and by visual content.
3. "Looks similar to existing X" does NOT count. "Inherits the same chrome" does NOT count.
   The actual surface must appear in the design.

If you cannot point at a file in `dev-docs/designs/` that shows the surface you're about to
build, it is **not designed**.

## Workflow

1. **Stop that slice.** Don't write the view. Don't write a placeholder. Don't improvise.
2. **File a `needs-design` issue** — title `Design needed: <surface> for #<N>`; labels
   `enhancement` + `needs-design`; body lists the surface, the parent feature/bug (`Refs #<N>`),
   the behavior the UI must expose, current screenshots if any, and the states the design must
   cover (default, loading, error, empty, …).
3. **Pause that slice** in the tracker — add a `BLOCKED: needs-design (#<new-issue>)` note.
4. **Continue parallel slices** that DO have a committed design (see `48-parallel-execution.md`).
5. **Design loop**: the design source produces a handoff bundle → it is committed under
   `dev-docs/designs/...` in its own change → the slice resumes.

## Not covered by this rule

- **Platform / framework chrome** rendered by default (status bars, default controls).
- **Pure code changes with no visible delta** — refactors, persistence/perf fixes, test-only.
- **Restoring broken UI back to its designed state** — fixing a mislabeled or hidden control.
- **Dev-only / verification artifacts** — never user-visible in a release build.
- **CLI / config / hook / script files** — never user-facing.

## Anti-patterns

| Anti-pattern | Why it fails | Right move |
|---|---|---|
| "I'll match the existing look for now" | That's self-designed UI; the existing look may be exactly what's being replaced. | File `needs-design`. |
| "Just a placeholder until v2" | Placeholders are committed code that ships. Fragmented UI across versions is worse than pausing. | File `needs-design`. |
| "It's a small dialog, a framework default is fine" | Defaults look fine in isolation but drift from the design system over time. | File `needs-design`. |
| Inventing UI for a bug-fix toast / status chip | Bug fixes introduce UI debt the same way features do. | File `needs-design`. |
| Inventing UI in a feature-workflow Gate 3 because the WI said "small" | If a WI's UI has no design, it was misclassified at Gate 1. | Stop the WI, file `needs-design`, fix the plan. |

## Relationship to other rules

- **`05-design-before-coding.md`** governs the *software* design (approach, interfaces) before
  any code. This rule governs the *visual* design before any UI code. Both are "design first,"
  at different layers.
- **`47-feature-workflow.md`** — a UI surface with no committed design means the WI was
  mis-scoped at Gate 1 (Plan); escalate rather than improvise.

## Tuning for your project

This rule assumes designs live under `dev-docs/designs/` and come from `claude.ai/design`.
Repoint both at whatever your team uses (Figma, a design-system package, a `design/` directory).
The cost of pausing a slice to file `needs-design` is far below the cost of shipping UI debt
that has to be re-skinned later — that trade-off is the whole point of the rule.
