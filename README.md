# claude-autonomous-team

A Claude Code plugin (`autonomous-team`) that turns a short project brief into a private GitHub repository and executes it phase by phase with GitHub Issues, a read-only QA gate, persistent engineering notes, and multi-language CI.

It is stack-agnostic: instead of hardcoding one language or a fixed phase template, it picks the stack per surface (backend, web, mobile, CLI, worker) based on the brief and scales the phase count to match the actual scope.

## Why This Exists

Running long coding sessions with an agent usually breaks down in four predictable ways:
1. **Context drift** — Decisions made three tasks ago get forgotten after context compaction or across sessions.
2. **Premature completion** — Tasks get marked done without running tests, or tests get silently skipped to make a build green.
3. **Contract mismatches** — Frontend, mobile, and backend surfaces diverge because shared schemas were never locked first.
4. **Messy git history** — Work lands as one massive unverified dump instead of clean, reproducible phase commits.

This plugin enforces a small set of mechanical guardrails to prevent all four:
- Every task lives as a **GitHub Issue** moving strictly through `status:todo` -> `status:in-progress` -> `status:test` -> `status:done`.
- Only **one issue** can be active at a time (`WIP = 1`).
- Multi-surface projects lock shared contracts in **Phase 1** before feature code starts.
- A read-only `qa-engineer` subagent (`Write` and `Edit` disabled) runs lint, build, and tests and audits diffs for skipped tests before any issue closes.
- Every closed issue appends a structured entry to `DONE_LOG.md` and posts the same note to the GitHub Issue, while `STATUS.md` tracks live progress.
- Every finished phase runs a full multi-surface regression, commits with Conventional Commits, and pushes to `origin main`.

## Workflow Overview

```text
/autonomous-team:start-project <name> <brief>
   │
   ├─► Pre-flight checks (gh auth status, git)
   ├─► architect subagent: stack selection + dynamic phase plan
   ├─► bootstrap-github.sh: private repo + status/surface/phase labels
   ├─► Writes CLAUDE.md, SPEC.md, ARCHITECTURE.md, PLAN.md, DONE_LOG.md, STATUS.md
   ├─► Installs .github/workflows/ci.yml (8-stack universal CI)
   ├─► Opens GitHub Issues for every task in Phases 1..N
   └─► Commits & pushes Phase 0

/autonomous-team:run-next-phase [phase-number]
   │
   ├─► Reads CLAUDE.md, SPEC.md, ARCHITECTURE.md, PLAN.md, DONE_LOG.md, STATUS.md
   ├─► For each open issue in target phase (WIP = 1):
   │      status:todo
   │         │
   │         ▼
   │      status:in-progress  ──► builder subagent (code + tests)
   │         │
   │         ▼
   │      status:test         ──► qa-engineer subagent (read-only gate)
   │         │   ▲
   │         │   └── fail (retry up to 3x, then status:blocked & halt)
   │         ▼
   │      status:done         ──► append DONE_LOG.md + comment & close issue
   │
   └─► release-manager subagent: full regression + secret scan + commit + push + CI check
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `git`
- [GitHub CLI (`gh`)](https://cli.github.com/) authenticated with repo write permissions:

```bash
gh auth login
gh auth status
```

## Installation & Setup

### Option 1: Load Directly From a Local Folder

```bash
chmod +x claude-autonomous-team/scripts/bootstrap-github.sh

# Validate the plugin manifest before loading
claude plugin validate --strict ./claude-autonomous-team

