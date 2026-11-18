# Security & Protection Policy

Local protective controls and verification rules for PlotMetric.

## 1. Local Pre-commit & Hook Standards
- Pre-commit and pre-push hooks must run entirely offline without internet dependencies.
- Reject paths traversing outside the repository (e.g. `..\` or absolute references to other directories).
- Verify staged files do not contain accidental secrets, API tokens, private signing keys, or un-ignored SQLite `.db` binaries.
- Ensure all hooks fail closed.

## 2. Manual Git Hooks Installation (When Git is initialized)
To install local Graphify hooks once Graphify is manually set up:
```powershell
# Working Directory: E:\github\PlotMetric
graphify hook install
```
Project-local protective scripts are housed in `.agent-policy/hooks/`.
