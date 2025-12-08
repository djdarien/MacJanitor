import Foundation

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
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .cacheCleanup:
            return "Clear system and application caches"
        case .systemOptimization:
            return "Optimize system settings for better performance"
        case .diskMaintenance:
            return "Verify and repair disk volumes"
        case .dnsFlush:
            return "Flush DNS cache for better network performance"
        case .fontCacheCleanup:
            return "Clear font cache to resolve font issues"
        case .logCleanup:
            return "Clean up system log files"
        case .trashEmpty:
            return "Empty trash on all volumes"
        case .memoryPurge:
            return "Clear RAM cache for better memory management"
        case .safariCleanup:
            return "Clear Safari browser caches"
        case .systemCacheCleanup:
            return "Clear system-level caches"
        case .userCacheCleanup:
            return "Clear user-specific caches"
        }
    }
    
    var icon: String {
        switch self {
        case .cacheCleanup:
            return "trash"
        case .systemOptimization:
            return "speedometer"
        case .diskMaintenance:
            return "internaldrive"
        case .dnsFlush:
            return "network"
        case .fontCacheCleanup:
            return "textformat"
        case .logCleanup:
            return "doc.text"
        case .trashEmpty:
            return "trash.fill"
        case .memoryPurge:
            return "memorychip"
        case .safariCleanup:
            return "safari"
        case .systemCacheCleanup:
            return "gear"
        case .userCacheCleanup:
            return "person.crop.circle"
        }
    }
    
    var requiresReboot: Bool {
        switch self {
        case .systemOptimization, .fontCacheCleanup:
            return true
        default:
            return false
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .cacheCleanup:
            return 30
        case .systemOptimization:
            return 10
        case .diskMaintenance:
            return 120
        case .dnsFlush:
            return 5
        case .fontCacheCleanup:
            return 15
        case .logCleanup:
            return 20
        case .trashEmpty:
            return 10
        case .memoryPurge:
            return 5
        case .safariCleanup:
            return 15
        case .systemCacheCleanup:
            return 25
        case .userCacheCleanup:
            return 20
        }
    }
}

struct MaintenanceTask: Identifiable, Codable {
    let id = UUID()
    let type: MaintenanceTaskType
    var isEnabled: Bool = true
    var isCompleted: Bool = false
    var progress: Double = 0.0
    var status: TaskStatus = .pending
    var errorMessage: String?
    
    enum TaskStatus: String, Codable {
        case pending = "Pending"
        case running = "Running"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }
}