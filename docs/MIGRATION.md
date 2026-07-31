# Migration to MacJanitor v3

## Use this project only

**Canonical local path:** `/Users/darienentwistle/MacJanitor-v3`  
**Remote:** https://github.com/djdarien/MacJanitor  
**Branch for this work:** `v3-real-cleanup`

## What changed in v3

| Area | v2 / early GUI | v3 |
|---|---|---|
| Empty Trash | Shell globs; wrong `.Trashed` path | `FileManager` + correct `.Trashes` |
| Admin commands | Over-escaped `$` broke scripts | Temp `.sh` + password dialog |
| Empty globs | zsh NOMATCH → fake failures | `NULL_GLOB` / FileManager |
| Results | Exit code only | Bytes freed + item counts |
| Tests | Empty / unrunnable | `swift test` (MacJanitorCore) |
| Layout | Many duplicate folders | **One** tree: `MacJanitor-v3` |

## Old folders (legacy — do not develop here)

| Path | Notes |
|---|---|
| `~/MacJanitor-v2/` | Old SPM + scripts |
| `~/MacJanitor-v2.1/` | Untitled + XcodeMacJanitor copies |
| `~/Documents/GitHub/MacJanitor` | Incomplete clone |
| `~/Documents/GitHub/MacJanitor-full` | Intermediate fix branch workspace |

Those trees are left on disk so nothing is lost. Point all new work at **MacJanitor-v3**.

## Build & run

```bash
cd ~/MacJanitor-v3
swift test
./Scripts/build_app.sh
open dist/MacJanitor.app
```

Or open `Package.swift` in Xcode and run the `MacJanitor` scheme.

## Legacy shell scripts

Moved under `legacy/` with deprecation headers. Prefer the SwiftUI app.
