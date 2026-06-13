# 05 — Design Before Coding

Produce a design before writing implementation code for any non-trivial change. Code is the
last step, not the first.

## The rule

- **MUST** sketch the approach before implementing anything non-trivial: the shape of the
  solution, the public interfaces / signatures it adds or changes, how data flows, the files
  it will touch, the edge cases it must handle, and at least one alternative considered and
  rejected (and why).
- **MUST** make that design explicit — in the plan, the PR/issue, or the chat — **before**
  the first line of implementation. Thinking it silently does not count; the design must be
  reviewable.
- **MUST** get alignment on the design when the change is ambiguous, cross-cutting, or hard to
  reverse, before coding. When the user is present, confirm the approach; when acting
  autonomously, write the design down, then proceed.
- **NEVER** jump straight to implementation for a new module, a new behavior, a public
  interface, a data-model change, or anything that spans multiple files.

## Trivial vs non-trivial

Skip the design step only for genuinely trivial changes:

| Trivial (no design needed) | Non-trivial (design first) |
|---|---|
| Typo / comment / docs wording | New module, command, or feature |
| One-line fix with an obvious cause | New or changed public interface / signature |
| Mechanical rename / formatting | Data-model / schema / persistence change |
| Import order, config value tweak | Anything cross-cutting or hard to reverse |
| | A bug fix whose root cause isn't understood yet |

When in doubt, write two or three sentences of design first. It is cheap.

## What a design looks like

A design is not a document for its own sake — it is the smallest explicit plan that lets a
reviewer (human or agent) catch a wrong approach **before** code is written. For most changes
that is a short list:

- **Goal** — what behavior changes, in one sentence.
- **Approach** — the shape of the solution; the key interface(s) / signature(s).
- **Touch set** — the files/modules it adds or changes, and what stays out of scope.
- **Edge cases** — the boundary and failure conditions it must handle.
- **Rejected** — at least one alternative considered, and why it lost.

Scale the design to the change: a few sentences for a small change, a plan file under
`dev-docs/plans/` for a feature.

## Relationship to other rules

- **`10-tdd.md`** — the design names the behavior; the **RED** test then encodes it. Design →
  failing test → minimal implementation → refactor. Designing first makes the test meaningful
  instead of reverse-engineered from the code.
- **`47-feature-workflow.md`** — this rule is the lightweight, always-on version of Gate 1
  (Plan). A full feature still goes through the gated plan + independent audit; a small change
  just needs its short design. Don't skip the design because a change is "too small for the
  workflow" — that is exactly when a wrong approach slips through.
- **`00-engineering-principles.md`** — read before you edit; design before you write.
