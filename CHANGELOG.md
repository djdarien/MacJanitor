# MacJanitor Changelog

## Version 3.1.0 — Cleanup beyond the Trash

### What actually gets deleted now
- User caches in `~/Library/Caches` are cleared even when they were used recently (**Deep cache clean**, on by default). Turn it off to keep the 7-day retention policy.
- Sandboxed app caches under `~/Library/Containers` and `~/Library/Group Containers` are included. The rest of each container is left alone.
- Browser cleanup covers Safari, Chrome, Edge, Brave, Arc, and Firefox cache folders. History, cookies, bookmarks, and saved passwords stay.
- New **Developer Junk** task removes Xcode DerivedData, device-support files, CoreSimulator caches, and package-manager caches. Archives, source, and simulator devices stay.
- **Temporary Files** replaces the old animation-defaults “System Optimization” task, which rewrote Dock and Finder preferences and killed those apps. Temp files older than 1 day and the Quick Look cache are removed instead.
- Log cleanup removes user logs and crash reports older than 7 days without an administrator password. System logs still elevate only when the user cannot delete them.
- System cache cleanup measures files first and asks for an administrator password only when deletion is denied.

### Left untouched
Documents, Desktop, Downloads, Mail, Messages, Photos, iCloud Drive, keychains, iOS backups, and protected caches (iCloud, Photos, Music, TV, HomeKit, passwords, Messages).

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
