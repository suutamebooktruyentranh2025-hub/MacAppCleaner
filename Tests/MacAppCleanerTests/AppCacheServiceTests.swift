import XCTest
@testable import MacAppCleanerKit

final class AppCacheServiceTests: XCTestCase {
    let fileManager = FileManager.default
    var tempCacheDirectory: URL!
    var cacheService: AppCacheService!

    override func setUpWithError() throws {
        tempCacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("test_cache_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempCacheDirectory, withIntermediateDirectories: true)
        cacheService = AppCacheService(customCacheDirectory: tempCacheDirectory)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempCacheDirectory)
    }

    func testSaveAndLoadAppsCache() async throws {
        let dummyApp = InstalledApp(
            id: UUID(),
            name: "TestApp",
            bundleURL: URL(fileURLWithPath: "/Applications/TestApp.app"),
            bundleIdentifier: "com.test.app",
            version: "1.0.0",
            architecture: .arm64,
            appSize: 1024 * 1024
        )

        cacheService.saveApps([dummyApp])

        // Allow async Task to write to disk
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let cached = try XCTUnwrap(cacheService.loadCachedApps())
        XCTAssertEqual(cached.apps.count, 1)
        XCTAssertEqual(cached.apps.first?.name, "TestApp")
        XCTAssertEqual(cached.apps.first?.bundleIdentifier, "com.test.app")
    }

    func testSaveAndLoadLibrariesCache() async throws {
        let dummyLib = InstalledLibrary(
            name: "llama3:latest",
            version: "latest",
            category: .aiModels,
            installPath: URL(fileURLWithPath: "/Users/admin/.ollama/models/manifests/llama3"),
            size: 4000000,
            riskLevel: .safe
        )

        cacheService.saveLibraries([dummyLib])

        // Allow async Task to write to disk
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let cached = try XCTUnwrap(cacheService.loadCachedLibraries())
        XCTAssertEqual(cached.libraries.count, 1)
        XCTAssertEqual(cached.libraries.first?.name, "llama3:latest")
        XCTAssertEqual(cached.libraries.first?.category, .aiModels)
    }

    func testSaveAndLoadDiskRootCache() async throws {
        let root = DiskItem(
            url: URL(fileURLWithPath: "/Users/admin"),
            name: "admin",
            isDirectory: true,
            size: 50000000,
            children: [
                DiskItem(url: URL(fileURLWithPath: "/Users/admin/Downloads"), name: "Downloads", isDirectory: true, size: 20000000)
            ]
        )

        cacheService.saveDiskRoot(root)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let cached = try XCTUnwrap(cacheService.loadCachedDiskRoot())
        XCTAssertEqual(cached.item.name, "admin")
        XCTAssertEqual(cached.item.children?.count, 1)
        XCTAssertEqual(cached.item.children?.first?.name, "Downloads")
    }

    func testSaveAndLoadDiskRootCacheScopes() async throws {
        let homeRoot = DiskItem(url: URL(fileURLWithPath: "/Users/admin"), name: "admin", isDirectory: true, size: 50)
        let systemRoot = DiskItem(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", isDirectory: true, size: 100)

        cacheService.saveDiskRoot(homeRoot, scope: "home")
        cacheService.saveDiskRoot(systemRoot, scope: "system")

        try await Task.sleep(nanoseconds: 100_000_000)

        let cachedHome = try XCTUnwrap(cacheService.loadCachedDiskRoot(scope: "home"))
        let cachedSystem = try XCTUnwrap(cacheService.loadCachedDiskRoot(scope: "system"))

        XCTAssertEqual(cachedHome.item.name, "admin")
        XCTAssertEqual(cachedSystem.item.name, "Macintosh HD")
    }

    func testSaveAndLoadLargeFilesCacheScopes() async throws {
        let homeFile = DiskItem(url: URL(fileURLWithPath: "/Users/admin/large.bin"), name: "large.bin", isDirectory: false, size: 600 * 1024 * 1024)
        let sysFile = DiskItem(url: URL(fileURLWithPath: "/Library/sys.dmg"), name: "sys.dmg", isDirectory: false, size: 900 * 1024 * 1024)

        cacheService.saveLargeFiles([homeFile], minBytes: 500 * 1024 * 1024, scope: "home")
        cacheService.saveLargeFiles([sysFile], minBytes: 500 * 1024 * 1024, scope: "system")

        try await Task.sleep(nanoseconds: 100_000_000)

        let homeCached = try XCTUnwrap(cacheService.loadCachedLargeFiles(minBytes: 500 * 1024 * 1024, scope: "home"))
        let sysCached = try XCTUnwrap(cacheService.loadCachedLargeFiles(minBytes: 500 * 1024 * 1024, scope: "system"))

        XCTAssertEqual(homeCached.files.first?.name, "large.bin")
        XCTAssertEqual(sysCached.files.first?.name, "sys.dmg")
    }

    func testClearAllCache() async throws {
        let dummyApp = InstalledApp(
            id: UUID(),
            name: "AppToDelete",
            bundleURL: URL(fileURLWithPath: "/Applications/App.app"),
            bundleIdentifier: "com.test.app",
            version: "1.0",
            architecture: .universal,
            appSize: 500
        )

        cacheService.saveApps([dummyApp])
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(cacheService.loadCachedApps())

        cacheService.clearAllCache()
        XCTAssertNil(cacheService.loadCachedApps())
    }
}
