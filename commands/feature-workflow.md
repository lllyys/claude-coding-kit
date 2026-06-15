---
description: Run the binding six-gate feature workflow from rule 47
argument-hint: "[feature-id | slug]"
---

# Feature Workflow

Use the `feature-workflow` skill to execute this command.

The skill and `.claude/rules/47-feature-workflow.md` are authoritative. Follow
their binding six-gate model end-to-end:

> Plan → Independent Plan Audit → TDD Implementation → Implementation Audit
> Loop → Gate 5a Pre-Merge Verification → Merge → Gate 5b Post-Merge Evidence

Do not substitute an abbreviated command-local workflow. In particular, preserve
author/auditor separation, per-WI Codex audit artifacts, merge transitions, and
the post-merge evidence file that requires the merge SHA.

Pass `$ARGUMENTS` through as the feature identifier. If it is empty, let the
skill list eligible tracker rows and ask the user to choose.
