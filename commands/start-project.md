---
description: Analyze a project brief, create a private GitHub repository, produce SPEC/ARCHITECTURE/PLAN docs, open all GitHub Issues, install universal CI, and push Phase 0.
argument-hint: "<project-name> <project-description>"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# `/autonomous-team:start-project`

Arguments provided by user: `$ARGUMENTS`

Bootstraps a new repository (Phase 0) from a short project name and description.

## 1. Parse Arguments and Pre-Flight Checks
1. Split `$ARGUMENTS` into:
   - `PROJECT_NAME`: first token, must be lowercase kebab-case (`^[a-z0-9][a-z0-9-]*$`).
   - `PROJECT_IDEA`: the rest of the text.
   If either is missing or `PROJECT_NAME` is invalid, ask the user to fix it and stop.
2. Run pre-flight checks via `Bash`:
   - `gh auth status` (if unauthenticated, tell the user to run `gh auth login` and stop)
   - `git --version`
3. Confirm `./$PROJECT_NAME` does not already exist in the current working directory. Never overwrite an existing directory.
4. Locate the plugin directory containing `scripts/bootstrap-github.sh` and `templates/`:
   - Prefer `${CLAUDE_PLUGIN_ROOT}` if populated in the environment.
   - Otherwise inspect `~/.claude/plugins/cache` or check the current plugin checkout path before running scripts. Save the resolved path as `PLUGIN_DIR`.

## 2. Architecture and Dynamic Phase Sizing (`autonomous-team:architect`)
Delegate to the `autonomous-team:architect` subagent with `PROJECT_NAME` and `PROJECT_IDEA` to produce the full blueprint:
- Identify required surfaces (`backend`, `frontend`, `mobile`, `cli`, `worker`, `shared`, `infra`, `docs`).
- Select the best-fit language, framework, package manager, linter/formatter, and test runner per surface, with a concise rationale for each.
- Size the number of execution phases dynamically based on actual scope (typically 2–3 phases for a focused CLI/library, 3–5 for a single-surface web/API service, 5–8 for a multi-surface fullstack/mobile system).
- On multi-surface projects, **Phase 1** must cover project scaffolding and locking shared contracts/schemas.
- Decompose each phase into atomic, independently testable tasks.

## 3. Create Local Directory and Private GitHub Repository
1. Create the directory and enter it:
   ```bash
   mkdir -p "$PROJECT_NAME" && cd "$PROJECT_NAME"
   ```
2. Run the bootstrap script from `PLUGIN_DIR`:
   ```bash
   bash "${PLUGIN_DIR}/scripts/bootstrap-github.sh" "$PROJECT_NAME" "<ONE_LINE_SUMMARY>" "<TOTAL_PHASES>"
   ```

## 4. Write Core Project Files and CI
Using the templates in `${PLUGIN_DIR}/templates/` as structural references, write complete, project-specific files inside `./$PROJECT_NAME`:
1. `CLAUDE.md` — Copy `${PLUGIN_DIR}/CLAUDE.md` and append a `## 10. Project Verification Commands` section with the exact lint, build, and test commands for this repo.
2. `SPEC.md` — Complete product specification (no template placeholders left behind).
3. `ARCHITECTURE.md` — Stack table, directory tree, data model, contracts, and verification commands.
4. `PLAN.md` — Dynamic phase list with every task listed under its phase.
5. `DONE_LOG.md` — Initialized with the Phase 0 entry.
6. `STATUS.md` — Initialized with Phase 0 completed and Phase 1 queued.
7. `.gitignore` — Tailored to the chosen languages and frameworks.
8. `.github/workflows/ci.yml` — Copied from `${PLUGIN_DIR}/templates/ci-universal.yml` (adjust runner OS if an iOS/macOS-only Swift target is selected).

## 5. Open GitHub Issues for All Planned Tasks
For every task in `PLAN.md` from Phase 1 through Phase N (do not skip any task), run `gh issue create`:
- Title: `[Phase <X>] <Task Title>`
- Labels: `status:todo`, `phase:<X>`, and the matching `surface:<name>` label.
- Body:
  - Objective and technical notes
  - Dependencies (earlier issue numbers, if any)
  - Acceptance criteria (Markdown checkboxes)
  - Required tests
- Capture each returned issue number (`#1`, `#2`, ...) and write it back into `PLAN.md`.

## 6. Commit and Push Phase 0
1. Update `STATUS.md` and `DONE_LOG.md` with the remote repository URL and total issue count.
2. Commit and push to `origin main`:
   ```bash
   git add -A
   git commit -m "chore(phase-0): initialize repo, specs, dynamic plan, issues, and CI"
   git push -u origin main
   ```

## 7. Print Bootstrap Summary
Show the user:
- Private repository URL
- Surfaces and selected tech stack
- Total dynamic phases and GitHub Issues opened
- Next step: `cd <project-name>` and run `/autonomous-team:run-next-phase`
