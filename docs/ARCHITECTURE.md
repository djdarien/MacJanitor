# MacJanitor v3 Architecture

```text
SwiftUI (Dashboard / Maintenance / Settings / Logs)
        │
        ▼
MaintenanceManager  ── dry run, progress, per-task status
        │
        ▼
CleanupEngine (MacJanitorCore)
   ├── FileManager: trash, user caches, Safari caches
   └── CommandRunner
          ├── ProcessCommandRunner  (user shell)
          └── AppCommandRunner → AdminExecutor (password dialog)
```

## Modules

- **MacJanitorCore** — pure cleanup logic + results (unit-tested)
- **MacJanitor** — app UI, admin elevation, system profiler, logging

## Safety

- Caches/logs: files older than **7 days** only (unless dry run)
- Never targets Documents, System, or arbitrary home folders
- Confirmation before real runs; dry-run available
