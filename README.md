# Mac Janitor v3.1

Native macOS maintenance app that empties Trash and clears regenerable junk, with a SwiftUI UI and measurable results (bytes freed).

**Local project:** `~/MacJanitor-v3`  
**GitHub:** [github.com/djdarien/MacJanitor](https://github.com/djdarien/MacJanitor)

## Why v3.1

v3 could empty Trash, but the other tasks freed almost nothing: user-cache and “cache cleanup” were the same `~/Library/Caches` folder, only files older than 7 days were removed, and sandboxed app caches (where Chrome, Slack, and most Mac App Store apps actually store data) were never visited. v3.1 cleans those locations and reports how much space each task frees.

## Features

- Empty Trash (user + external volumes via `.Trashes`)
- User caches in `~/Library/Caches`, including recent files when **Deep cache clean** is on
- Sandboxed app caches (`~/Library/Containers/*/Data/Library/Caches` and group containers)
- Known app cache folders (Slack, VS Code, Teams, and similar) without deleting their other data
- Browser caches for Safari, Chrome, Edge, Brave, Arc, and Firefox (history, bookmarks, and passwords stay)
- User logs and crash reports older than 7 days
- Temporary files older than 1 day, plus the Quick Look thumbnail cache
- Developer junk: Xcode DerivedData, device-support symbols, simulator caches, Homebrew/npm/pip/CocoaPods/Gradle/Cargo caches
- System caches and font caches (off until you enable them; they ask for an administrator password)
- Optional DNS flush, memory purge, disk verify, and Time Machine snapshot (off by default; they do not free disk space)
- Dry run (scan and report bytes without deleting)
- Per-task success/failure + bytes freed
- Logs: `~/Library/Logs/MacJanitor/` — open with **⌘⇧2**

These are never deleted: Documents, Desktop, Downloads, Mail, Messages, Photos, iCloud Drive, keychains, iOS backups, browser profiles, Xcode archives, and simulator devices. iCloud, Photos, Music, TV, and account caches are skipped.

## Requirements

- macOS 12+ (Monterey or later)
- Admin password for system-level tasks (lock icon in the list)

## Build

```bash
cd ~/MacJanitor-v3

# Unit tests (no sudo; uses temp fixtures)
swift test

# Release .app (ad-hoc signed)
./Scripts/build_app.sh
open dist/MacJanitor.app
```

Open `Package.swift` in Xcode if you prefer the IDE.

## Usage

1. Launch Mac Janitor  
2. **Dashboard** — system info + disk space  
3. **Maintenance** — space-freeing tasks are on by default; DNS, memory, disk verify, and snapshots stay off until you enable them  
4. Optional: **Dry run** to preview, or turn off **Deep cache clean** to keep caches from the last 7 days  
5. **Start Maintenance** — confirm; enter admin password when a system task asks  

## Project layout

```text
Sources/MacJanitorCore/   # CleanupEngine (tested)
Sources/MacJanitor/       # SwiftUI app
Tests/MacJanitorTests/
Scripts/build_app.sh
docs/MIGRATION.md
legacy/                   # old bash scripts (deprecated)
```

## Legacy folders

Do not develop in `~/MacJanitor-v2` or `~/MacJanitor-v2.1`. See [docs/MIGRATION.md](docs/MIGRATION.md).

## License

See [LICENSE](LICENSE).
