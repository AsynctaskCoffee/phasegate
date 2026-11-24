# ARCHITECTURE.md — System Architecture & Contracts

- **Project:** {{PROJECT_NAME}}
- **Layout Style:** {{ARCH_TYPE}}

## 1. Surfaces & Tech Stack
| Surface | Language / Runtime | Framework | Package Manager | Linter / Formatter | Test Runner | Rationale |
|---------|--------------------|-----------|-----------------|--------------------|-------------|-----------|
| {{SURFACE_1}} | {{LANG_1}} | {{FW_1}} | {{PM_1}} | {{LINT_1}} | {{TEST_1}} | {{REASON_1}} |

## 2. Directory Layout
```text
{{DIRECTORY_TREE}}
```

## 3. Data Model & Storage
{{DATA_MODEL_DESCRIPTION}}

## 4. Shared Contracts (API / CLI / Events / Schemas)
> On multi-surface projects, contracts are locked in **Phase 1**. Record any later contract revision in `DONE_LOG.md`.

{{CONTRACTS_SPEC}}

## 5. Verification Commands
```bash
# Lint & format
{{LINT_CMD}}

# Build / type-check
{{BUILD_CMD}}

# Tests
{{TEST_CMD}}
```
