# Mac Janitor v5.0
---
### 🎨 **1. Hero Section**
- **Title:** Mac Janitor v5.0
- **Tagline:** The ultimate macOS maintenance solution for modern Mac users
- **Badges:** 
  - macOS 12.0+ | SwiftUI | Open Source
  - Build Status: ✓ Working
---
🌟 2. Key Features (Organized by Category)
🧹 Cleaning & Maintenance
- ✓ Cache Cleanup (User & System with 7-day retention)
- ✓ Log Cleanup (7-day retention - safe for diagnostics)
- ✓ Trash Emptying (All volumes + hidden files)
- ✓ Safari & Browser Cache Cleanup
⚡ System Optimization
- ✓ DNS Cache Flush
- ✓ Font Cache Cleanup
- ✓ Memory Purge
- ✓ Disk Maintenance & Verification
- ✓ Time Machine Snapshot Creation
🔒 Security & Safety
- ✓ 7-day retention policy (preserves recent data)
- ✓ Command escaping prevents injection attacks
- ✓ AppleScript GUI password prompts
- ✓ System Integrity Protection aware
🛠️ Developer Tools
- ✓ Hidden Dev Mode (Cmd+Shift+2)
- ✓ Live Log Viewer
- ✓ Operation Logging with timestamps
- ✓ Log storage: ~/Library/Logs/MacJanitor/
---
📷 3. Screenshots
Screenshot 1: Dashboard View
- Shows system info: macOS version, disk space, battery status
- Navigation tabs: Dashboard | Maintenance | Settings
Screenshot 2: Maintenance View  
- Task list with toggles
- Progress bar
- Time Machine status indicator (green when enabled)
- "Start Maintenance" and "Cancel" buttons
---
🚀 4. Quick Start
# Installation
1. Download the latest release (.zip)
2. Extract and move MacJanitor.app to /Applications
3. Launch and grant admin permissions when prompted
# Build from Source (Optional)
git clone https://github.com/djdarien/MacJanitor.git
cd MacJanitor
swift build -c release
cp .build/.../MacJanitor MacJanitor.app/Contents/MacOS/
---
### 📋 **5. Requirements**
- macOS 12.0 (Monterey) or later
- Administrator privileges
- ~100MB free disk space
---
🔧 6. Technical Details
- Built with: SwiftUI (modern native macOS framework)
- Architecture: MVVM with @Observable
- Compatibility: macOS 12+ (Monterey through Sequoia)
- Platforms: Apple Silicon & Intel Macs
- Package Manager: Swift Package Manager
---
📂 7. File Structure
MacJanitor/
├── Sources/
│   └── MacJanitor/
│       ├── App/           # App entry point
│       ├── Views/         # SwiftUI views
│       ├── Models/        # Data models
│       └── Services/      # Maintenance tasks
├── Resources/              # App icons, assets
├── Package.swift          # Build configuration
└── README.md              # This file
---
⚠️ 8. Safety & Disclaimer
> Important: Mac Janitor performs system-level maintenance tasks. While designed with safety in mind, always ensure you have a current Time Machine backup before running maintenance operations.
Safety Features:
- 7-day retention prevents accidental deletion of recent files
- Operation logging tracks all changes
- Time Machine snapshots created before major operations
- Graceful error handling with user-friendly messages
---
🐛 9. Troubleshooting
Issue: Admin prompt doesn't appear
- Solution: Check System Preferences → Security & Privacy → Accessibility
Issue: Some tasks fail
- Solution: Check logs at ~/Library/Logs/MacJanitor/
Issue: Trash not emptying
- Solution: Ensure no apps are holding files in Trash
---
📄 10. License
Open Source - MIT License  
See LICENSE file for details
---
👤 11. Author
Created by: Darien Entwistle  
Website: https://djdarien.github.io/MacJanitor/  
GitHub: https://github.com/djdarien/MacJanitor
---
🙏 12. Acknowledgments
- Built with SwiftUI for modern macOS
- Inspired by traditional Unix maintenance tools
- Thanks to the macOS developer community
