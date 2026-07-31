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

    func testSystemCacheUsesAdminRunner() async {
        let mock = MockCommandRunner { command, asAdmin in
            XCTAssertTrue(asAdmin)
            XCTAssertTrue(command.contains("/Library/Caches"))
            return ("cleaned", 0)
        }
        let engine = CleanupEngine(runner: mock, dryRun: false)
        let result = await engine.perform(.systemCacheCleanup)
        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertTrue(mock.calls[0].asAdmin)
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
        XCTAssertFalse(CleanupTaskKind.trashEmpty.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.userCacheCleanup.requiresAdmin)
        XCTAssertFalse(CleanupTaskKind.safariCleanup.requiresAdmin)
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
