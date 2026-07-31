# Mac Janitor v3

Native macOS maintenance app that **actually empties Trash and cleans caches**, with a SwiftUI UI and measurable results (bytes freed).

**Local project:** `~/MacJanitor-v3`  
**GitHub:** [github.com/djdarien/MacJanitor](https://github.com/djdarien/MacJanitor)

## Why v3

Older copies (`MacJanitor-v2`, `v2.1`, multiple Untitled trees) had a working-looking GUI but cleanup often failed silently (wrong volume trash path, broken admin escaping, zsh glob errors). **v3 consolidates everything** into one tree with a real `CleanupEngine`.

## Features

- Empty Trash (user + external volumes via `.Trashes`)
- User / Safari / system cache cleanup (7-day retention)
- Log cleanup (7-day retention)
- DNS flush, font cache, memory purge, disk verify, Time Machine snapshot
- Dry run (report only)
- Per-task success/failure + bytes freed
- Logs: `~/Library/Logs/MacJanitor/` — open with **⌘⇧2**

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
3. **Maintenance** — enable tasks (start with Empty Trash to verify)  
4. Optional: **Dry run** to preview  
5. **Start Maintenance** — confirm; enter admin password when asked  

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
