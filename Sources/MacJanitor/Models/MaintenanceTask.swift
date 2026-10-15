import Foundation
import MacJanitorCore

enum MaintenanceTaskType: String, CaseIterable, Identifiable, Codable {
    case cacheCleanup = "Cache Cleanup"
    case systemOptimization = "System Optimization"
    case diskMaintenance = "Disk Maintenance"
    case dnsFlush = "DNS Flush"
    case fontCacheCleanup = "Font Cache Cleanup"
    case logCleanup = "Log Cleanup"
    case trashEmpty = "Empty Trash"
    case memoryPurge = "Memory Purge"
    case safariCleanup = "Safari Cleanup"
    case systemCacheCleanup = "System Cache Cleanup"
    case userCacheCleanup = "User Cache Cleanup"
    case timeMachineSnapshot = "Time Machine Snapshot"
    case xcodeCleanup = "Xcode Derived Data"
    case userLogsCleanup = "User Logs"
    case downloadsCleanup = "Old Downloads"
    case homebrewCleanup = "Homebrew Cleanup"
    case periodicMaintenance = "Periodic Scripts"
    case browserCaches = "Browser Caches"
    case simulatorCleanup = "iOS Simulator"
    case packageCaches = "Package Caches"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .cacheCleanup:
            return "Clear application caches older than 7 days"
        case .systemOptimization:
            return "Speed up UI animations (Dock/Finder defaults)"
        case .diskMaintenance:
            return "Verify the startup disk volume"
        case .dnsFlush:
            return "Flush DNS cache for better network performance"
        case .fontCacheCleanup:
            return "Clear font cache to resolve font issues"
        case .logCleanup:
            return "Remove system logs older than 7 days"
        case .trashEmpty:
            return "Empty Trash on this Mac and mounted volumes"
        case .memoryPurge:
            return "Purge inactive memory (admin)"
        case .safariCleanup:
            return "Clear Safari browser caches"
        case .systemCacheCleanup:
            return "Clear system caches older than 7 days"
        case .userCacheCleanup:
            return "Clear user caches older than 7 days"
        case .timeMachineSnapshot:
            return "Create a local Time Machine snapshot"
        case .xcodeCleanup:
            return "Remove Xcode DerivedData (rebuilds required)"
        case .userLogsCleanup:
            return "Clear user Library/Logs older than 7 days"
        case .downloadsCleanup:
            return "Remove files in Downloads older than 30 days"
        case .homebrewCleanup:
            return "Run brew cleanup (if Homebrew is installed)"
        case .periodicMaintenance:
            return "Run classic daily/weekly/monthly maintenance scripts"
        case .browserCaches:
            return "Clear Chrome, Firefox, Edge, and Brave caches"
        case .simulatorCleanup:
            return "Remove iOS Simulator caches and unavailable devices"
        case .packageCaches:
            return "Clean npm, yarn, pip, and similar package caches"
        }
    }

    var icon: String {
        switch self {
        case .cacheCleanup: return "internaldrive"
        case .systemOptimization: return "speedometer"
        case .diskMaintenance: return "externaldrive.badge.checkmark"
        case .dnsFlush: return "network"
        case .fontCacheCleanup: return "textformat"
        case .logCleanup: return "doc.text"
        case .trashEmpty: return "trash.fill"
        case .memoryPurge: return "memorychip"
        case .safariCleanup: return "safari"
        case .systemCacheCleanup: return "gearshape.2"
        case .userCacheCleanup: return "person.crop.circle"
        case .timeMachineSnapshot: return "clock.arrow.circlepath"
        case .xcodeCleanup: return "hammer"
        case .userLogsCleanup: return "doc.plaintext"
        case .downloadsCleanup: return "arrow.down.circle"
        case .homebrewCleanup: return "cup.and.saucer"
        case .periodicMaintenance: return "calendar"
        case .browserCaches: return "globe"
        case .simulatorCleanup: return "iphone"
        case .packageCaches: return "shippingbox"
        }
    }

    var requiresReboot: Bool {
        switch self {
        case .fontCacheCleanup:
            return true
        default:
            return false
        }
    }

    var requiresAdmin: Bool {
        coreKind.requiresAdmin
    }

    var estimatedDuration: TimeInterval {
        switch self {
        case .cacheCleanup: return 30
        case .systemOptimization: return 10
        case .diskMaintenance: return 120
        case .dnsFlush: return 5
        case .fontCacheCleanup: return 15
        case .logCleanup: return 20
        case .trashEmpty: return 10
        case .memoryPurge: return 5
        case .safariCleanup: return 15
        case .systemCacheCleanup: return 25
        case .userCacheCleanup: return 20
        case .timeMachineSnapshot: return 30
        case .xcodeCleanup: return 15
        case .userLogsCleanup: return 15
        case .downloadsCleanup: return 20
        case .homebrewCleanup: return 30
        case .periodicMaintenance: return 60
        case .browserCaches: return 20
        case .simulatorCleanup: return 25
        case .packageCaches: return 20
        }
    }

    var coreKind: CleanupTaskKind {
        switch self {
        case .cacheCleanup: return .cacheCleanup
        case .systemOptimization: return .systemOptimization
        case .diskMaintenance: return .diskMaintenance
        case .dnsFlush: return .dnsFlush
        case .fontCacheCleanup: return .fontCacheCleanup
        case .logCleanup: return .logCleanup
        case .trashEmpty: return .trashEmpty
        case .memoryPurge: return .memoryPurge
        case .safariCleanup: return .safariCleanup
        case .systemCacheCleanup: return .systemCacheCleanup
        case .userCacheCleanup: return .userCacheCleanup
        case .timeMachineSnapshot: return .timeMachineSnapshot
        case .xcodeCleanup: return .xcodeCleanup
        case .userLogsCleanup: return .userLogsCleanup
        case .downloadsCleanup: return .downloadsCleanup
        case .homebrewCleanup: return .homebrewCleanup
        case .periodicMaintenance: return .periodicMaintenance
        case .browserCaches: return .browserCaches
        case .simulatorCleanup: return .simulatorCleanup
        case .packageCaches: return .packageCaches
        }
    }
}

struct MaintenanceTask: Identifiable, Codable {
    var id = UUID()
    let type: MaintenanceTaskType
    var isEnabled: Bool = true
    var isCompleted: Bool = false
    var progress: Double = 0.0
    var status: TaskStatus = .pending
    var errorMessage: String?
    var resultMessage: String?
    var freedBytes: Int64 = 0

    enum TaskStatus: String, Codable {
        case pending = "Pending"
        case running = "Running"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }
}
