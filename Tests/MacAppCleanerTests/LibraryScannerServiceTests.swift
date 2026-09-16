import XCTest
@testable import MacAppCleanerKit

final class MockLibraryProvider: LibraryProvider, Sendable {
    let category: LibraryCategory
    let mockLibraries: [InstalledLibrary]

    init(category: LibraryCategory, mockLibraries: [InstalledLibrary]) {
        self.category = category
        self.mockLibraries = mockLibraries
    }

    func scanLibraries() async -> [InstalledLibrary] {
        return mockLibraries
    }
}

final class LibraryScannerServiceTests: XCTestCase {
    func testAggregatesMultipleProvidersConcurrently() async {
        let lib1 = InstalledLibrary(
            name: "LibA",
            version: "1.0",
            category: .frameworks,
            installPath: URL(fileURLWithPath: "/Library/Frameworks/LibA.framework"),
            size: 200,
            riskLevel: .safe
        )
        let lib2 = InstalledLibrary(
            name: "PkgB",
            version: "2.0",
            category: .homebrew,
            installPath: URL(fileURLWithPath: "/opt/homebrew/Cellar/PkgB"),
            size: 500,
            riskLevel: .safe
        )

        let providerA = MockLibraryProvider(category: .frameworks, mockLibraries: [lib1])
        let providerB = MockLibraryProvider(category: .homebrew, mockLibraries: [lib2])

        let service = LibraryScannerService(providers: [providerA, providerB])
        let allLibs = await service.scanAllLibraries()

        XCTAssertEqual(allLibs.count, 2)
        // Should sort by size descending
        XCTAssertEqual(allLibs[0].name, "PkgB")
        XCTAssertEqual(allLibs[1].name, "LibA")
        XCTAssertEqual(service.totalLibrariesSize(libraries: allLibs), 700)
    }

    func testCategoryFiltering() async {
        let lib1 = InstalledLibrary(
            name: "LibA",
            version: "1.0",
            category: .frameworks,
            installPath: URL(fileURLWithPath: "/Library/Frameworks/LibA.framework"),
            size: 200,
            riskLevel: .safe
        )
        let lib2 = InstalledLibrary(
            name: "PkgB",
            version: "2.0",
            category: .homebrew,
            installPath: URL(fileURLWithPath: "/opt/homebrew/Cellar/PkgB"),
            size: 500,
            riskLevel: .safe
        )

        let service = LibraryScannerService(providers: [
            MockLibraryProvider(category: .frameworks, mockLibraries: [lib1]),
            MockLibraryProvider(category: .homebrew, mockLibraries: [lib2])
        ])

        let filtered = service.filter(libraries: [lib1, lib2], by: .frameworks, query: "")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "LibA")

        let searched = service.filter(libraries: [lib1, lib2], by: .all, query: "Pkg")
        XCTAssertEqual(searched.count, 1)
        XCTAssertEqual(searched.first?.name, "PkgB")
    }
}
