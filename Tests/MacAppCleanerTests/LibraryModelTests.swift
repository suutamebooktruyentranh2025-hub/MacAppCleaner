import XCTest
@testable import MacAppCleanerKit

final class LibraryModelTests: XCTestCase {
    func testInstalledLibraryModelInitialization() {
        let path = URL(fileURLWithPath: "/Library/Frameworks/Python.framework")
        let lib = InstalledLibrary(
            id: UUID(),
            name: "Python",
            version: "3.11.0",
            category: .frameworks,
            installPath: path,
            size: 150 * 1024 * 1024,
            riskLevel: .safe,
            dependencies: [],
            requiredBy: ["pip"],
            descriptionText: "Python Framework",
            isSystemProtected: false
        )

        XCTAssertEqual(lib.name, "Python")
        XCTAssertEqual(lib.version, "3.11.0")
        XCTAssertEqual(lib.category, .frameworks)
        XCTAssertEqual(lib.category.id, "Frameworks macOS")
        XCTAssertFalse(lib.category.icon.isEmpty)
        XCTAssertEqual(lib.size, 150 * 1024 * 1024)
        XCTAssertEqual(lib.riskLevel, .safe)
        XCTAssertEqual(lib.requiredBy, ["pip"])
        XCTAssertFalse(lib.isSystemProtected)
    }

    func testLibraryCategoryIconsAndDisplayNames() {
        for category in LibraryCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty)
            XCTAssertFalse(category.icon.isEmpty)
        }
    }
}
