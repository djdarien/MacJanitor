import Foundation

/// Performs real file-system cleanup and maintenance commands.
///
/// User-scoped work (trash, user caches) uses `FileManager` so results are measurable.
/// Privileged work is delegated to a `CommandRunner` (admin via app layer).
public struct CleanupEngine {
    public var fileManager: FileManager
    public var runner: any CommandRunner
    public var dryRun: Bool
    public var homeDirectory: URL
    public var volumesDirectory: URL
    public var minAgeDays: Int

    public init(
        fileManager: FileManager = .default,
        runner: any CommandRunner = ProcessCommandRunner(),
        dryRun: Bool = false,
        homeDirectory: URL? = nil,
        volumesDirectory: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true),
        minAgeDays: Int = 7
    ) {
        self.fileManager = fileManager
        self.runner = runner
        self.dryRun = dryRun
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.volumesDirectory = volumesDirectory
        self.minAgeDays = minAgeDays
    }

    // MARK: - Public entry

    public func perform(_ kind: CleanupTaskKind) async -> CleanupResult {
        switch kind {
        case .trashEmpty:
            return emptyTrash()
        case .userCacheCleanup:
            return cleanDirectory(
                homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true),
                label: "User caches",
                olderThanDays: minAgeDays
            )
        case .cacheCleanup:
            // Broad user cache sweep (same root, age-gated)
            return cleanDirectory(
                homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true),
                label: "Application caches",
                olderThanDays: minAgeDays
            )
        case .safariCleanup:
            return cleanSafariCaches()
        case .systemCacheCleanup:
            return await runAdminScript(
                """
                /usr/bin/find /Library/Caches -type f -mtime +\(minAgeDays) -delete 2>/dev/null || true
                /usr/bin/find /Library/Caches -type d -empty -delete 2>/dev/null || true
                echo "System caches older than \(minAgeDays) days cleaned"
                """,
                summary: "find /Library/Caches -mtime +\(minAgeDays)"
            )
        case .logCleanup:
            return await runAdminScript(
                """
                /usr/bin/find /var/log -type f \\( -name "*.log" -o -name "*.gz" -o -name "*.old" \\) -mtime +\(minAgeDays) -delete 2>/dev/null || true
                echo "Logs older than \(minAgeDays) days cleaned"
                """,
                summary: "find /var/log -mtime +\(minAgeDays)"
            )
        case .dnsFlush:
            return await runAdminScript(
                "dscacheutil -flushcache; killall -HUP mDNSResponder; echo DNS cache flushed",
                summary: "dscacheutil -flushcache && killall -HUP mDNSResponder"
            )
        case .fontCacheCleanup:
            return await runAdminScript(
                "atsutil databases -remove; echo Font caches removed",
                summary: "atsutil databases -remove"
            )
        case .memoryPurge:
            return await runAdminScript(
                "purge; echo Memory purge complete",
                summary: "purge"
            )
        case .diskMaintenance:
            return await runAdminScript(
                "diskutil verifyVolume /",
                summary: "diskutil verifyVolume /"
            )
        case .systemOptimization:
            // User-domain defaults — no admin required for current user prefs
            return await runUserScript(
                """
                defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
                defaults write com.apple.dock autohide-delay -float 0
                defaults write com.apple.finder DisableAllAnimations -bool true
                defaults write com.apple.dock expose-animation-duration -float 0.1
                defaults write com.apple.dock launchanim -bool false
                killall Dock 2>/dev/null || true
                killall Finder 2>/dev/null || true
                echo "UI animation optimizations applied"
                """,
                summary: "defaults write (animation tweaks)"
            )
        case .timeMachineSnapshot:
            return await runAdminScript(
                """
                if tmutil status >/dev/null 2>&1; then
                  tmutil localsnapshot && echo "Time Machine local snapshot created" || echo "Snapshot failed"
                else
                  echo "Time Machine tools unavailable or not configured"
                fi
                """,
                summary: "tmutil localsnapshot"
            )
        }
    }

    // MARK: - Trash

    /// User trash (`~/.Trash`) plus volume trash folders (`.Trashes`).
    public func emptyTrash() -> CleanupResult {
        var freed: Int64 = 0
        var removed = 0
        var notes: [String] = []
        var hadError = false

        let userTrash = userTrashURL()
        let userResult = emptyTrashDirectory(at: userTrash, label: "User Trash")
        freed += userResult.freedBytes
        removed += userResult.itemsRemoved
        notes.append(userResult.message)
        if !userResult.success { hadError = true }

        for volumeTrash in volumeTrashURLs() {
            let result = emptyTrashDirectory(at: volumeTrash, label: volumeTrash.path)
            freed += result.freedBytes
            removed += result.itemsRemoved
            notes.append(result.message)
            if !result.success { hadError = true }
        }

        let message: String
        if dryRun {
            message = "Dry run: would free \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)) (\(removed) items). " + notes.joined(separator: " | ")
        } else if removed == 0 && !hadError {
            message = "Trash already empty"
        } else {
            message = "Emptied trash: removed \(removed) items, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)). " + notes.joined(separator: " | ")
        }

        return CleanupResult(
            success: !hadError,
            freedBytes: dryRun ? 0 : freed,
            itemsRemoved: dryRun ? 0 : removed,
            message: message,
            commandSummary: "FileManager empty ~/.Trash + /Volumes/*/.Trashes"
        )
    }

    public func userTrashURL() -> URL {
        homeDirectory.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// macOS stores external-volume trash under `.Trashes` (not `.Trashed`).
    public func volumeTrashURLs() -> [URL] {
        guard let volumes = try? fileManager.contentsOfDirectory(
            at: volumesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for volume in volumes {
            // Skip the boot volume symlink if present as /
            let trashes = volume.appendingPathComponent(".Trashes", isDirectory: true)
            if fileManager.fileExists(atPath: trashes.path) {
                urls.append(trashes)
                // Nested per-UID folders are common; empty directory will recurse children
            }
        }
        return urls
    }

    public func emptyTrashDirectory(at directory: URL, label: String) -> CleanupResult {
        guard fileManager.fileExists(atPath: directory.path) else {
            return .success(message: "\(label): not present", command: directory.path)
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else {
            return .failure("\(label): could not list contents", command: directory.path)
        }

        var freed: Int64 = 0
        var removed = 0
        var errors: [String] = []

        for child in children {
            let size = allocatedSize(of: child)
            if dryRun {
                freed += size
                removed += 1
                continue
            }
            do {
                try fileManager.removeItem(at: child)
                freed += size
                removed += 1
            } catch {
                errors.append("\(child.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if errors.isEmpty {
            return CleanupResult(
                success: true,
                freedBytes: freed,
                itemsRemoved: removed,
                message: "\(label): \(removed) items",
                commandSummary: directory.path
            )
        }
        return CleanupResult(
            success: removed > 0,
            freedBytes: freed,
            itemsRemoved: removed,
            message: "\(label): removed \(removed), errors: \(errors.joined(separator: "; "))",
            commandSummary: directory.path
        )
    }

    // MARK: - Directory cleanup

    public func cleanDirectory(_ directory: URL, label: String, olderThanDays: Int?) -> CleanupResult {
        guard fileManager.fileExists(atPath: directory.path) else {
            return .success(message: "\(label): directory not found", command: directory.path)
        }

        let cutoff: Date? = olderThanDays.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date.distantPast
        }

        var freed: Int64 = 0
        var removed = 0
        var errors: [String] = []

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        )

        var candidates: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard shouldDelete(item, cutoff: cutoff) else { continue }
            candidates.append(item)
        }

        // Delete deepest paths first so directories empty cleanly
        candidates.sort { $0.pathComponents.count > $1.pathComponents.count }

        for item in candidates {
            let size = allocatedSize(of: item)
            if dryRun {
                freed += size
                removed += 1
                continue
            }
            do {
                // Skip if already removed as part of a parent
                guard fileManager.fileExists(atPath: item.path) else { continue }
                try fileManager.removeItem(at: item)
                freed += size
                removed += 1
            } catch {
                errors.append("\(item.lastPathComponent): \(error.localizedDescription)")
            }
        }

        let ageNote = olderThanDays.map { " (older than \($0) days)" } ?? ""
        if !errors.isEmpty {
            return CleanupResult(
                success: removed > 0,
                freedBytes: dryRun ? 0 : freed,
                itemsRemoved: dryRun ? 0 : removed,
                message: "\(label)\(ageNote): removed \(removed), errors: \(errors.prefix(3).joined(separator: "; "))",
                commandSummary: directory.path
            )
        }

        let verb = dryRun ? "would remove" : "removed"
        return CleanupResult(
            success: true,
            freedBytes: dryRun ? 0 : freed,
            itemsRemoved: dryRun ? 0 : removed,
            message: "\(label)\(ageNote): \(verb) \(removed) items, \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))",
            commandSummary: directory.path
        )
    }

    public func shouldDelete(_ url: URL, cutoff: Date?) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .isSymbolicLinkKey])
        if values?.isSymbolicLink == true { return false }

        if let cutoff {
            // For age filter, only delete files (and empty handling via files first)
            if values?.isDirectory == true {
                return false
            }
            guard let modified = values?.contentModificationDate else { return false }
            return modified < cutoff
        }
        // No age filter: delete files and directories that are direct cleanable content
        return true
    }

    public func cleanSafariCaches() -> CleanupResult {
        let roots = [
            homeDirectory.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Caches/CloudKit/com.apple.Safari", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Caches/Metadata/Safari", isDirectory: true),
        ]

        var freed: Int64 = 0
        var removed = 0
        var messages: [String] = []
        var ok = true

        for root in roots {
            let result = cleanDirectory(root, label: root.lastPathComponent, olderThanDays: nil)
            freed += result.freedBytes
            removed += result.itemsRemoved
            messages.append(result.message)
            if !result.success { ok = false }
        }

        return CleanupResult(
            success: ok,
            freedBytes: freed,
            itemsRemoved: removed,
            message: messages.joined(separator: " | "),
            commandSummary: "Safari cache directories"
        )
    }

    // MARK: - Shell helpers

    private func runAdminScript(_ script: String, summary: String) async -> CleanupResult {
        if dryRun {
            return .success(message: "Dry run: would run (admin): \(summary)", command: summary)
        }
        let (output, status) = await runner.run(script, asAdmin: true)
        if status == 0 {
            return .success(
                message: output?.isEmpty == false ? output! : "Completed: \(summary)",
                command: summary
            )
        }
        let detail = output?.isEmpty == false ? output! : "Exit status \(status)"
        return .failure(detail, command: summary)
    }

    private func runUserScript(_ script: String, summary: String) async -> CleanupResult {
        if dryRun {
            return .success(message: "Dry run: would run: \(summary)", command: summary)
        }
        let (output, status) = await runner.run(script, asAdmin: false)
        if status == 0 {
            return .success(
                message: output?.isEmpty == false ? output! : "Completed: \(summary)",
                command: summary
            )
        }
        let detail = output?.isEmpty == false ? output! : "Exit status \(status)"
        return .failure(detail, command: summary)
    }

    // MARK: - Size

    public func allocatedSize(of url: URL) -> Int64 {
        var total: Int64 = 0
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
            return 0
        }

        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: []
        )
        while let item = enumerator?.nextObject() as? URL {
            if let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
