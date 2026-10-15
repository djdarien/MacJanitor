# Mac Janitor v4

Native macOS maintenance app that cleans caches, empties Trash, removes developer junk, and runs classic periodic scripts.

**GitHub:** [github.com/djdarien/MacJanitor](https://github.com/djdarien/MacJanitor)

## Why v4

v3 emptied Trash reliably but other tasks often did little (age filters, restricted system commands). v4 adds practical user-level cleanups that free real space and makes system tasks more resilient.

## Features

- Empty Trash (user + volumes + Finder fallback)
- User / Safari / system cache cleanup (7-day retention)
- **Xcode DerivedData** cleanup
- **User logs** and **old Downloads** (30-day)
- **Homebrew cleanup** (if installed)
- Classic **periodic daily/weekly/monthly** scripts
- DNS flush, font cache, memory purge, disk verify, Time Machine snapshot
- Dry run, per-task success/failure + bytes freed
- Logs: `~/Library/Logs/MacJanitor/`

## Requirements

- macOS 12+
- Admin password for system tasks

## Build

```bash
swift test
./Scripts/build_app.sh
open dist/MacJanitor.app
```

## Usage

1. Launch Mac Janitor
2. Enable desired tasks (try Xcode DerivedData and User Logs first)
3. Optional dry run
4. Start Maintenance (admin prompt for privileged tasks)

## Project layout

```text
Sources/MacJanitorCore/   # CleanupEngine
Sources/MacJanitor/       # SwiftUI app
Tests/MacJanitorTests/
Scripts/build_app.sh
```

See [CHANGELOG.md](CHANGELOG.md) for details.
