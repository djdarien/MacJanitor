import XCTest
@testable import MacJanitorCore

final class CleanupEngineTests: XCTestCase {
    var tempRoot: URL!
    var fm: FileManager!

    override func setUpWithError() throws {
        fm = FileManager.default
        tempRoot = fm.temporaryDirectory.appendingPathComponent("MacJanitorTests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempRoot)
    }

    // MARK: - Paths

    func testUserTrashURL() {
        let home = tempRoot.appendingPathComponent("User", isDirectory: true)
        let engine = CleanupEngine(homeDirectory: home)
        XCTAssertEqual(engine.userTrashURL().path, home.appendingPathComponent(".Trash").path)
    }

    func testVolumeTrashUsesTrashesNotTrashed() throws {
        let volumes = tempRoot.appendingPathComponent("Volumes", isDirectory: true)
        let disk = volumes.appendingPathComponent("External", isDirectory: true)
        let trashes = disk.appendingPathComponent(".Trashes", isDirectory: true)
        try fm.createDirectory(at: trashes, withIntermediateDirectories: true)

        // Wrong legacy path should NOT be discovered
        try fm.createDirectory(
            at: disk.appendingPathComponent(".Trashed", isDirectory: true),
            withIntermediateDirectories: true
        )

        let engine = CleanupEngine(homeDirectory: tempRoot, volumesDirectory: volumes)
        let urls = engine.volumeTrashURLs()
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls[0].path.hasSuffix(".Trashes"))
        XCTAssertFalse(urls.contains(where: { $0.path.hasSuffix(".Trashed") }))
    }

    // MARK: - Empty trash

    func testEmptyTrashRemovesFilesAndReportsBytes() throws {
        let home = tempRoot.appendingPathComponent("Home", isDirectory: true)
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)

        let file = trash.appendingPathComponent("junk.txt")
        let payload = Data(repeating: 0x41, count: 4096)
        try payload.write(to: file)

        let engine = CleanupEngine(
            runner: MockCommandRunner(),
            dryRun: false,
            homeDirectory: home,
            volumesDirectory: tempRoot.appendingPathComponent("NoVolumes", isDirectory: true)
        )

