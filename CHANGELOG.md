# MacJanitor Changelog

## Version 3.0.0 — Consolidated Real Cleanup

### Product
- Single canonical project: **MacJanitor-v3**
- Merged GUI app + real cleanup engine + tests
- Version branding **3.0.0**

### Critical fixes (from real-cleanup work)
- **Empty Trash** via `FileManager` (user `~/.Trash` + volume **`.Trashes`**)
- Fixed wrong path `.Trashed` → `.Trashes`
- **AdminExecutor** runs a temp script (no broken `$` escaping)
- Shell **nullglob** so empty globs do not fail tasks
- **OperationLogger** creates log files before writing
- UI shows **bytes freed** and per-task messages
- **Dry run** mode (scan only)

### Architecture
- `MacJanitorCore` library + `MacJanitor` executable
- `swift test` — unit tests for trash, age filter, admin routing

### Docs
- `docs/MIGRATION.md` — old folder map
- `docs/ARCHITECTURE.md` — engine overview
- Legacy bash scripts under `legacy/`

---

## Earlier history

See git history and prior BUILD_SUMMARY for v2 / v5 GUI milestones.