# Start Claude Code with the plugin loaded
claude --plugin-dir ./claude-autonomous-team
```

### Option 2: Publish to Your Own GitHub Repository

```bash
cd claude-autonomous-team
chmod +x scripts/bootstrap-github.sh
git init -b main
git add -A
git commit -m "feat: initial autonomous-team plugin"
gh repo create claude-autonomous-team --private --source=. --remote=origin --push
```

> **Note on command namespacing:** The plugin manifest sets `"name": "autonomous-team"` so `claude plugin validate --strict` passes without triggering Anthropic's reserved `claude-` prefix check. Claude Code namespaces all plugin commands under that name, so commands are invoked as `/autonomous-team:start-project` and `/autonomous-team:run-next-phase`.

## End-to-End Walkthrough

### 1. Bootstrap a New Project (Phase 0)

Run Claude Code from the directory where you want your new repository folder created:

```bash
claude --plugin-dir /path/to/claude-autonomous-team
```

Inside Claude Code:

```text
/autonomous-team:start-project invoice-portal Multi-tenant invoicing web app with item-based billing, PDF export, and role-based approval limits. Use .NET 9 for the API and React + TypeScript for the frontend.
```

What gets created on disk and on GitHub:

```text
invoice-portal/
├── .github/
│   └── workflows/
│       └── ci.yml
├── .gitignore
├── ARCHITECTURE.md
├── CLAUDE.md
├── DONE_LOG.md
├── PLAN.md
├── SPEC.md
└── STATUS.md
```

- A new **private** GitHub repo `invoice-portal` is created under your authenticated `gh` account.
- Labels (`status:*`, `surface:*`, `phase:0..N`) are provisioned automatically.
- Every task from Phase 1 to Phase N is opened as a GitHub Issue with acceptance criteria and test requirements, and issue numbers are written back into `PLAN.md`.
- Phase 0 is committed and pushed to `origin main`.

### 2. Execute Phases One by One

Move into the generated repository and start Claude Code with the plugin:

```bash
cd invoice-portal
claude --plugin-dir /path/to/claude-autonomous-team
```

Run the next pending phase:

```text
/autonomous-team:run-next-phase
```

Or run a specific phase explicitly:

```text
/autonomous-team:run-next-phase 2
```

During execution, each transition prints a single-line status banner in the terminal and updates `STATUS.md`:

```text
[PHASE 1/5 | ISSUE #1 | ROLE: builder | STATE: status:in-progress | TESTS: pending]
[PHASE 1/5 | ISSUE #1 | ROLE: qa-engineer | STATE: status:test | TESTS: running]
[PHASE 1/5 | ISSUE #1 | ROLE: qa-engineer | STATE: status:done | TESTS: 18/18 PASS]
```

Once every issue in the phase is closed, `release-manager` runs a full multi-surface regression, checks for leaked secrets or stray files, commits (`feat(phase-1): ...`), pushes to `origin main`, and verifies the GitHub Actions run.

Repeat `/autonomous-team:run-next-phase` until all phases are marked `COMPLETED`.

## Repository Structure

```text
claude-autonomous-team/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest (auto-discovers commands/ and agents/)
├── agents/
│   ├── architect.md             # Stack selection, contracts, dynamic phase planning
│   ├── builder.md               # Production code + unit/integration tests
│   ├── qa-engineer.md           # Read-only quality gate (Write/Edit disallowed)
│   └── release-manager.md       # Multi-surface regression, hygiene, commit/push, CI check
├── commands/
│   ├── start-project.md         # /autonomous-team:start-project
│   └── run-next-phase.md        # /autonomous-team:run-next-phase
├── scripts/
│   └── bootstrap-github.sh      # Private repo creation + label provisioning
├── templates/
│   ├── ARCHITECTURE.template.md
│   ├── DONE_LOG.template.md
│   ├── PLAN.template.md
│   ├── SPEC.template.md
│   ├── STATUS.template.md
│   └── ci-universal.yml         # Auto-detecting 8-ecosystem GitHub Actions workflow
├── CLAUDE.md                    # Core operating rules copied into generated projects
├── LICENSE                      # MIT
└── README.md
```

## Supported Stacks & Universal CI

The bundled `.github/workflows/ci.yml` inspects the repository up to 3 levels deep and runs CI jobs only for stacks actually present. Monorepos combining multiple stacks run each detected job in parallel.

| Ecosystem | Detection Signal | Checks Executed | Monorepo Support |
|-----------|------------------|-----------------|------------------|
| **Node / TypeScript** | `package.json` | `lint`, `typecheck`, `build`, `test` (`pnpm` / `yarn` / `npm`) | Root workspaces & multi-package folders |
| **Python** | `pyproject.toml`, `requirements.txt` | `ruff check .`, `pytest` (isolated temp venv per surface) | Per-directory isolated virtualenvs |
| **Go** | `go.mod` | `gofmt -l`, `go vet ./...`, `go build ./...`, `go test -race ./...` | Per-module loop |
| **Rust** | `Cargo.toml` | `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test --all` | Root workspace & independent crates |
| **Flutter / Dart** | `pubspec.yaml` | `flutter analyze && flutter test` (or `dart` for pure Dart) | Per-package loop |
| **Swift** | `Package.swift` | `swift build && swift test` | Per-package loop (Linux runner*) |
| **.NET / C#** | `*.sln`, `*.slnx`, `*.csproj` | `dotnet restore`, `build`, `test` | Solution-first, project fallback |
| **Gradle / Kotlin / Java** | `build.gradle`, `build.gradle.kts` | `./gradlew check` (or `gradle check` fallback) | Per-project loop |

\* Swift packages targeting Linux/server/CLI run on `ubuntu-latest`. For iOS/macOS-only UIKit or SwiftUI targets, switch `swift-ci`'s `runs-on` in `.github/workflows/ci.yml` to `macos-latest`.

On Phase 0 (documentation and CI only), `detect-stacks` returns `false` for all stacks and the workflow completes green without false failures.

## Guardrails & Failure Handling

- **Read-Only QA Gate:** `agents/qa-engineer.md` sets `disallowedTools: Write, Edit`. It cannot silently weaken tests or tweak code to force a pass.
- **No Bypass Patterns:** Diffs containing `.skip(`, `xit(`, `#[ignore]`, `@pytest.mark.skip`, `// nolint`, `# noqa`, `@ts-ignore`, or `eslint-disable` automatically fail QA.
- **Blocker Circuit Breaker:** If an issue fails QA 3 times in a row for the same root cause, the loop halts, applies `status:blocked`, records the error and all 3 attempts on the GitHub Issue and `STATUS.md`, and hands control back to you.
- **Interrupted Session Recovery:** Because state lives in GitHub Issues, `STATUS.md`, and `DONE_LOG.md`, running `/autonomous-team:run-next-phase` in a fresh session picks up the currently open `status:in-progress` or `status:test` issue automatically instead of duplicating work.

## Customization

- **Adjust subagent models or turn budgets:** Edit the frontmatter (`model`, `maxTurns`) in `agents/*.md`. For heavier architectural work, you can switch `architect.md` from `sonnet` to `opus`.
- **Add another language to CI:** Add a detection output in `detect-stacks` and a matching job in `templates/ci-universal.yml`.
- **Use a different default branch or visibility:** Edit `scripts/bootstrap-github.sh` (`--private` -> `--public`, `-b main` -> your preferred branch name).

## Troubleshooting

- **`gh auth status` fails during `/autonomous-team:start-project`:** Run `gh auth login` in your shell and verify token scopes include `repo`.
- **Slash commands don't appear as `/start-project`:** Claude Code prefixes all plugin commands with the manifest `name`. Use `/autonomous-team:start-project` and `/autonomous-team:run-next-phase`.
- **`claude plugin validate` reports an issue after editing files:** Run `claude plugin validate --strict ./claude-autonomous-team` to pinpoint invalid JSON keys or frontmatter syntax errors before reloading.
- **Need to resume after fixing a `status:blocked` issue manually:** Remove the `status:blocked` label on GitHub, restore `status:todo` (or `status:in-progress`), and run `/autonomous-team:run-next-phase`.

## License

MIT — see `LICENSE`.
