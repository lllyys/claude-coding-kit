---
description: End-to-end GitHub issue resolver — fetch, classify, fix, audit, PR
argument-hint: "#123 [#456 ...]"
---

# Fix Issue

Resolve one or more GitHub issues end-to-end: fetch, classify, branch, fix with TDD, Codex audit loop, gate, docs-sync, version bump, PR, and close.

## Input

```text
$ARGUMENTS
```

## Pre-flight Checks

1. **Parse arguments** — extract issue numbers (e.g. `#123`, `123`, `#123 #456`).
   - No arguments: print usage and STOP.
2. **Working tree must be clean** — run `git status --porcelain`. If dirty, error and STOP.
3. **Confirm on main/up-to-date** — run `git branch --show-current` and `git fetch origin`.

## Single-Issue Pipeline

When exactly one issue number is provided, run phases 1-9 sequentially.

### Phase 1: Fetch & Classify

```bash
gh issue view {N} --json number,title,body,labels,state,assignees
```

- If issue not found or closed: warn user, ask whether to proceed, or STOP.
- Classify by labels or body content:

| Classification | Trigger | Path |
|---------------|---------|------|
| Bug | label contains `bug`, or body mentions error/crash/broken | Bug path (Phase 3a) |
| Feature | label contains `feature`/`enhancement` | **Redirect to `/feature-workflow` and STOP** (rule 47 — see Phase 3b) |
| Question | label contains `question` | Question path (Phase 3c) |
| Ambiguous | no matching labels | Ask user to classify |

### Phase 2: Branch Setup

