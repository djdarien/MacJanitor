# MacJanitor Changelog

## Version 2.0.0 (Current)

### Changes
- Fixed dashboard not displaying system information (macOS version, disk space, etc.)
- Created missing ShellExecutor service to handle command execution
- Removed sudo from maintenance commands to prevent password prompts and hanging
- Added automatic system info refresh on dashboard load
- Improved error handling for maintenance tasks

### Technical Details
- Added .onAppear to DashboardView for system info refresh
- Implemented ShellExecutor.swift with async command execution
- Modified MaintenanceManager commands to be user-safe (no admin privileges required)
- Maintained task selection and progress tracking functionality
- Updated package name to MacJanitorV2 to avoid build conflicts
- Build successful, app launches without hanging