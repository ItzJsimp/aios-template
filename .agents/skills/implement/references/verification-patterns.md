# Verification Patterns Reference

Guidelines for establishing the observable Red Phase across non-compiled, scripting, or governance-heavy environments:

## 1. PowerShell & Automation Scripts
- **Strategy:** Write an explicit test assertion script in `scratch/` or use Pester (`*.Tests.ps1`).
- **Red Phase Action:** Execute the script against the current codebase and confirm it exits with a non-zero code or explicit assertion failure indicating the missing behavior.
- **Green Phase Action:** Implement the cmdlet or logic and verify the script returns exit code 0 with all assertions passing.

## 2. Markdown, Canon & Governance Documents
- **Strategy:** Use targeted lint checks, regex assertions, or repo verification scripts (e.g. [`Detect-Drift.ps1`](../../../../scripts/Detect-Drift.ps1)).
- **Red Phase Action:** Run the validator and observe the exact violation report (such as a missing glossary entry, broken relative link, or malformed frontmatter).
- **Green Phase Action:** Update the canon document and confirm the validator runs with zero warnings or errors.

## 3. Data Schemas, Configuration & Manifests
- **Strategy:** Schema validation checks or PowerShell data file validation.
- **Red Phase Action:** Test against a test parser or validator to observe failure when new schema properties or constraints are missing.
- **Green Phase Action:** Update the schema/manifest (e.g. [`shared-manifest.psd1`](../../../../scripts/sync/shared-manifest.psd1)) and verify parsing succeeds without errors.

## 4. Frontend & Web Interfaces
- **Strategy:** Headless assertions, DOM component tests, or visual check scripts.
- **Red Phase Action:** Run the test runner or component assertion to verify the missing UI element or behavior fails cleanly.
- **Green Phase Action:** Implement the minimal markup/styling/logic to satisfy the check.