- Generate slug from title: lowercase, strip non-ASCII, replace spaces with `-`, truncate to 40 chars.
- Branch name: `fix/issue-{N}-{slug}`. (Features don't branch here — they redirect to `/feature-workflow`.)
- If branch already exists: ask user — reuse or rename.
- Create and checkout the branch.

### Phase 3: Resolve

#### 3a. Bug Path

Follow the philosophy from `/fix` — no half measures.

1. **Reproduce** — Read relevant code, trace call chain from symptom to root cause. Reproduce via a failing test, or by running the app the way this project runs it (CLI, server, desktop, browser, or a library test harness, whatever applies) and observing the broken behavior.
2. **Diagnose** — Find root cause, check for similar patterns elsewhere.
3. **RED** — Write a failing test capturing the bug (see `.claude/rules/10-tdd.md`).
4. **GREEN** — Fix the root cause with minimal, focused changes.
5. **REFACTOR** — Clean up without changing behavior.

#### 3b. Feature Path — redirected, not handled here

**Always redirect feature/enhancement issues to `/feature-workflow` and STOP this pipeline.** `.claude/rules/47-feature-workflow.md` is binding for every feature (Plan → independent plan audit → TDD → implementation audit → integration verification → merge). This command can't run Gate 2 (independent plan audit in a separate context) or Gate 5 (integration verification + evidence) inline, so there is **no size threshold and no waiver** — every feature goes through `/feature-workflow`, however small. (Research routing for that work is described in rule 60 §8.)

#### 3c. Question Path

1. **Research** — Read code and docs to compose a thorough answer.
2. **Detect language** — Check the issue author's language from the issue title and body. Reply in the **same language** the author used (e.g. Chinese issue gets a Chinese reply, Japanese gets Japanese).
3. **Respond** — Post the answer as a comment in the author's language:
   ```bash
   gh issue comment {N} --body "{answer in author's language}"
   ```
4. **STOP** — No branch, no PR needed. Clean up the branch if created.

### Phase 4: Codex Audit Loop (max 3 iterations)

**Goal**: Targeted audit of changed files, not a generic sweep.

#### 4a. Collect changed files

```bash
git diff main --name-only
git diff main
```

#### 4b. Initial audit via the configured Codex runner

Run the project's configured **independent Codex audit runner**. Current
runner: **`cc-suite`**, which drives Codex through `codex exec` (a killable,
deadline-bounded CLI runner with job tracking). Do **NOT** use `ToolSearch
+codex` or the Codex MCP bridge (`mcp__codex__codex`) — cc-suite intentionally
avoids the bridge because it has no controllable timeout and hangs on long
responses (see `.claude/rules/53-codex-runner-isolation.md`). No availability
ping: the first real call completes or fails fast; on failure go straight to
**4f. Fallback**.

Default to a **read-only audit** via **`/cc-suite:audit`** (Codex audits, *you*
fix — this preserves the rule-48 author/auditor separation). Point it at the
changed files (`git diff main --name-only`) and have it focus on:

1. Correctness & logic — does the fix actually solve the root cause? No patching around symptoms.
2. Edge cases — boundary conditions, null/empty, malformed input, concurrent access.
3. Error handling — failures surfaced clearly; no swallowed errors, no silent fallbacks.
4. Security — no vulnerabilities introduced (injection, untrusted input); secret/credential hygiene (never logged, never bundled, never sent to the wrong destination).
5. No regressions — existing behavior preserved; the change doesn't break adjacent features.
6. Duplicate code — copy-paste patterns, repeated logic that should be unified.
7. Dead code — unused imports, unreachable branches, orphaned functions left behind.
8. Shortcuts & patches — workarounds, TODO markers, band-aids, flags to bypass broken logic.
9. Project conventions — follows this project's own layering, module boundaries, naming, and style rules; files stay reasonably small (~300 lines).

`/cc-suite:audit` reports findings as: `file:line | severity | issue | fix`.
(`/cc-suite:audit-fix` runs the full audit→fix→verify loop with Codex driving
the fixes — use it only if you want Codex-authored fixes and will review them
yourself. `/cc-suite:status | result | cancel` track a running job.)

#### 4c. Parse & fix

Fix **every** finding — Critical, High, Medium, and Low. No exceptions, no "note in PR" deferrals. The audit is not clean until the finding count is zero.

#### 4d. Verify

Re-run **`/cc-suite:audit`** on the updated diff to confirm every finding is
resolved and no new issue was introduced. (If you used `/cc-suite:audit-fix`,
its built-in verify pass already covers this.)

#### 4e. Loop or exit

- **Zero findings** (all severities): audit passes, exit loop.
- **Any findings remain** and iteration < 3: fix everything and verify again (goto 4c).
- 3 iterations reached with findings still open: STOP. Report all remaining issues to the user. Do NOT create a PR — the code is not ready.

#### 4f. Fallback — manual mini-audit

If the Codex runner is genuinely unavailable (the `codex` CLI is missing or
unauthenticated, or cc-suite errors), perform a manual mini-audit — read each
changed file and audit dimensions 1–8 from 4b above, fixing Critical/High inline.

#### 4g. Write the audit log artifact

**Required before merge.** The `check_codex_audit_artifact.sh` hook blocks
`gh pr merge` on a source-touching branch without an audit log. Write it before
the merge (recommended before PR creation so review sees it):

Path: `.claude/codex-audits/<branch-with-slashes-replaced-by-hyphens>-audit.md`

```markdown
---
branch: <current branch, exactly as `git branch --show-current` returns>
threadId: <Codex exec session id, or `manual-fallback` if 4f was used>
rounds: <integer ≥ 1>
final_verdict: ship-as-is | follow-up-recommended | block-recommended
date: YYYY-MM-DD
---
```

Body: per-round findings (`file:line | severity | issue | fix`), a resolution
note per finding, and a summary verdict. If you used manual fallback, add a
"Manual audit evidence" section per `.claude/rules/47-feature-workflow.md`.
Commit it alongside the fix (e.g. `chore: codex audit log for issue #{N}`)
before the PR opens.

### Phase 5: Gate

Run the project's build/gate command (the release-gate skill runs whatever
the project configures). Up to 3 attempts:

- Pass: proceed to docs-sync.
- Fail: read errors, fix, retry.
- 3 failures: report errors, keep branch, STOP.

