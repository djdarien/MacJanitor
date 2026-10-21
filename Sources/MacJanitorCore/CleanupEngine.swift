import Foundation

/// Performs real file-system cleanup and maintenance commands.
///
/// User-scoped work (trash, caches, logs, browser and developer junk) uses
/// `FileManager` so results are measurable. Privileged work is delegated to a
/// `CommandRunner` only when the user cannot delete the files themselves.
public struct CleanupEngine {
    public var fileManager: FileManager
    public var runner: any CommandRunner
    public var dryRun: Bool
    public var homeDirectory: URL
    public var volumesDirectory: URL
    /// Age cutoff for logs and system caches. User/app caches ignore this when
    /// `deepCacheClean` is true.
    public var minAgeDays: Int
    /// When true, regenerable user and sandboxed-app caches are cleared even
    /// if they were written recently. iCloud, Photos, Music, and account
    /// folders are still skipped.
    public var deepCacheClean: Bool
    public var systemCacheDirectory: URL
    public var systemLogDirectory: URL
    public var libraryLogDirectory: URL
    public var temporaryDirectory: URL?
    public var tempMinAgeDays: Int

    public init(
        fileManager: FileManager = .default,
        runner: any CommandRunner = ProcessCommandRunner(),
        dryRun: Bool = false,
        homeDirectory: URL? = nil,
        volumesDirectory: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true),
        minAgeDays: Int = 7,
        deepCacheClean: Bool = true,
        systemCacheDirectory: URL = URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
        systemLogDirectory: URL = URL(fileURLWithPath: "/var/log", isDirectory: true),
        libraryLogDirectory: URL = URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
        temporaryDirectory: URL? = nil,
        tempMinAgeDays: Int = 1
    ) {
        self.fileManager = fileManager
        self.runner = runner
        self.dryRun = dryRun
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.volumesDirectory = volumesDirectory
        self.minAgeDays = minAgeDays
        self.deepCacheClean = deepCacheClean
        self.systemCacheDirectory = systemCacheDirectory
        self.systemLogDirectory = systemLogDirectory
        self.libraryLogDirectory = libraryLogDirectory
        self.temporaryDirectory = temporaryDirectory
        self.tempMinAgeDays = tempMinAgeDays
    }

    /// Nil means "delete regenerable cache contents regardless of age".
    public var userCacheMaxAgeDays: Int? {
        deepCacheClean ? nil : minAgeDays
    }

    // MARK: - Public entry

    public func perform(_ kind: CleanupTaskKind) async -> CleanupResult {
        switch kind {
        case .trashEmpty:
            return emptyTrash()
        case .userCacheCleanup:
            return cleanUserCaches()
        case .cacheCleanup:
            return cleanAppCaches()
        case .safariCleanup:
            return cleanBrowserCaches()
        case .logCleanup:
            return await cleanLogs()
        case .developerCleanup:
            return cleanDeveloperJunk()
        case .temporaryFiles:
            return cleanTemporaryFiles()
        case .fontCacheCleanup:
            return await cleanFontCaches()
        case .systemCacheCleanup:
            return await cleanSystemCaches()
        case .dnsFlush:
            return await runAdminScript(
                "dscacheutil -flushcache; killall -HUP mDNSResponder; echo DNS cache flushed",
                summary: "dscacheutil -flushcache && killall -HUP mDNSResponder"
            )
        case .memoryPurge:
            return await runAdminScript(
                """
                if command -v purge >/dev/null 2>&1; then
                  purge
                  echo "Memory purge complete"
                else
                  echo "purge is not available on this macOS version"
                fi
                """,
                summary: "purge"
            )
        case .diskMaintenance:
            return await runAdminScript(
                "diskutil verifyVolume /",
                summary: "diskutil verifyVolume /"
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
            message = "Dry run: would free \(format(freed)) (\(removed) items). " + notes.joined(separator: " | ")
        } else if removed == 0 && !hadError {
            message = "Trash already empty"
        } else {
            message = "Emptied trash: removed \(removed) items, freed \(format(freed)). " + notes.joined(separator: " | ")
        }

        return CleanupResult(
            success: !hadError,
            freedBytes: freed,
            itemsRemoved: removed,
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
            let trashes = volume.appendingPathComponent(".Trashes", isDirectory: true)
            if fileManager.fileExists(atPath: trashes.path) {
                urls.append(trashes)
            }
        }
        return urls
    }

    public func emptyTrashDirectory(at directory: URL, label: String) -> CleanupResult {
        if isSymbolicLink(directory) {
            return .success(message: "\(label): skipped symbolic link", command: directory.path)
        }
        guard fileManager.fileExists(atPath: directory.path) else {
            return .success(message: "\(label): not present", command: directory.path)
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else {
            return .failure("\(label): could not list contents", command: directory.path)
        }

        var freed: Int64 = 0
        var removed = 0
        var errors: [String] = []

        for child in children {
            if !isStrictlyInside(directory, item: child) { continue }
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

    // MARK: - Caches

    /// `~/Library/Caches`, skipping protected iCloud / media / account folders.
    public func cleanUserCaches() -> CleanupResult {
        let root = homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true)
        return cleanCacheRoot(root, label: "User caches", olderThanDays: userCacheMaxAgeDays)
    }

    /// Sandboxed app caches plus a fixed allow-list of Electron cache folders
    /// under Application Support. Never deletes the container or the app's
    /// Application Support root.
    public func cleanAppCaches() -> CleanupResult {
        var urls: [URL] = []
        urls.append(contentsOf: containerCacheURLs(
            root: homeDirectory.appendingPathComponent("Library/Containers", isDirectory: true),
            relativeCache: "Data/Library/Caches"
        ))
        urls.append(contentsOf: containerCacheURLs(
            root: homeDirectory.appendingPathComponent("Library/Group Containers", isDirectory: true),
            relativeCache: "Library/Caches"
        ))
        urls.append(contentsOf: applicationSupportCacheURLs())
        return cleanMany(
            urls,
            label: "App caches",
            olderThanDays: userCacheMaxAgeDays,
            respectProtection: true,
            command: "Containers + Group Containers + Application Support caches"
        )
    }

    /// Safari, Chromium-family, and Firefox *cache* directories only.
    public func cleanBrowserCaches() -> CleanupResult {
        cleanMany(
            browserCacheURLs(),
            label: "Browser caches",
            olderThanDays: nil,
            respectProtection: false,
            command: "Safari, Chromium, and Firefox cache directories"
        )
    }

    public func cleanDeveloperJunk() -> CleanupResult {
        cleanMany(
            developerCleanupURLs(),
            label: "Developer junk",
            olderThanDays: nil,
            respectProtection: true,
            command: "Xcode DerivedData, device support, simulator caches, package-manager caches"
        )
    }

    public func cleanTemporaryFiles() -> CleanupResult {
        let tempRoot = temporaryDirectory ?? fileManager.temporaryDirectory
        let quickLook = tempRoot
            .deletingLastPathComponent()
            .appendingPathComponent("C/com.apple.QuickLook.thumbnailcache", isDirectory: true)
        let userQuickLook = homeDirectory.appendingPathComponent(
            "Library/Caches/com.apple.QuickLook.thumbnailcache",
            isDirectory: true
        )

        let aged = cleanDirectory(tempRoot, label: "Temporary files", olderThanDays: tempMinAgeDays)
        let thumbs = cleanMany(
            [quickLook, userQuickLook],
            label: "Quick Look cache",
            olderThanDays: nil,
            respectProtection: true,
            command: "Quick Look thumbnail cache"
        )
        return summarize([aged, thumbs], label: "Temporary files", command: "TMPDIR + Quick Look")
    }

    // MARK: - Directory cleanup

    public func cleanDirectory(
        _ directory: URL,
        label: String,
        olderThanDays: Int?,
        respectProtection: Bool = true
    ) -> CleanupResult {
        if isSymbolicLink(directory) {
            return .success(message: "\(label): skipped symbolic link", command: directory.path)
        }
        guard fileManager.fileExists(atPath: directory.path) else {
            return .success(message: "\(label): directory not found", command: directory.path)
        }

        do {
            _ = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            let denied = isPermissionError(error)
            return .failure(
                "\(label): \(error.localizedDescription)",
                command: directory.path,
                permissionDenied: denied
            )
        }

        let cutoff: Date? = olderThanDays.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date.distantPast
        }

        var freed: Int64 = 0
        var blocked: Int64 = 0
        var removed = 0
        var errors: [String] = []
        var permissionDenied = false

        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
        ]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return .failure("\(label): could not list contents", command: directory.path)
        }

        var candidates: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if isSymbolicLink(item) {
                enumerator.skipDescendants()
                continue
            }
            if !isStrictlyInside(directory, item: item) {
                enumerator.skipDescendants()
                continue
            }
            guard shouldDelete(item, cutoff: cutoff, respectProtection: respectProtection) else {
                if respectProtection && CleanupSafety.isProtected(item) {
                    enumerator.skipDescendants()
                }
                continue
            }
            candidates.append(item)
        }

        // Deepest paths first so a directory is removed after its children.
        candidates.sort { $0.pathComponents.count > $1.pathComponents.count }

        for item in candidates {
            // Directory sizes include their files, which are counted separately.
            let countsAsItem = !isDirectory(item)
            let size = countsAsItem ? allocatedSize(of: item) : 0
            if dryRun {
                freed += size
                if countsAsItem { removed += 1 }
                continue
            }
            guard fileManager.fileExists(atPath: item.path) else { continue }
            do {
                try fileManager.removeItem(at: item)
                freed += size
                if countsAsItem { removed += 1 }
            } catch {
                if isPermissionError(error) {
                    permissionDenied = true
                    blocked += size
                } else if errors.count < 3 {
                    errors.append("\(item.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        if !dryRun {
            removeEmptyDirectories(under: directory, respectProtection: respectProtection)
        }

        let ageNote = olderThanDays.map { " (older than \($0) days)" } ?? ""
        if permissionDenied || !errors.isEmpty {
            let detail = errors.isEmpty ? "permission denied" : errors.joined(separator: "; ")
            return CleanupResult(
                success: false,
                freedBytes: freed,
                itemsRemoved: removed,
                message: "\(label)\(ageNote): removed \(removed), \(detail)",
                commandSummary: directory.path,
                blockedBytes: blocked,
                permissionDenied: permissionDenied
            )
        }

        let verb = dryRun ? "would remove" : "removed"
        return CleanupResult(
            success: true,
            freedBytes: freed,
            itemsRemoved: removed,
            message: "\(label)\(ageNote): \(verb) \(removed) items, \(format(freed))",
            commandSummary: directory.path
        )
    }

    public func shouldDelete(_ url: URL, cutoff: Date?, respectProtection: Bool = true) -> Bool {
        if respectProtection && CleanupSafety.isProtected(url) { return false }
        if isSymbolicLink(url) { return false }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .isSymbolicLinkKey])
        if values?.isSymbolicLink == true { return false }

        if let cutoff {
            if values?.isDirectory == true { return false }
            guard let modified = modificationDate(of: url, values: values) else { return false }
            return modified < cutoff
        }
        return true
    }

    // MARK: - Logs, fonts, system caches

    public func cleanLogs() async -> CleanupResult {
        var results: [CleanupResult] = [
            cleanDirectory(
                homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true),
                label: "User logs",
                olderThanDays: minAgeDays
            ),
            cleanDirectory(
                homeDirectory.appendingPathComponent("Library/Application Support/CrashReporter", isDirectory: true),
                label: "Crash reports",
                olderThanDays: minAgeDays
            ),
        ]

        let systemTargets = [systemLogDirectory, libraryLogDirectory]
        for directory in systemTargets {
            results.append(cleanDirectory(directory, label: directory.lastPathComponent, olderThanDays: minAgeDays))
        }

        if !dryRun && results.contains(where: \.permissionDenied) {
            let blocked = results.filter(\.permissionDenied)
            let script = systemLogScript(for: blocked.map { URL(fileURLWithPath: $0.commandSummary) })
            let admin = await runAdminScript(script, summary: "find system logs -mtime +\(minAgeDays)")
            if admin.success {
                let recovered = blocked.reduce(Int64(0)) { $0 + $1.blockedBytes + $1.freedBytes }
                results.removeAll(where: \.permissionDenied)
                results.append(
                    .success(
                        freedBytes: recovered,
                        message: admin.message.isEmpty ? "System logs cleaned" : admin.message,
                        command: admin.commandSummary
                    )
                )
            } else {
                results.append(admin)
            }
        }

        return summarize(results, label: "Logs", command: "user logs, crash reports, system logs")
    }

    public func cleanFontCaches() async -> CleanupResult {
        let user = cleanMany(
            [
                homeDirectory.appendingPathComponent("Library/Caches/com.apple.FontRegistry", isDirectory: true),
                homeDirectory.appendingPathComponent("Library/Caches/com.apple.ATS", isDirectory: true),
                homeDirectory.appendingPathComponent("Library/Caches/com.apple.FontRegistry.user", isDirectory: true),
            ],
            label: "User font caches",
            olderThanDays: nil,
            respectProtection: true,
            command: "user font caches"
        )
        if dryRun {
            return CleanupResult(
                success: true,
                freedBytes: user.freedBytes,
                itemsRemoved: user.itemsRemoved,
                message: "Dry run: \(user.message). Would also run atsutil databases -remove",
                commandSummary: "user font caches + atsutil databases -remove"
            )
        }

        let admin = await runAdminScript(
            "atsutil databases -remove; echo Font caches removed",
            summary: "atsutil databases -remove"
        )
        if admin.success {
            return CleanupResult(
                success: true,
                freedBytes: user.freedBytes,
                itemsRemoved: user.itemsRemoved,
                message: "\(user.message) | \(admin.message)",
                commandSummary: "user font caches + atsutil databases -remove"
            )
        }
        if user.itemsRemoved > 0 {
            return CleanupResult(
                success: true,
                freedBytes: user.freedBytes,
                itemsRemoved: user.itemsRemoved,
                message: "\(user.message) | System font database: \(admin.message)",
                commandSummary: "user font caches + atsutil databases -remove"
            )
        }
        return admin
    }

    public func cleanSystemCaches() async -> CleanupResult {
        let scanned = cleanDirectory(
            systemCacheDirectory,
            label: "System caches",
            olderThanDays: minAgeDays
        )
        guard !dryRun, scanned.permissionDenied else { return scanned }

        let quoted = shellQuote(systemCacheDirectory.path)
        let admin = await runAdminScript(
            """
            /usr/bin/find \(quoted) -mindepth 1 -type f -mtime +\(minAgeDays) -delete 2>/dev/null || true
            /usr/bin/find \(quoted) -mindepth 1 -type d -empty -delete 2>/dev/null || true
            echo "System caches older than \(minAgeDays) days cleaned"
            """,
            summary: "find \(systemCacheDirectory.path) -mtime +\(minAgeDays)"
        )
        guard admin.success else { return admin }
        return CleanupResult(
            success: true,
            freedBytes: scanned.freedBytes + scanned.blockedBytes,
            itemsRemoved: scanned.itemsRemoved,
            message: admin.message,
            commandSummary: admin.commandSummary
        )
    }

    // MARK: - Discovery

    public func containerCacheURLs(root: URL, relativeCache: String) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for entry in entries {
            if isSymbolicLink(entry) || CleanupSafety.isProtected(entry) { continue }
            let caches = relativeCache.split(separator: "/").reduce(entry) { partial, part in
                partial.appendingPathComponent(String(part), isDirectory: true)
            }
            if fileManager.fileExists(atPath: caches.path) && !isSymbolicLink(caches) {
                urls.append(caches)
            }
        }
        return urls
    }

    public func applicationSupportCacheURLs() -> [URL] {
        let names = [
            "Slack", "discord", "Code", "Code - Insiders", "Cursor",
            "Microsoft Teams", "Figma", "Notion", "Zoom", "Signal",
            "WhatsApp", "Telegram", "spotify", "Spotify",
        ]
        let cacheNames = [
            "Cache", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache",
            "DawnGraphiteCache", "DawnWebGPUCache", "CachedData",
        ]
        let support = homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
        return names.flatMap { app in
            cacheNames.map { cache in
                support.appendingPathComponent(app, isDirectory: true)
                    .appendingPathComponent(cache, isDirectory: true)
            }
        }
    }

    public func browserCacheURLs() -> [URL] {
        var urls: [URL] = []
        let safari = [
            "Library/Caches/com.apple.Safari",
            "Library/Caches/CloudKit/com.apple.Safari",
            "Library/Caches/Metadata/Safari",
            "Library/Containers/com.apple.Safari/Data/Library/Caches",
            "Library/Containers/com.apple.WebKit.WebContent/Data/Library/Caches",
            "Library/Containers/com.apple.WebKit.Networking/Data/Library/Caches",
            "Library/Containers/com.apple.WebKit.GPU/Data/Library/Caches",
        ]
        urls.append(contentsOf: safari.map { homeDirectory.appendingPathComponent($0, isDirectory: true) })

        let chromiumApps = [
            "Google/Chrome",
            "Google/Chrome Canary",
            "Google/Chrome Beta",
            "Chromium",
            "Microsoft Edge",
            "BraveSoftware/Brave-Browser",
            "Arc",
            "Vivaldi",
            "com.operasoftware.Opera",
            "DuckDuckGo",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",
        ]
        for app in chromiumApps {
            urls.append(contentsOf: chromiumProfileCacheURLs(appSupportRelative: app))
            urls.append(homeDirectory.appendingPathComponent("Library/Caches", isDirectory: true)
                .appendingPathComponent(app, isDirectory: true))
        }

        urls.append(contentsOf: firefoxCacheURLs())
        return urls
    }

    public func developerCleanupURLs() -> [URL] {
        let xcode = homeDirectory.appendingPathComponent("Library/Developer/Xcode", isDirectory: true)
        let relative = [
            "Library/Developer/CoreSimulator/Caches",
            "Library/Caches/Homebrew",
            "Library/Caches/CocoaPods",
            "Library/Caches/org.carthage.CarthageKit",
            "Library/Caches/org.swift.swiftpm",
            "Library/Caches/pip",
            "Library/Caches/Yarn",
            "Library/Caches/com.apple.dt.Xcode",
            ".npm/_cacache",
            ".yarn/cache",
            ".gradle/caches",
            ".cargo/registry/cache",
            ".cache/pip",
        ]
        var urls = relative.map { homeDirectory.appendingPathComponent($0, isDirectory: true) }
        let xcodeChildren = [
            "DerivedData",
            "iOS DeviceSupport",
            "watchOS DeviceSupport",
            "tvOS DeviceSupport",
            "macOS DeviceSupport",
            "iOS Device Logs",
        ]
        urls.append(contentsOf: xcodeChildren.map { xcode.appendingPathComponent($0, isDirectory: true) })
        return urls
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

    private func systemLogScript(for directories: [URL]) -> String {
        let bodies = directories.map { directory -> String in
            let quoted = shellQuote(directory.path)
            return """
            /usr/bin/find \(quoted) -mindepth 1 -type f \\( -name "*.log" -o -name "*.gz" -o -name "*.old" -o -name "*.crash" -o -name "*.ips" \\) -mtime +\(minAgeDays) -delete 2>/dev/null || true
            """
        }
        return bodies.joined(separator: "\n") + "\necho \"System logs older than \(minAgeDays) days cleaned\""
    }

    func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Internals

    private func cleanCacheRoot(_ root: URL, label: String, olderThanDays: Int?) -> CleanupResult {
        if isSymbolicLink(root) {
            return .success(message: "\(label): skipped symbolic link", command: root.path)
        }
        guard fileManager.fileExists(atPath: root.path) else {
            return .success(message: "\(label): directory not found", command: root.path)
        }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
                options: []
            )
        } catch {
            return .failure(
                "\(label): \(error.localizedDescription)",
                command: root.path,
                permissionDenied: isPermissionError(error)
            )
        }

        var results: [CleanupResult] = []
        for child in children {
            if isSymbolicLink(child) { continue }
            if CleanupSafety.isProtected(child) { continue }
            if isDirectory(child) {
                results.append(cleanDirectory(child, label: child.lastPathComponent, olderThanDays: olderThanDays))
            } else if shouldDelete(child, cutoff: cutoffDate(olderThanDays), respectProtection: true) {
                results.append(deleteFile(child, label: child.lastPathComponent))
            }
        }
        return summarize(results, label: label, command: root.path)
    }

    private func cleanMany(
        _ urls: [URL],
        label: String,
        olderThanDays: Int?,
        respectProtection: Bool,
        command: String
    ) -> CleanupResult {
        let results = urls.compactMap { url -> CleanupResult? in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return cleanDirectory(
                url,
                label: url.lastPathComponent,
                olderThanDays: olderThanDays,
                respectProtection: respectProtection
            )
        }
        return summarize(results, label: label, command: command)
    }

    private func deleteFile(_ url: URL, label: String) -> CleanupResult {
        if !isStrictlyInside(homeDirectory, item: url) && !isStrictlyInside(url.deletingLastPathComponent(), item: url) {
            return .success(message: "\(label): skipped", command: url.path)
        }
        let size = allocatedSize(of: url)
        if dryRun {
            return .success(freedBytes: size, itemsRemoved: 1, message: "would remove \(label)", command: url.path)
        }
        do {
            try fileManager.removeItem(at: url)
            return .success(freedBytes: size, itemsRemoved: 1, message: "removed \(label)", command: url.path)
        } catch {
            return .failure(
                "\(label): \(error.localizedDescription)",
                command: url.path,
                blockedBytes: isPermissionError(error) ? size : 0,
                permissionDenied: isPermissionError(error)
            )
        }
    }

    private func summarize(_ results: [CleanupResult], label: String, command: String) -> CleanupResult {
        let present = results.filter { !$0.message.contains("directory not found") && !$0.message.contains("not present") }
        if present.isEmpty {
            return .success(message: "\(label): nothing to clean", command: command)
        }
        let freed = present.reduce(Int64(0)) { $0 + $1.freedBytes }
        let removed = present.reduce(0) { $0 + $1.itemsRemoved }
        let blocked = present.reduce(Int64(0)) { $0 + $1.blockedBytes }
        let denied = present.contains(where: \.permissionDenied)
        let failures = present.filter { !$0.success }
        let verb = dryRun ? "would remove" : "removed"
        var message = "\(label): \(verb) \(removed) items, \(format(freed))"
        if let detail = failures.first?.message {
            message += ". \(detail)"
        }
        return CleanupResult(
            success: failures.isEmpty,
            freedBytes: freed,
            itemsRemoved: removed,
            message: message,
            commandSummary: command,
            blockedBytes: blocked,
            permissionDenied: denied
        )
    }

    private func chromiumProfileCacheURLs(appSupportRelative: String) -> [URL] {
        let root = homeDirectory
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(appSupportRelative, isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let cacheNames = [
            "Cache", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache",
            "DawnGraphiteCache", "DawnWebGPUCache",
        ]
        var urls: [URL] = []
        for entry in entries {
            let name = entry.lastPathComponent
            let isProfile = name == "Default" || name == "Guest Profile" || name == "System Profile" || name.hasPrefix("Profile ")
            guard isProfile else { continue }
            for cache in cacheNames {
                urls.append(entry.appendingPathComponent(cache, isDirectory: true))
            }
        }
        return urls
    }

    private func firefoxCacheURLs() -> [URL] {
        var urls = [homeDirectory.appendingPathComponent("Library/Caches/Firefox", isDirectory: true)]
        let roots = [
            homeDirectory.appendingPathComponent("Library/Application Support/Firefox/Profiles", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Caches/Firefox/Profiles", isDirectory: true),
        ]
        let children = ["cache2", "startupCache", "shader-cache", "thumbnails"]
        for root in roots {
            guard let profiles = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for profile in profiles {
                for child in children {
                    urls.append(profile.appendingPathComponent(child, isDirectory: true))
                }
            }
        }
        return urls
    }

    private func cutoffDate(_ olderThanDays: Int?) -> Date? {
        olderThanDays.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date.distantPast
        }
    }

    private func modificationDate(of url: URL, values: URLResourceValues?) -> Date? {
        if let modified = values?.contentModificationDate { return modified }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func removeEmptyDirectories(under root: URL, respectProtection: Bool) {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else { return }

        var directories: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            if isSymbolicLink(item) {
                enumerator.skipDescendants()
                continue
            }
            if isDirectory(item) {
                directories.append(item)
            }
        }
        directories.sort { $0.pathComponents.count > $1.pathComponents.count }
        for directory in directories {
            if respectProtection && CleanupSafety.isProtected(directory) { continue }
            if !isStrictlyInside(root, item: directory) { continue }
            guard let children = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
                  children.isEmpty else { continue }
            try? fileManager.removeItem(at: directory)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        if isSymbolicLink(url) { return false }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values?.isSymbolicLink == true { return false }
        if let isDirectory = values?.isDirectory { return isDirectory }
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
            return true
        }
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let type = attributes[.type] as? FileAttributeType {
            return type == .typeSymbolicLink
        }
        return false
    }

    /// True when `item` stays inside `root` after resolving symbolic links.
    func isStrictlyInside(_ root: URL, item: URL) -> Bool {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let itemPath = item.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return itemPath.hasPrefix(prefix)
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.code == NSFileWriteNoPermissionError || ns.code == NSFileReadNoPermissionError { return true }
        if ns.code == 513 || ns.code == 257 { return true }
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(EACCES) { return true }
        let text = ns.localizedDescription.lowercased()
        return text.contains("permission") || text.contains("not permitted")
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    public func allocatedSize(of url: URL) -> Int64 {
        if isSymbolicLink(url) { return 0 }
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                if size > 0 { return size }
            }
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            if let number = attributes?[.size] as? NSNumber { return number.int64Value }
            return 0
        }

        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else { return 0 }

        while let item = enumerator.nextObject() as? URL {
            if isSymbolicLink(item) {
                enumerator.skipDescendants()
                continue
            }
            if !isStrictlyInside(url, item: item) {
                enumerator.skipDescendants()
                continue
            }
            let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
            let isFile = values?.isRegularFile ?? !isDirectory(item)
            guard isFile else { continue }
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            if size > 0 {
                total += size
            } else if let attributes = try? fileManager.attributesOfItem(atPath: item.path),
                      let number = attributes[.size] as? NSNumber {
                total += number.int64Value
            }
        }
        return total
    }
}
