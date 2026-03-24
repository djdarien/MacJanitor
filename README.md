# Mac Janitor v5.0

![Mac Janitor Screenshot](https://raw.githubusercontent.com/djdarien/MacJanitor/main/Screenshot%202026-03-17%20at%209.04.14%20PM.png)

A modern, safe, and robust macOS maintenance application with a beautiful SwiftUI GUI that actually works on modern macOS versions.

## ✨ Features

### 🧹 Smart Cleaning & Maintenance
- **Cache Cleanup** - Safely removes user & system caches older than 7 days
- **Log Cleanup** - Removes old system logs (>7 days) while preserving current diagnostics
- **Trash Emptying** - Empties trash on all volumes (including external drives) with hidden file support
- **Browser Cache** - Cleans Safari caches and other browser data
- **Font Cache** - Clears problematic font caches
- **DNS Flush** - Refreshes DNS resolution for better network performance

### ⚡ System Optimization & Health
- **Time Machine Snapshots** - Automatically creates local snapshots before maintenance (if enabled)
- **Memory Purge** - Clears inactive memory for better performance
- **Disk Maintenance** - Verifies and repairs disk permissions and structure
- **System Optimization** - Tweaks system settings for improved responsiveness

### 🔒 Security & Safety First
- **7-Day Retention Policy** - Never deletes recent files (configurable via find -mtime)
- **Command Injection Protection** - Properly escaped shell commands prevent security vulnerabilities
- **AppleScript GUI Prompts** - Native macOS password dialogs for admin privileges
- **System Integrity Protection Aware** - Works with modern macOS security features

### 🛠️ Developer & Power User Tools
- **Hidden Dev Mode** - Press `Cmd+Shift+2` to access log viewer
- **Live Log Viewer** - Real-time monitoring of all maintenance operations
- **Operation Logging** - Detailed logs with timestamps, success/failure status, and duration
- **Log Storage** - `~/Library/Logs/MacJanitor/maintenance_*.log`

### 🖼️ Beautiful Native Interface
- **SwiftUI Framework** - Modern, responsive, and accessible UI
- **Progress Tracking** - Real-time progress bars and status updates
- **Task Management** - Select/deselect specific maintenance operations
- **Multiple Views** - Dashboard, Maintenance, and Settings tabs
- **Time Machine Status** - Visual indicator when Time Machine backups are available

## 📸 Screenshots

| Dashboard View | Maintenance View |
|----------------|------------------|
| ![Dashboard](https://raw.githubusercontent.com/djdarien/MacJanitor/main/Screenshot%202026-03-17%20at%209.04.14%20PM.png) | ![Maintenance](https://raw.githubusercontent.com/djdarien/MacJanitor/main/Screenshot%202026-03-17%20at%209.04.19%20PM.png) |

## 📋 Requirements

- **macOS 12.0 (Monterey) or later** - Tested on Ventura and Sequoia
- **Administrator privileges** - Required for system-level maintenance tasks
- **~100MB free disk space** - For temporary files during operations
- **Apple Silicon or Intel** - Universal binary supports both architectures

## 🚀 Installation

### Option 1: Download Ready-to-Run App
1. [Download the latest release](https://github.com/djdarien/MacJanitor/releases/latest) (MacJanitor.zip)
2. Extract the ZIP file
3. Drag `MacJanitor.app` to your `/Applications` folder
4. Launch the app and grant administrator permissions when prompted

### Option 2: Build from Source (Developers)
```bash
# Clone the repository
git clone https://github.com/djdarien/MacJanitor.git
cd MacJanitor

# Build the application
swift build -c release

# Copy to Applications folder (optional)
cp .build/arm64-apple-macosx/release/MacJanitor /Applications/MacJanitor.app
```

## 🔧 Usage

1. **Launch Mac Janitor** from your Applications folder
2. **Review System Status** on the Dashboard tab (macOS version, disk space, battery)
3. **Select Tasks** in the Maintenance tab - toggle on/off specific operations
4. **Start Maintenance** - Click the "Start Maintenance" button
5. **Monitor Progress** - Watch real-time progress bars and status updates
6. **Review Results** - Check completion status and any recommendations
7. **Access Logs** - Press `Cmd+Shift+2` or go to Settings → Enable Developer Mode

## 🛡️ Safety Features

Mac Janitor prioritizes your system's safety with multiple protection layers:

- **Conservative Cleaning** - Only removes files older than 7 days by default
- **Volume-Aware Trash** - Empties trash on all mounted volumes safely
- **Operation Logging** - Every action is logged for audit and troubleshooting
- **Time Machine Integration** - Creates local snapshots before major operations
- **Error Recovery** - Graceful handling with user-friendly messages
- **No Forced Reboots** - Only suggests reboot when actually needed (font/cache changes)

## 📂 File Structure

```
MacJanitor/
├── MacJanitor.app/                 # The application bundle
├── Sources/
│   └── MacJanitor/                 # Source code
│       ├── App/                    # App entry point
│       ├── Views/                  # SwiftUI interface (Dashboard, Maintenance, Settings)
│       ├── Models/                 # Data models (MaintenanceTask, etc.)
│       └── Services/               # Core functionality (MaintenanceManager, etc.)
├── Resources/                      # App icons, assets
├── Package.swift                   # Swift package configuration
├── README.md                       # This file
├── LICENSE                         # MIT license
└── CHANGELOG.md                    # Version history
```

## ⚙️ Technical Details

- **Built With:** SwiftUI 4.0, Swift 5.9+
- **Architecture:** MVVM with `@Observable` state management
- **Compatibility:** macOS 12.0+ (Monterey through Sequoia)
- **Platforms:** Universal binary (Apple Silicon & Intel)
- **Package Manager:** Swift Package Manager
- **Minimum Deployment Target:** macOS 12.0

## 📄 Logs & Troubleshooting

### Log Location
All maintenance operations are logged to:
```
~/Library/Logs/MacJanitor/maintenance_YYYY-MM-DD.log
```

### Common Issues & Solutions

**Issue:** Admin password prompt doesn't appear
- **Solution:** Ensure Mac Janitor has accessibility permissions in System Settings → Privacy & Security → Accessibility

**Issue:** Some maintenance tasks fail
- **Solution:** Check the log viewer (`Cmd+Shift+2`) for detailed error messages

**Issue:** Trash not emptying properly
- **Solution:** Ensure no applications are actively using files in the Trash

**Issue:** App won't launch
- **Solution:** Try redownloading - may have been blocked by Gatekeeper (right-click → Open)

## 🐞 Reporting Issues

Please visit the [GitHub Issues page](https://github.com/djdarien/MacJanitor/issues) to:
- Report bugs
- Suggest new features
- Ask questions
- View known issues

## 📄 License

Mac Janitor is released under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**Copyright © 2026 Darien Entwistle**

## 🙏 Acknowledgments

- Built with SwiftUI for modern, native macOS experience
- Inspired by traditional Unix maintenance tools (`periodic`, `purge`, etc.)
- Thanks to the open-source macOS development community
- Special thanks to all users who provide feedback and suggestions

---

*Mac Janitor v5.0 - Built with pride for the macOS community*  
*Last updated: March 2026 | Supports macOS Monterey through Sequoia*
