#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./bootstrap-github.sh <repo-name> "<description>" <total-phases>
REPO_NAME="${1:-}"
REPO_DESC="${2:-Project bootstrapped with autonomous-team}"
TOTAL_PHASES="${3:-3}"

if [[ -z "$REPO_NAME" ]]; then
  echo "Error: repository name is required." >&2
  echo "Usage: $0 <repo-name> \"<description>\" <total-phases>" >&2
  exit 1
fi

if ! [[ "$TOTAL_PHASES" =~ ^[0-9]+$ ]]; then
  echo "Error: total-phases must be a non-negative integer (got '${TOTAL_PHASES}')." >&2
  exit 1
fi

echo "[1/4] Checking GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

echo "[2/4] Initializing local git repository..."
if [[ ! -d ".git" ]]; then
  git init -b main
fi

echo "[3/4] Creating private GitHub repository: ${REPO_NAME}"
if ! git remote get-url origin >/dev/null 2>&1; then
  gh repo create "$REPO_NAME" \
    --private \
    --source=. \
    --remote=origin \
    --description "$REPO_DESC"
else
  echo "Remote 'origin' already configured; skipping repository creation."
fi

echo "[4/4] Creating state, surface, and phase labels..."

# State machine labels
gh label create "status:todo"        --color "D4C5F9" --description "Queued and ready to start" --force
gh label create "status:in-progress" --color "FBCA04" --description "Actively being implemented (WIP=1)" --force
gh label create "status:test"        --color "1D76DB" --description "Under automated test and QA verification" --force
gh label create "status:done"        --color "0E8A16" --description "Verified, tested, and closed" --force
gh label create "status:blocked"     --color "B60205" --description "Halted after repeated failures; needs input" --force

# Surface labels (matches all surfaces defined in agents/architect.md)
gh label create "surface:backend"    --color "0052CC" --description "Backend service or API" --force
gh label create "surface:frontend"   --color "5319E7" --description "Web frontend" --force
gh label create "surface:mobile"     --color "C2E0C6" --description "Mobile application" --force
gh label create "surface:cli"        --color "BFD4F2" --description "CLI tool" --force
gh label create "surface:worker"     --color "D93F0B" --description "Background worker or queue consumer" --force
gh label create "surface:shared"     --color "F9D0C4" --description "Shared contracts, schemas, or packages" --force
gh label create "surface:infra"      --color "E99695" --description "CI/CD, containers, and infrastructure" --force
gh label create "surface:docs"       --color "0E8A16" --description "Documentation" --force

# Dynamic phase labels (phase:0 .. phase:N)
for ((i = 0; i <= TOTAL_PHASES; i++)); do
  gh label create "phase:${i}" --color "006B75" --description "Execution Phase ${i}" --force
done

echo "Done. Repository URL: $(git remote get-url origin)"
