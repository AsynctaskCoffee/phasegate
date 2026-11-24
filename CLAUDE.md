# CLAUDE.md — Operating Rules

These rules govern every repository created or managed by the `autonomous-team` plugin. Follow them literally.

## 1. Read State Before Acting
At the start of any session, phase, or task, read these files in order before editing anything:
1. `SPEC.md` — Scope, functional requirements, assumptions, and explicit non-goals.
2. `ARCHITECTURE.md` — Tech stack per surface, directory layout, data model, and shared contracts.
3. `PLAN.md` — Phase breakdown, issue links, and task order.
4. `DONE_LOG.md` — Engineering log from completed issues (decisions, file paths, known quirks).
5. `STATUS.md` — Current phase, active issue, and last verification outcome.

## 2. Work In Progress Limit (WIP = 1)
- Only one GitHub Issue may carry `status:in-progress` or `status:test` at a time.
- Do not pick up the next issue until the current one is either closed as `status:done` or halted as `status:blocked`.

## 3. Contract-First on Multi-Surface Repositories
When a repository contains more than one surface (for example, `backend` + `frontend`, `backend` + `mobile`, or a monorepo with `shared`):
- **Phase 1** must establish the repository scaffold and lock shared contracts first (OpenAPI, GraphQL schema, Protobuf, JSON Schema, shared DTOs, or DB migrations).
- Every surface builds against that locked contract. If a contract change becomes necessary later, update `ARCHITECTURE.md` first and log the reason in `DONE_LOG.md`.

## 4. Issue State Machine
Every task moves strictly through:

`status:todo` -> `status:in-progress` -> `status:test` -> `status:done`

- Never skip a state.
- On every transition, inspect existing `status:*` labels on the issue before removing them, then apply the next label via `gh issue edit`.
- Update `STATUS.md` on every transition and print a single-line status update:
  `[PHASE <X>/<N> | ISSUE #<NUM> | ROLE: <agent> | STATE: <label> | TESTS: <summary>]`

## 5. Quality Gate (No Bypasses)
An issue cannot move from `status:test` to `status:done` until:
1. Automated tests (unit, integration, or end-to-end) covering the issue's acceptance criteria are written and executed.
2. Every configured lint, format check, type-check, build, and test command exits with code `0`.
3. No test skips or linter suppressions were introduced (`.skip(`, `xit(`, `#[ignore]`, `@pytest.mark.skip`, `// nolint`, `# noqa`, `@ts-ignore`, `eslint-disable`).
4. If any check fails, move the issue back to `status:in-progress`, fix the root cause, and re-run the full verification pass.

## 6. Persistent Memory (`DONE_LOG.md` + Issue Comments)
Before closing an issue:
1. Append a structured entry to `DONE_LOG.md` listing the issue number, summary, modified files, key decisions, exact verification commands/results, and notes for downstream tasks.
2. Post the same summary as a comment on the GitHub Issue with `gh issue comment`.
3. Switch the label to `status:done` and close the issue with `gh issue close`.

## 7. Phase Commits and Pushes
- Do not push half-finished phases. Once every issue in a phase is closed, run a full regression pass (lint, build, and tests) across **all** surfaces in the repository.
- Check `git status` and `git diff --cached` to ensure no temporary files, build artifacts, or secrets are staged.
- Commit with Conventional Commits and push to `origin main`:
  - Phase 0: `chore(phase-0): initialize repo, specs, dynamic plan, issues, and CI`
  - Later phases: `feat(phase-<N>): <short phase summary>`
- Include `Refs: #<n1>, #<n2>` in the commit body for every issue completed in that phase.

## 8. Blocker Handling
If the same failure remains unresolved after **3 consecutive fix attempts**:
1. Stop immediately. Do not loop.
2. Replace the issue's active status label with `status:blocked`.
3. Post the exact error output, what was tried in all 3 attempts, and the specific input or decision needed from the user in both a GitHub Issue comment and `STATUS.md`.
4. Halt execution and report the blocker clearly.

## 9. Stack Selection
Do not default blindly to one language. The `architect` agent picks the right language, framework, package manager, linter, and test runner per surface based on the actual requirements, and writes the rationale in `ARCHITECTURE.md`.
