# Graphify Policy & Offline Status

Canonical policy for code investigation and architecture mapping in PlotMetric.

## 1. Upstream Verification & Identity
- Official Upstream Repository: [graphify](https://github.com/graphify-ai/graphify) (or verified official Python package via `uv tool`).
- Do not assume similarly named tools or unofficial forks.
- Offline check status: No local `graphify-out/` directory currently exists in the workspace.

## 2. Shared Installation Commands (Manual by User)
When the user wishes to enable Graphify, run the following in Windows PowerShell:
```powershell
# Working Directory: E:\github\PlotMetric
uv tool install graphify
graphify install
```
*Note: `/graphify` is an agent slash command where supported, not a PowerShell command.*

## 3. Investigation & Fallback Protocol
- Before using Git commands or significant refactoring, check for Graphify availability and `graphify-out/`.
- If Graphify is not yet installed or generated, explicitly state the limitation and fall back to repository-local search (`grep`, `find`, or direct file inspection).
- Output graphs and logs must remain in `graphify-out/` and must be Git-ignored. Never commit raw graph output files.
