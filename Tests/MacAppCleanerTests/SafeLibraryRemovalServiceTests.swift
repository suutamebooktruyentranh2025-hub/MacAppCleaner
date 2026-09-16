import XCTest
@testable import MacAppCleanerKit

final class SafeLibraryRemovalServiceTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testRejectsSystemProtectedLibrary() async {
        let protectedLib = InstalledLibrary(
            name: "AppleCore",
            version: "1.0",
            category: .frameworks,
            installPath: URL(fileURLWithPath: "/System/Library/Frameworks/AppleCore.framework"),
            size: 100,
            riskLevel: .systemProtected,
            isSystemProtected: true
        )

        let service = SafeLibraryRemovalService.shared
        do {
            try await service.removeLibrary(protectedLib)
            XCTFail("Should have thrown error for protected library")
        } catch {
            XCTAssertTrue(error is LibraryRemovalError)
        }
    }

    func testTrashesFilesystemLibrarySafely() async throws {
        let sampleFile = tempDir.appendingPathComponent("TestPlugin.vst3")
        try "dummy vst content".data(using: .utf8)!.write(to: sampleFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleFile.path))

        let lib = InstalledLibrary(
            name: "TestPlugin.vst3",
            version: "1.0",
            category: .audioPlugins,
            installPath: sampleFile,
            size: 100,
            riskLevel: .safe,
            isSystemProtected: false
        )

        let service = SafeLibraryRemovalService.shared
        try await service.removeLibrary(lib)

        // Item should no longer exist at original path (moved to Trash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sampleFile.path))
    }
}
