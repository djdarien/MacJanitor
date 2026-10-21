import Foundation

/// Outcome of a single maintenance/cleanup operation.
public struct CleanupResult: Equatable, Sendable {
    public var success: Bool
    public var freedBytes: Int64
    public var itemsRemoved: Int
    public var message: String
    public var commandSummary: String
    /// Bytes we could measure but could not delete (typically a permissions error).
    public var blockedBytes: Int64
    public var permissionDenied: Bool

    public init(
        success: Bool,
        freedBytes: Int64 = 0,
        itemsRemoved: Int = 0,
        message: String,
        commandSummary: String = "",
        blockedBytes: Int64 = 0,
        permissionDenied: Bool = false
    ) {
        self.success = success
        self.freedBytes = freedBytes
        self.itemsRemoved = itemsRemoved
        self.message = message
        self.commandSummary = commandSummary
        self.blockedBytes = blockedBytes
        self.permissionDenied = permissionDenied
    }

    public static func failure(
        _ message: String,
        command: String = "",
        blockedBytes: Int64 = 0,
        permissionDenied: Bool = false
    ) -> CleanupResult {
        CleanupResult(
            success: false,
            message: message,
            commandSummary: command,
            blockedBytes: blockedBytes,
            permissionDenied: permissionDenied
        )
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
    case temporaryFiles
    case diskMaintenance
    case dnsFlush
    case fontCacheCleanup
    case logCleanup
    case trashEmpty
    case memoryPurge
    case safariCleanup
    case systemCacheCleanup
    case userCacheCleanup
    case developerCleanup
    case timeMachineSnapshot

    /// Tasks that need an administrator prompt up front.
    /// Log cleanup elevates only when system logs are not writable.
    public var requiresAdmin: Bool {
        switch self {
        case .diskMaintenance, .dnsFlush, .fontCacheCleanup,
             .memoryPurge, .systemCacheCleanup, .timeMachineSnapshot:
            return true
        case .cacheCleanup, .temporaryFiles, .logCleanup, .trashEmpty,
             .safariCleanup, .userCacheCleanup, .developerCleanup:
            return false
        }
    }

    /// Tasks that delete files. The rest are optional system maintenance.
    public var freesDiskSpace: Bool {
        switch self {
        case .diskMaintenance, .dnsFlush, .memoryPurge, .timeMachineSnapshot:
            return false
        case .cacheCleanup, .temporaryFiles, .fontCacheCleanup, .logCleanup,
             .trashEmpty, .safariCleanup, .systemCacheCleanup, .userCacheCleanup,
             .developerCleanup:
            return true
        }
    }
}
