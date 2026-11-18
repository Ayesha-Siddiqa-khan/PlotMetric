# PlotMetric — Shared Agent Guidelines & Policy

This file defines the canonical policy and operational boundaries for all AI agents working on the PlotMetric project.

## 1. Project Boundaries & Offline Default
- **Strict Repository Boundary:** Agents must only read, create, and modify files within `e:\github\PlotMetric`.
- **Offline First:** No network access, external telemetry, background updates, or unapproved API calls.
- **Manual Dependency Installation:** The user personally installs and updates all software, tools, and dependencies via Windows PowerShell. Agents must NEVER execute `flutter pub get`, `flutter pub add`, `npm`, `pip`, `uv`, `winget`, or `git clone/fetch/pull` commands. When new dependencies are required, agents must provide the exact package version, rationale, PowerShell working directory, ready-to-copy commands, and wait for manual user confirmation.

## 2. Canonical Policies
All extended agent guidelines are stored in `.agent-policy/`:
- [skills.md](.agent-policy/skills.md) — Shared agent skills and execution standards.
- [graphify.md](.agent-policy/graphify.md) — Graphify architecture map and integration status.
- [security.md](.agent-policy/security.md) — Local security controls, secret protection, and path validation.

## 3. Project Architecture
- **Language & Framework:** Dart (null-safe) & Flutter Material 3.
- **State Management:** Riverpod (`flutter_riverpod`).
- **Persistence:** Local SQLite database via `sqflite` with foreign key constraints enabled.
- **Feature Structure:**
  - `lib/core/` — Constants, theme tokens, date/time and number formatters.
  - `lib/data/` — SQLite database helper, entity models, and repositories.
  - `lib/features/land/` — Land measurement engine (centi-Sarsai integer math), worksheet notifier, and UI widgets.
  - `lib/features/calculator/` — Arithmetic calculator logic and screen.
  - `lib/features/records/` — SQLite calculation records screen and search.
  - `lib/features/scan/` — Future OCR placeholder screen.
- **Quality Standards:** English-only UI, pure integer arithmetic for land measurements (no floating-point drift), and comprehensive unit/widget tests.
