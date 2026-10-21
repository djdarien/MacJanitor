# MacJanitor v3 Architecture

```text
SwiftUI (Dashboard / Maintenance / Settings / Logs)
        │
        ▼
MaintenanceManager  ── dry run, progress, per-task status
        │
        ▼
CleanupEngine (MacJanitorCore)
   ├── FileManager
   │     ├── Trash (~/.Trash, /Volumes/*/.Trashes)
   │     ├── User caches, container caches, browser caches
   │     ├── Logs, temp files, Quick Look, developer junk
   │     └── CleanupSafety skips iCloud, Photos, Music, Messages, accounts
   └── CommandRunner
          ├── ProcessCommandRunner  (user shell)
          └── AppCommandRunner → AdminExecutor (password dialog)
                used for system caches, font databases, DNS, and
                system logs only when the user cannot delete them
```

## Modules

- **MacJanitorCore** — pure cleanup logic + results (unit-tested)
- **MacJanitor** — app UI, admin elevation, system profiler, logging

## Safety

- Deep cache clean (default) clears regenerable user and app caches regardless of age. Logs and system caches still use a **7 day** cutoff. Temporary files use **1 day**.
- Protected cache names (iCloud, Photos, Music, TV, HomeKit, passwords, Messages, accounts) are skipped
- Browser and Application Support cleanup only enters known cache subfolders
- Symbolic links are not followed, so a cache link cannot delete Documents or another folder
- Never targets Documents, Desktop, Downloads, Mail, Photos libraries, or iOS backups
- Confirmation before real runs; dry-run available and reports bytes that would be freed
