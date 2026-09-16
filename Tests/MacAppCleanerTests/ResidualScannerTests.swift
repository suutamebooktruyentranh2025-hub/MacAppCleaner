import XCTest
@testable import MacAppCleanerKit

final class ResidualScannerTests: XCTestCase {
    let fileManager = FileManager.default
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
    }

    func testResidualScannerDetectsRelatedFiles() async throws {
        let bundleID = "com.example.DemoApp"
        let appName = "DemoApp"

        // Mock test residual directories
        let mockAppSupport = tempDirectory.appendingPathComponent("Application Support/\(bundleID)")
        try fileManager.createDirectory(at: mockAppSupport, withIntermediateDirectories: true)
        let sampleData = "Test residual content".data(using: .utf8)!
        try sampleData.write(to: mockAppSupport.appendingPathComponent("config.json"))

        let mockCache = tempDirectory.appendingPathComponent("Caches/\(bundleID)")
        try fileManager.createDirectory(at: mockCache, withIntermediateDirectories: true)
        try sampleData.write(to: mockCache.appendingPathComponent("cache.db"))

        let scanner = ResidualScanner(customLibraryURL: tempDirectory)
        let testApp = InstalledApp(
            name: appName,
            bundleURL: tempDirectory.appendingPathComponent("\(appName).app"),
            bundleIdentifier: bundleID,
            version: "1.0"
        )

        let residuals = await scanner.findResidualFiles(for: testApp)
        XCTAssertGreaterThanOrEqual(residuals.count, 2)
        XCTAssertTrue(residuals.contains(where: { $0.category == .applicationSupport }))
        XCTAssertTrue(residuals.contains(where: { $0.category == .caches }))
    }

    func testTrashServiceRejectsProtectedFiles() {
        let trashService = TrashService(safetyGuard: SafetyGuardService.shared)
        let systemURL = URL(fileURLWithPath: "/System/Library")

        XCTAssertThrowsError(try trashService.trashItem(at: systemURL)) { error in
            XCTAssertEqual(error as? TrashError, .systemProtected(path: systemURL.path))
        }
    }
}