        let result = engine.emptyTrash()
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.itemsRemoved, 1)
        XCTAssertGreaterThan(result.freedBytes, 0)
        XCTAssertFalse(fm.fileExists(atPath: file.path))
    }

    func testEmptyTrashDryRunDoesNotDelete() throws {
        let home = tempRoot.appendingPathComponent("Home2", isDirectory: true)
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let file = trash.appendingPathComponent("keep.txt")
        try Data("hello".utf8).write(to: file)

        let engine = CleanupEngine(
            dryRun: true,
            homeDirectory: home,
            volumesDirectory: tempRoot.appendingPathComponent("NoVolumes2", isDirectory: true)
        )
        let result = engine.emptyTrash()
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("Dry run"))
        XCTAssertTrue(fm.fileExists(atPath: file.path))
    }

    func testEmptyVolumeTrashes() throws {
        let home = tempRoot.appendingPathComponent("Home3", isDirectory: true)
        try fm.createDirectory(at: home.appendingPathComponent(".Trash", isDirectory: true), withIntermediateDirectories: true)

        let volumes = tempRoot.appendingPathComponent("Volumes3", isDirectory: true)
        let disk = volumes.appendingPathComponent("USB", isDirectory: true)
        let trashes = disk.appendingPathComponent(".Trashes", isDirectory: true)
        try fm.createDirectory(at: trashes, withIntermediateDirectories: true)
        let junk = trashes.appendingPathComponent("old.mov")
        try Data(repeating: 0x42, count: 2048).write(to: junk)

        let engine = CleanupEngine(homeDirectory: home, volumesDirectory: volumes)
        let result = engine.emptyTrash()
        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: junk.path))
        XCTAssertGreaterThanOrEqual(result.itemsRemoved, 1)
    }

    // MARK: - Age filter

    func testAgeFilterDeletesOnlyOldFiles() throws {
        let caches = tempRoot.appendingPathComponent("Caches", isDirectory: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)

        let oldFile = caches.appendingPathComponent("old.dat")
        let newFile = caches.appendingPathComponent("new.dat")
        try Data("old".utf8).write(to: oldFile)
        try Data("new".utf8).write(to: newFile)

        let oldDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile.path)

        let engine = CleanupEngine(minAgeDays: 7)
        let result = engine.cleanDirectory(caches, label: "Caches", olderThanDays: 7)

        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: oldFile.path))
        XCTAssertTrue(fm.fileExists(atPath: newFile.path))
    }

    func testShouldDeleteRespectsCutoff() {
        let engine = CleanupEngine()
        let url = tempRoot.appendingPathComponent("f.txt")
        try? Data("x".utf8).write(to: url)
        let old = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        try? fm.setAttributes([.modificationDate: old], ofItemAtPath: url.path)

        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertTrue(engine.shouldDelete(url, cutoff: cutoff))

        let recentCutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        XCTAssertFalse(engine.shouldDelete(url, cutoff: recentCutoff))
    }

    // MARK: - Admin routing

    func testSystemCacheUsesAdminRunnerOnlyWhenDeleteIsDenied() async throws {
        let caches = tempRoot.appendingPathComponent("SystemCaches", isDirectory: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        let file = caches.appendingPathComponent("old.tmp")
        try Data(repeating: 0x11, count: 2048).write(to: file)
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        try fm.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: caches.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: caches.path) }

        let mock = MockCommandRunner { command, asAdmin in
            XCTAssertTrue(asAdmin)
            XCTAssertTrue(command.contains(caches.path))
            return ("cleaned", 0)
        }
        let engine = CleanupEngine(
            runner: mock,
            dryRun: false,
            homeDirectory: tempRoot.appendingPathComponent("HomeAdmin"),
            systemCacheDirectory: caches,
            systemLogDirectory: tempRoot.appendingPathComponent("no-syslog"),
            libraryLogDirectory: tempRoot.appendingPathComponent("no-liblog")
        )
        let result = await engine.perform(.systemCacheCleanup)
        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertGreaterThan(result.freedBytes, 0)
    }

    func testSystemCacheSkipsAdminWhenUserCanDelete() async throws {
        let caches = tempRoot.appendingPathComponent("WritableSystemCaches", isDirectory: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        let file = caches.appendingPathComponent("old.tmp")
        try Data("stale".utf8).write(to: file)
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        try fm.setAttributes([.modificationDate: old], ofItemAtPath: file.path)

        let mock = MockCommandRunner()
        let engine = CleanupEngine(
            runner: mock,
            homeDirectory: tempRoot.appendingPathComponent("HomeWritable"),
            systemCacheDirectory: caches,
            systemLogDirectory: tempRoot.appendingPathComponent("no-syslog-2"),
            libraryLogDirectory: tempRoot.appendingPathComponent("no-liblog-2")
        )
        let result = await engine.perform(.systemCacheCleanup)
        XCTAssertTrue(result.success)
        XCTAssertTrue(mock.calls.isEmpty)
        XCTAssertFalse(fm.fileExists(atPath: file.path))
    }

    func testTrashDoesNotCallRunner() async {
        let mock = MockCommandRunner()
        let home = tempRoot.appendingPathComponent("Home4", isDirectory: true)
        try? fm.createDirectory(at: home.appendingPathComponent(".Trash", isDirectory: true), withIntermediateDirectories: true)
        let engine = CleanupEngine(
            runner: mock,
            homeDirectory: home,
            volumesDirectory: tempRoot.appendingPathComponent("emptyVol", isDirectory: true)
        )
        _ = await engine.perform(.trashEmpty)
        XCTAssertTrue(mock.calls.isEmpty)
    }

    func testDryRunAdminDoesNotInvokeRunner() async {
        let mock = MockCommandRunner()
        let engine = CleanupEngine(runner: mock, dryRun: true)
        let result = await engine.perform(.dnsFlush)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("Dry run"))
        XCTAssertTrue(mock.calls.isEmpty)
    }

    func testRequiresAdminMatrix() {
        XCTAssertTrue(CleanupTaskKind.dnsFlush.requiresAdmin)
        XCTAssertTrue(CleanupTaskKind.systemCacheCleanup.requiresAdmin)
        XCTAssertTrue(CleanupTaskKind.fontCacheCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.logCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.trashEmpty.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.userCacheCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.cacheCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.safariCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.developerCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.temporaryFiles.requiresAdmin)
        XCTAssertTrue(CleanupTaskKind.developerCleanup.freesDiskSpace)
        XCTAssertFalse(CleanupTaskKind.dnsFlush.freesDiskSpace)
        XCTAssertFalse(CleanupTaskKind.memoryPurge.freesDiskSpace)
    }

    func testAdminFailureSurfacesMessage() async {
        let mock = MockCommandRunner { _, _ in
            ("User canceled", 126)
        }
        let engine = CleanupEngine(runner: mock)
        let result = await engine.perform(.memoryPurge)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("canceled") || result.message.contains("User"))
    }
}

