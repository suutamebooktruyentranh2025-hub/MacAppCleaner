import XCTest
@testable import MacAppCleanerKit

final class ModelTests: XCTestCase {
    func testByteFormatting() {
        let kbString = ByteCountFormatter.format(bytes: 1024)
        let mbString = ByteCountFormatter.format(bytes: 1024 * 1024)
        let gbString = ByteCountFormatter.format(bytes: 1024 * 1024 * 1024)

        XCTAssertTrue(kbString.contains("KB") || kbString.contains("kB"), "Should format KB: \(kbString)")
        XCTAssertTrue(mbString.contains("MB"), "Should format MB: \(mbString)")
        XCTAssertTrue(gbString.contains("GB"), "Should format GB: \(gbString)")
    }

    func testInstalledAppTotalSizeCalculation() {
        let app = InstalledApp(
            id: UUID(),
            name: "TestApp",
            bundleURL: URL(fileURLWithPath: "/Applications/Test.app"),
            bundleIdentifier: "com.test.app",
            version: "1.0",
            architecture: .arm64,
            installDate: Date(),
            appSize: 1000,
            residualFiles: [
                RelatedFile(url: URL(fileURLWithPath: "/tmp/cache"), size: 500, category: .caches),
                RelatedFile(url: URL(fileURLWithPath: "/tmp/pref"), size: 200, category: .preferences)
            ],
            isSystemApp: false
        )

        XCTAssertEqual(app.totalSize, 1700)
        XCTAssertEqual(app.selectedSize, 1700)
    }
}
