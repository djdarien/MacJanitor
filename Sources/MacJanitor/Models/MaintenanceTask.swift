import Foundation
import MacJanitorCore

enum MaintenanceTaskType: String, CaseIterable, Identifiable, Codable, Sendable {
    case trashEmpty = "Empty Trash"
    case userCacheCleanup = "User Caches"
    case cacheCleanup = "App Caches"
    case safariCleanup = "Browser Caches"
    case logCleanup = "Log Cleanup"
    case developerCleanup = "Developer Junk"
    case temporaryFiles = "Temporary Files"
    case fontCacheCleanup = "Font Cache Cleanup"
    case systemCacheCleanup = "System Caches"
    case dnsFlush = "DNS Flush"
    case memoryPurge = "Memory Purge"
    case diskMaintenance = "Disk Maintenance"
    case timeMachineSnapshot = "Time Machine Snapshot"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .trashEmpty:
            return "Empty Trash on this Mac and mounted volumes"
        case .userCacheCleanup:
            return "Clear regenerable caches in ~/Library/Caches. Skips iCloud, Photos, Music, Messages, and account data"
        case .cacheCleanup:
            return "Clear sandboxed app caches and known app cache folders (Slack, VS Code, Teams, and similar)"
        case .safariCleanup:
            return "Clear Safari, Chrome, Edge, Brave, Arc, and Firefox caches. History, bookmarks, and passwords stay"
        case .logCleanup:
            return "Remove user logs and crash reports older than 7 days, plus system logs when permitted"
        case .developerCleanup:
            return "Remove Xcode DerivedData, device-support files, simulator caches, and package-manager caches. Archives and source stay"
        case .temporaryFiles:
            return "Remove temporary files older than 1 day and the Quick Look thumbnail cache"
        case .fontCacheCleanup:
            return "Clear user font caches and rebuild the system font database"
        case .systemCacheCleanup:
            return "Clear system caches in /Library/Caches older than 7 days"
        case .dnsFlush:
            return "Flush the DNS cache. This does not free disk space"
        case .memoryPurge:
            return "Purge inactive memory when the purge tool is available. This does not free disk space"
        case .diskMaintenance:
            return "Verify the startup disk. This does not delete files"
        case .timeMachineSnapshot:
            return "Create a local Time Machine snapshot. This does not free disk space"
        }
    }

    var icon: String {
        switch self {
        case .trashEmpty: return "trash.fill"
        case .userCacheCleanup: return "internaldrive"
        case .cacheCleanup: return "square.stack.3d.up"
        case .safariCleanup: return "safari"
        case .logCleanup: return "doc.text"
        case .developerCleanup: return "hammer"
        case .temporaryFiles: return "hourglass"
        case .fontCacheCleanup: return "textformat"
        case .systemCacheCleanup: return "gearshape.2"
        case .dnsFlush: return "network"
        case .memoryPurge: return "memorychip"
        case .diskMaintenance: return "externaldrive.badge.checkmark"
        case .timeMachineSnapshot: return "clock.arrow.circlepath"
        }
    }

    var requiresReboot: Bool {
        self == .fontCacheCleanup
    }

    var requiresAdmin: Bool {
        coreKind.requiresAdmin
    }

    var freesDiskSpace: Bool {
        coreKind.freesDiskSpace
    }

    /// Space-freeing tasks that can run without an administrator password.
    /// System and font caches stay off until the user opts in, because they prompt for a password.
    var defaultEnabled: Bool {
        switch self {
        case .fontCacheCleanup, .systemCacheCleanup:
            return false
        default:
            return freesDiskSpace
        }
    }

    var estimatedDuration: TimeInterval {
        switch self {
        case .trashEmpty: return 10
        case .userCacheCleanup: return 40
        case .cacheCleanup: return 60
        case .safariCleanup: return 20
        case .logCleanup: return 20
        case .developerCleanup: return 90
        case .temporaryFiles: return 15
        case .fontCacheCleanup: return 15
        case .systemCacheCleanup: return 25
        case .dnsFlush: return 5
        case .memoryPurge: return 5
        case .diskMaintenance: return 120
        case .timeMachineSnapshot: return 30
        }
    }

    var coreKind: CleanupTaskKind {
        switch self {
        case .trashEmpty: return .trashEmpty
        case .userCacheCleanup: return .userCacheCleanup
        case .cacheCleanup: return .cacheCleanup
        case .safariCleanup: return .safariCleanup
        case .logCleanup: return .logCleanup
        case .developerCleanup: return .developerCleanup
        case .temporaryFiles: return .temporaryFiles
        case .fontCacheCleanup: return .fontCacheCleanup
        case .systemCacheCleanup: return .systemCacheCleanup
        case .dnsFlush: return .dnsFlush
        case .memoryPurge: return .memoryPurge
        case .diskMaintenance: return .diskMaintenance
        case .timeMachineSnapshot: return .timeMachineSnapshot
        }
    }
}

struct MaintenanceTask: Identifiable, Codable {
    var id = UUID()
    let type: MaintenanceTaskType
    var isEnabled: Bool
    var isCompleted: Bool = false
    var progress: Double = 0.0
    var status: TaskStatus = .pending
    var errorMessage: String?
    var resultMessage: String?
    var freedBytes: Int64 = 0

    init(type: MaintenanceTaskType, isEnabled: Bool? = nil) {
        self.type = type
        self.isEnabled = isEnabled ?? type.defaultEnabled
    }

    enum TaskStatus: String, Codable {
        case pending = "Pending"
        case running = "Running"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }
}
