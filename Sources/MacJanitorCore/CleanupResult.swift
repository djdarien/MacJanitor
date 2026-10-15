import Foundation

/// Outcome of a single maintenance/cleanup operation.
public struct CleanupResult: Equatable, Sendable {
    public var success: Bool
    public var freedBytes: Int64
    public var itemsRemoved: Int
    public var message: String
    public var commandSummary: String

    public init(
        success: Bool,
        freedBytes: Int64 = 0,
        itemsRemoved: Int = 0,
        message: String,
        commandSummary: String = ""
    ) {
        self.success = success
        self.freedBytes = freedBytes
        self.itemsRemoved = itemsRemoved
        self.message = message
        self.commandSummary = commandSummary
    }

    public static func failure(_ message: String, command: String = "") -> CleanupResult {
        CleanupResult(success: false, message: message, commandSummary: command)
    }

    public static func success(
        freedBytes: Int64 = 0,
        itemsRemoved: Int = 0,
        message: String,
        command: String = ""
    ) -> CleanupResult {
        CleanupResult(
            success: true,
            freedBytes: freedBytes,
            itemsRemoved: itemsRemoved,
            message: message,
            commandSummary: command
        )
    }

    public var formattedFreed: String {
        ByteCountFormatter.string(fromByteCount: max(0, freedBytes), countStyle: .file)
    }
}

/// High-level maintenance task kinds the core engine understands.
public enum CleanupTaskKind: String, CaseIterable, Sendable {
    case cacheCleanup
    case systemOptimization
    case diskMaintenance
    case dnsFlush
    case fontCacheCleanup
    case logCleanup
    case trashEmpty
    case memoryPurge
    case safariCleanup
    case systemCacheCleanup
    case userCacheCleanup
    case timeMachineSnapshot
    case xcodeCleanup
    case userLogsCleanup
    case downloadsCleanup
    case homebrewCleanup
    case periodicMaintenance

    public var requiresAdmin: Bool {
        switch self {
        case .systemOptimization, .diskMaintenance, .dnsFlush, .fontCacheCleanup,
             .logCleanup, .memoryPurge, .systemCacheCleanup, .timeMachineSnapshot,
             .periodicMaintenance:
            return true
        case .cacheCleanup, .trashEmpty, .safariCleanup, .userCacheCleanup,
             .xcodeCleanup, .userLogsCleanup, .downloadsCleanup, .homebrewCleanup:
            return false
        }
    }
}
