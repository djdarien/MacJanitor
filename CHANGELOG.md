# MacJanitor Changelog

## Version 4.0.0 — Enhanced Practical Cleanup

### Added
- Xcode DerivedData cleanup
- User Library/Logs cleanup (age-gated)
- Old Downloads cleanup (30-day retention)
- Homebrew cleanup task
- Classic periodic daily/weekly/monthly maintenance scripts
- Finder empty-trash fallback for more reliable Trash emptying
- More resilient admin command handling (fallbacks when tools unavailable)
- Browser caches (Chrome, Firefox, Edge, Brave)
- iOS Simulator caches
- Package caches (npm, yarn, pip)

### Improved
- Trash emptying now combines FileManager + Finder
- System tasks less likely to hard-fail on modern macOS

### Notes
User-level tasks (caches, logs, DerivedData, Downloads, browsers, packages, simulator) do the real work without admin prompts. System tasks still require password.

---

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
