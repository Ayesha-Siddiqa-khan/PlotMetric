# Agent Skills Policy

Canonical policy for shared agent skills across the PlotMetric project.

## 1. Skill Acquisition & Discovery
- Agents must not automatically download or run remote skill installations.
- All skill additions are managed manually by the user in Windows PowerShell:
  ```powershell
  # Project root: E:\github\PlotMetric
  node --version
  npx skills add addyosmani/agent-skills --list
  npx skills add addyosmani/agent-skills
  npx skills list
  ```
- Before recommending skills, agents must verify upstream source, version, commands, and compatibility.
- Project-level policies (`AGENTS.md`, `.agent-policy/`) always supersede skill recommendations.

## 2. Core Operational Skills
- **Specification First:** Always align implementation with `PlotMetric_PRD_v1.0.md`.
- **Test-Driven & Incremental:** Implement core mathematical and repository layers with pure functions and unit tests before composing complex UI widgets.
- **Fail Closed:** If any command, path, or operation falls outside the verified sandbox and repository scope, halt and ask for explicit user guidance.