Also verify sync rules:
- User-facing behavior changed? Verify by running the app the way this project runs it (CLI, server, desktop, browser, or a library test harness, whatever applies) and observing the behavior — automate with the project's E2E tool if it has one — and update docs as needed.

### Phase 5b: Docs-sync & Version Bump

- Sync the tracker: if this issue mirrors a row in `docs/bugs.md` / `docs/features.md`, update its status and Notes.
- **Version bump**: bump the project's source-of-truth version per rule 40 (patch for a bug fix, minor for a feature).

### Phase 6: Create PR

```bash
gh pr create --title "{type}: {concise description}" --body "$(cat <<'EOF'
## Summary

{1-3 bullet points describing what changed and why}

Refs #{N}

## What Changed

{list of key changes}

## Codex Audit

{audit summary — iterations run, findings fixed, remaining notes}

## Validation

- [x] Project build/gate command passes
- [x] Tests cover changed behavior (TDD)
- [x] Codex audit loop completed ({M} iterations)
- [x] Version bumped (rule 40)
{- [x] Verified by running the app (if user-facing behavior changed)}

## Type of Change

- [{x if bug}] Bug fix
- [{x if feature}] Feature
EOF
)"
```

Report the PR URL to the user.

### Phase 9: Post-Merge Close Gate

The issue stays open after merge. Do not use an auto-closing PR keyword and do
not close it merely because the PR landed.

1. Immediately after merge, apply the `awaiting-verification` label and comment
   with the shipped version and merge commit SHA.
2. Check out the merged build on `main` and re-run the original reproduction
   using the app's real execution path (or the skill's documented
   high-fidelity verification-exception path when run-the-app reproduction is
   physically impossible).
3. Record what was tested and observed. For the exception path, write
   `dev-docs/verification/bug-{N}-{YYYYMMDD}.md` using
   `dev-docs/verification/SCHEMA.md`.
4. Only after verification passes, post a closure comment citing the merge SHA,
   verification method, observed result, and evidence file when applicable;
   then close:

   ```bash
   gh issue close {N}
   ```

If verification fails or is blocked, keep the issue open and follow the
`fix-issue` skill's Phase 9 label/follow-up rules.

---

## Multi-Issue Pipeline

When multiple issue numbers are provided (e.g. `#123 #456 #789`).

### M1: Fetch & Validate All

Fetch all issues in parallel:
```bash
gh issue view {N} --json number,title,body,labels,state
```

- Filter out closed issues (warn user).
- Filter out questions (handle inline with `gh issue comment`, no worktree needed).
- Filter out features/enhancements (redirect each to `/feature-workflow` per rule 47; no worktree).
- Remaining issues proceed to worktree pipeline.

### M2: Create Worktrees

For each issue, create an isolated git worktree:
```bash
git worktree add ../<repo>-worktree-{N} -b fix/issue-{N}-{slug} main
```

### M3: Parallel Execution

Spawn one Task agent per issue, each running the **full single-issue pipeline** (Phases 1-6) inside its worktree directory.

Use the Task tool with `subagent_type: "general-purpose"` and `run_in_background: true` for each.

### M4: Collect Results

After all agents complete, display a summary table:

```
| Issue | Status | Branch | PR |
|-------|--------|--------|----|
| #123  | Done   | fix/issue-123-slug | #45 |
| #456  | Failed (gate) | fix/issue-456-slug | — |
```

### M5: Cleanup Worktrees

```bash
# Remove successful worktrees
git worktree remove ../<repo>-worktree-{N}

# Keep failed ones for investigation
```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| No arguments | Print usage, STOP |
| Issue not found / closed | Warn, ask user |
| Dirty working tree | Error, STOP |
| No labels (ambiguous type) | Ask user to classify |
| Codex runner (cc-suite) unavailable | Fall back to manual mini-audit (Phase 4f) |
| Gate fails 3x | Report errors, keep branch, STOP |
| Feature / enhancement issue | Redirect to `/feature-workflow` and STOP (rule 47 — no size threshold) |
| Branch already exists | Ask user: reuse or rename |
| Non-ASCII characters in title | Strip to ASCII for branch slug |
