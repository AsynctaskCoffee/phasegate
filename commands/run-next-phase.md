---
description: Execute the next incomplete phase via the GitHub Issue state machine, enforce zero-bypass QA, record DONE_LOG.md memory, and commit/push on completion.
argument-hint: "[optional: phase-number]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# `/autonomous-team:run-next-phase`

Optional argument: `$ARGUMENTS`

Runs the next incomplete phase in the current repository, one issue at a time.

## 1. Load Project Context
Read these files in order before doing anything else. If any are missing, inform the user to run `/autonomous-team:start-project` first and stop:
1. `CLAUDE.md`
2. `SPEC.md`
3. `ARCHITECTURE.md`
4. `PLAN.md`
5. `DONE_LOG.md`
6. `STATUS.md`

## 2. Select Target Phase and Open Issues
1. If `$ARGUMENTS` contains a valid phase number, set `TARGET_PHASE` to it. Otherwise pick the lowest-numbered phase that still has open issues.
2. If no open phase issues exist, confirm all phases are done and print a final project summary.
3. Fetch open issues for `TARGET_PHASE`:
   ```bash
   gh issue list --state open --label "phase:${TARGET_PHASE}" --limit 100 --json number,title,labels,body
   ```
4. Order issues by dependency (if an issue is already `status:in-progress` or `status:test` from a previously interrupted session, resume that issue first to preserve WIP = 1).
5. Update `STATUS.md` to mark `TARGET_PHASE` active.

## 3. Execute Issues Sequentially (WIP = 1)

Helper rule for label transitions: always inspect the issue's current `status:*` labels first and remove only the ones actually present before adding the new label, so resuming an interrupted run never errors out.

For each issue (`ISSUE_NUM`) in `TARGET_PHASE`:

### 3.1. Enter `status:in-progress`
- Transition the issue's status label to `status:in-progress`.
- Update `STATUS.md` (`Active Issue: #<ISSUE_NUM>`, `Role: builder`, `State: status:in-progress`).
- Print status banner:
  `[PHASE <X>/<N> | ISSUE #<ISSUE_NUM> | ROLE: builder | STATE: status:in-progress | TESTS: pending]`

### 3.2. Implement (`autonomous-team:builder`)
Delegate implementation to the `autonomous-team:builder` subagent:
- Pass the full issue body plus relevant context from `ARCHITECTURE.md` and `DONE_LOG.md`.
- Builder writes production code and accompanying automated tests covering happy paths, edge cases, and failure paths, then verifies tests locally.

### 3.3. Enter `status:test` and Verify (`autonomous-team:qa-engineer`)
- Transition the issue's status label from `status:in-progress` to `status:test`.
- Update `STATUS.md` (`Role: qa-engineer`, `State: status:test`) and print the status banner.
- Delegate verification to the read-only `autonomous-team:qa-engineer` subagent:
  1. Runs all lint, format, type-check, build, and test commands from `CLAUDE.md` / `ARCHITECTURE.md`.
  2. Audits `git diff` for skipped tests or linter suppressions.
  3. Checks every acceptance criterion on the GitHub Issue against code and test evidence.
- **If `qa-engineer` returns FAIL:**
  - Transition label back to `status:in-progress`.
  - Send the exact failure report back to `autonomous-team:builder`, fix the root cause, and re-run `autonomous-team:qa-engineer`.
- **If the same failure persists after 3 consecutive attempts:**
  - Trigger `CLAUDE.md` Section 8 (Blocker Handling): switch label to `status:blocked`, document the error and all 3 attempts on the GitHub Issue and in `STATUS.md`, and stop immediately.

### 3.4. Log Memory and Close as `status:done`
Only after `qa-engineer` returns `PASS` with exit code `0` on every check:
1. Append a structured entry to `DONE_LOG.md`.
2. Post the exact same entry as a GitHub Issue comment:
   ```bash
   gh issue comment "$ISSUE_NUM" --body "<STRUCTURED_ENTRY>"
   ```
3. Transition label to `status:done` and close the issue:
   ```bash
   gh issue edit "$ISSUE_NUM" --remove-label "status:test" --add-label "status:done"
   gh issue close "$ISSUE_NUM"
   ```
4. Check off the task (`[x]`) in `PLAN.md`, update `STATUS.md`, and print the banner with `STATE: status:done`.

## 4. Phase Regression, Commit, and Push (`autonomous-team:release-manager`)
Once every issue in `TARGET_PHASE` is closed, delegate phase closure to `autonomous-team:release-manager`:
1. Run full regression (lint + build + test) across **every** surface in the repository.
2. Audit `git status` and `git diff --cached` for untracked junk or leaked secrets.
3. Mark `TARGET_PHASE` as `COMPLETED` in `PLAN.md` and update `STATUS.md` for the next phase.
4. Commit and push:
   ```bash
   git add -A
   git commit -m "feat(phase-${TARGET_PHASE}): <concise phase summary>

   Refs: #<n1>, #<n2>"
   git push origin main
   ```
5. Check the triggered workflow with `gh run list --limit 3`.

## 5. Report Phase Completion
Summarize for the user: completed phase, closed issues, test pass counts, commit SHA, CI status, and whether another phase remains (`/autonomous-team:run-next-phase`).