final class OperationPathTests: XCTestCase {
    func testCleanupResultFormatting() {
        let result = CleanupResult.success(freedBytes: 1024, itemsRemoved: 2, message: "ok")
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.formattedFreed.isEmpty)
    }
}

final class RealCleanupTests: XCTestCase {
    var tempRoot: URL!
    var fm: FileManager!
    var home: URL!

    override func setUpWithError() throws {
        fm = FileManager.default
        tempRoot = fm.temporaryDirectory.appendingPathComponent("MacJanitorReal-\(UUID().uuidString)", isDirectory: true)
        home = tempRoot.appendingPathComponent("Home", isDirectory: true)
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempRoot)
    }

    func testDeepUserCacheRemovesRecentJunkAndKeepsProtectedData() throws {
        let chrome = try write("Library/Caches/com.google.Chrome/Cache/data.bin", bytes: 4096)
        let cloud = try write("Library/Caches/CloudKit/record.dat", bytes: 2048)
        let photos = try write("Library/Caches/com.apple.Photos/thumb.jpg", bytes: 1024)
        let music = try write("Library/Caches/com.apple.Music/artwork.bin", bytes: 1024)

        let result = engine().cleanUserCaches()
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.freedBytes, 0)
        XCTAssertFalse(fm.fileExists(atPath: chrome.path))
        XCTAssertTrue(fm.fileExists(atPath: cloud.path))
        XCTAssertTrue(fm.fileExists(atPath: photos.path))
        XCTAssertTrue(fm.fileExists(atPath: music.path))
    }

    func testShallowCacheKeepsRecentFiles() throws {
        let recent = try write("Library/Caches/com.google.Chrome/Cache/new.bin")
        let old = try write("Library/Caches/com.google.Chrome/Cache/old.bin", ageDays: 30)

        let result = engine(deepCacheClean: false).cleanUserCaches()
        XCTAssertTrue(result.success)
        XCTAssertTrue(fm.fileExists(atPath: recent.path))
        XCTAssertFalse(fm.fileExists(atPath: old.path))
    }

    func testAppCachesCleanContainersWithoutTouchingAppData() throws {
        let cache = try write("Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Caches/blob.bin", bytes: 3000)
        let secret = try write("Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/secret.txt")
        let docs = try write("Library/Containers/com.tinyspeck.slackmacgap/Data/Documents/keep.txt")
        let photos = try write("Library/Containers/com.apple.Photos/Data/Library/Caches/thumb.bin")
        let groupCache = try write("Library/Group Containers/group.com.example.app/Library/Caches/blob.bin", bytes: 1500)
        let groupPrefs = try write("Library/Group Containers/group.com.example.app/Library/Preferences/keep.plist")
        let icloud = try write("Library/Group Containers/group.com.apple.icloud.fmfcore/Library/Caches/sync.bin")
        let slackCache = try write("Library/Application Support/Slack/Cache/data.bin", bytes: 2500)
        let slackStorage = try write("Library/Application Support/Slack/Local Storage/leveldb/keep")

        let result = engine().cleanAppCaches()
        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: cache.path))
        XCTAssertFalse(fm.fileExists(atPath: groupCache.path))
        XCTAssertFalse(fm.fileExists(atPath: slackCache.path))
        XCTAssertTrue(fm.fileExists(atPath: secret.path))
        XCTAssertTrue(fm.fileExists(atPath: docs.path))
        XCTAssertTrue(fm.fileExists(atPath: photos.path))
        XCTAssertTrue(fm.fileExists(atPath: groupPrefs.path))
        XCTAssertTrue(fm.fileExists(atPath: icloud.path))
        XCTAssertTrue(fm.fileExists(atPath: slackStorage.path))
    }

    func testBrowserCleanupKeepsProfileData() throws {
        let http = try write("Library/Application Support/Google/Chrome/Default/Cache/f_000001", bytes: 8000)
        let cookies = try write("Library/Application Support/Google/Chrome/Default/Cookies")
        let history = try write("Library/Application Support/Google/Chrome/Default/History")
        let logins = try write("Library/Application Support/Google/Chrome/Default/Login Data")
        let disk = try write("Library/Caches/Google/Chrome/Default/Cache/data.bin", bytes: 4000)
        let places = try write("Library/Application Support/Firefox/Profiles/abc.default-release/places.sqlite")
        let ffCache = try write("Library/Application Support/Firefox/Profiles/abc.default-release/cache2/entries/x", bytes: 2000)
        let safari = try write("Library/Caches/com.apple.Safari/Webpage Previews/x.png", bytes: 1200)

        let result = engine().cleanBrowserCaches()
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.freedBytes, 0)
        XCTAssertFalse(fm.fileExists(atPath: http.path))
        XCTAssertFalse(fm.fileExists(atPath: disk.path))
        XCTAssertFalse(fm.fileExists(atPath: ffCache.path))
        XCTAssertFalse(fm.fileExists(atPath: safari.path))
        XCTAssertTrue(fm.fileExists(atPath: cookies.path))
        XCTAssertTrue(fm.fileExists(atPath: history.path))
        XCTAssertTrue(fm.fileExists(atPath: logins.path))
        XCTAssertTrue(fm.fileExists(atPath: places.path))
    }

    func testDeveloperJunkKeepsArchivesSourceAndDevices() throws {
        let derived = try write("Library/Developer/Xcode/DerivedData/App/Build/a.o", bytes: 9000)
        let archive = try write("Library/Developer/Xcode/Archives/App.xcarchive/Info.plist")
        let symbols = try write("Library/Developer/Xcode/iOS DeviceSupport/iPhone15/Symbols/foo", bytes: 5000)
        let simCache = try write("Library/Developer/CoreSimulator/Caches/dyld/cache", bytes: 3000)
        let simDevice = try write("Library/Developer/CoreSimulator/Devices/UDID/data/keep.txt")
        let npm = try write(".npm/_cacache/content/sha", bytes: 2200)
        let cargoCache = try write(".cargo/registry/cache/crate.tgz", bytes: 1800)
        let cargoBin = try write(".cargo/bin/tool")

        let result = engine().cleanDeveloperJunk()
        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: derived.path))
        XCTAssertFalse(fm.fileExists(atPath: symbols.path))
        XCTAssertFalse(fm.fileExists(atPath: simCache.path))
        XCTAssertFalse(fm.fileExists(atPath: npm.path))
        XCTAssertFalse(fm.fileExists(atPath: cargoCache.path))
        XCTAssertTrue(fm.fileExists(atPath: archive.path))
        XCTAssertTrue(fm.fileExists(atPath: simDevice.path))
        XCTAssertTrue(fm.fileExists(atPath: cargoBin.path))
    }

    func testLogsRemoveOnlyOldFiles() async throws {
        let oldLog = try write("Library/Logs/SomeApp/old.log", ageDays: 30)
        let newLog = try write("Library/Logs/SomeApp/new.log", ageDays: 1)
        let crash = try write("Library/Application Support/CrashReporter/old.crash", ageDays: 21)

        let result = await engine().cleanLogs()
        XCTAssertTrue(result.success, result.message)
        XCTAssertFalse(fm.fileExists(atPath: oldLog.path))
        XCTAssertFalse(fm.fileExists(atPath: crash.path))
        XCTAssertTrue(fm.fileExists(atPath: newLog.path))
    }

    func testTemporaryFilesRespectAgeAndClearQuickLook() throws {
        let temp = tempRoot.appendingPathComponent("T", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        let stale = temp.appendingPathComponent("stale.tmp")
        let fresh = temp.appendingPathComponent("fresh.tmp")
        try Data("old".utf8).write(to: stale)
        try Data("new".utf8).write(to: fresh)
        let old = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        try fm.setAttributes([.modificationDate: old], ofItemAtPath: stale.path)

        let thumb = tempRoot.appendingPathComponent("C/com.apple.QuickLook.thumbnailcache/thumb.jpg")
        try fm.createDirectory(at: thumb.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x22, count: 1500).write(to: thumb)

        let result = engine(temporaryDirectory: temp).cleanTemporaryFiles()
        XCTAssertTrue(result.success)
        XCTAssertFalse(fm.fileExists(atPath: stale.path))
        XCTAssertTrue(fm.fileExists(atPath: fresh.path))
        XCTAssertFalse(fm.fileExists(atPath: thumb.path))
    }

    func testSymlinkDoesNotEscapeIntoDocuments() throws {
        let important = try write("Documents/important.txt")
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        try fm.createSymbolicLink(
            at: caches.appendingPathComponent("com.evil.cache"),
            withDestinationURL: important.deletingLastPathComponent()
        )
        let realCache = try write("Library/Caches/com.google.Chrome/data.bin")
        try fm.createSymbolicLink(
            at: home.appendingPathComponent("Library/Caches/com.google.Chrome/escape"),
            withDestinationURL: important
        )

        let result = engine().cleanUserCaches()
        XCTAssertTrue(result.success)
        XCTAssertTrue(fm.fileExists(atPath: important.path))
        XCTAssertFalse(fm.fileExists(atPath: realCache.path))
    }

    func testDryRunReportsBytesWithoutDeleting() throws {
        let file = try write("Library/Caches/com.google.Chrome/Cache/data.bin", bytes: 4096)
        let result = engine(dryRun: true).cleanUserCaches()
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("would remove"))
        XCTAssertGreaterThan(result.freedBytes, 0)
        XCTAssertTrue(fm.fileExists(atPath: file.path))
    }

    func testPersonalDataSurvivesAFullDiskPass() async throws {
        let documents = try write("Documents/tax.pdf")
        let desktop = try write("Desktop/photo.jpg")
        let downloads = try write("Downloads/installer.dmg")
        let mail = try write("Library/Mail/V10/INBOX.mbox/keep.emlx")
        let messages = try write("Library/Messages/chat.db")
        let photosLib = try write("Library/Photos/Libraries/Photos Library.photoslibrary/database/photos.db")
        let icloud = try write("Library/Mobile Documents/com~apple~CloudDocs/notes.txt")
        let backup = try write("Library/Application Support/MobileSync/Backup/0000/Info.plist")
        let keychain = try write("Library/Keychains/login.keychain-db")
        let junk = try write("Library/Caches/com.spotify.client/Cache/audio.bin", bytes: 6000)

        let janitor = engine()
        for kind in [CleanupTaskKind.trashEmpty, .userCacheCleanup, .cacheCleanup, .safariCleanup, .developerCleanup, .temporaryFiles] {
            let result = await janitor.perform(kind)
            XCTAssertTrue(result.success, result.message)
        }
        let logs = await janitor.cleanLogs()
        XCTAssertTrue(logs.success, logs.message)

        for survivor in [documents, desktop, downloads, mail, messages, photosLib, icloud, backup, keychain] {
            XCTAssertTrue(fm.fileExists(atPath: survivor.path), survivor.path)
        }
        XCTAssertFalse(fm.fileExists(atPath: junk.path))
    }

    func testProtectedGroupContainerName() {
        XCTAssertTrue(CleanupSafety.matches("com.apple.Photos"))
        XCTAssertTrue(CleanupSafety.matches("group.com.apple.icloud.fmfcore"))
        XCTAssertTrue(CleanupSafety.matches("com.apple.HomeKit.Widgets"))
        XCTAssertFalse(CleanupSafety.matches("com.google.Chrome"))
        XCTAssertFalse(CleanupSafety.matches("com.tinyspeck.slackmacgap"))
    }

    private func engine(
        dryRun: Bool = false,
        deepCacheClean: Bool = true,
        temporaryDirectory: URL? = nil
    ) -> CleanupEngine {
        CleanupEngine(
            runner: MockCommandRunner(),
            dryRun: dryRun,
            homeDirectory: home,
            volumesDirectory: tempRoot.appendingPathComponent("NoVolumes", isDirectory: true),
            deepCacheClean: deepCacheClean,
            systemCacheDirectory: tempRoot.appendingPathComponent("EmptySystemCaches", isDirectory: true),
            systemLogDirectory: tempRoot.appendingPathComponent("EmptySyslog", isDirectory: true),
            libraryLogDirectory: tempRoot.appendingPathComponent("EmptyLiblog", isDirectory: true),
            temporaryDirectory: temporaryDirectory ?? tempRoot.appendingPathComponent("EmptyTemp", isDirectory: true)
        )
    }

    @discardableResult
    private func write(_ relative: String, bytes: Int = 64, ageDays: Int? = nil) throws -> URL {
        let url = relative.split(separator: "/").reduce(home) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        if let ageDays {
            let date = Calendar.current.date(byAdding: .day, value: -ageDays, to: Date())!
            try fm.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return url
    }
}
