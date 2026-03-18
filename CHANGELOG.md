# MacJanitor Changelog

## Version 2.1.0 (Current)

### Changes
- Added secure admin elevation for maintenance tasks that require privileges
- Implemented AdminExecutor using macOS Authorization Services
- Added visual indicators for admin-required tasks
- Tasks now execute properly with appropriate permissions
- Maintained dashboard functionality (no changes)

### Technical Details
- Created AdminExecutor.swift using NSAppleScript for privileged command execution
- Added requiresAdmin property to MaintenanceTaskType
- Updated MaintenanceManager to route tasks based on privilege requirements
- Added lock icons for admin tasks in UI
- Preserved user-level task execution via ShellExecutor
- Build successful, app launches and maintenance tasks execute with proper permissions

## Version 2.0.0

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