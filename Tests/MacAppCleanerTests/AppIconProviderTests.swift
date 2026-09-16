import XCTest
import AppKit
@testable import MacAppCleanerKit

final class AppIconProviderTests: XCTestCase {
    func testAppIconProviderReturnsValidIconForApplicationsDirectory() {
        let provider = AppIconProvider.shared
        let url = URL(fileURLWithPath: "/Applications")
        let targetSize = CGSize(width: 48, height: 48)

        let icon = provider.icon(for: url, size: targetSize)
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 48)
        XCTAssertEqual(icon.size.height, 48)
    }

    func testAppIconProviderReturnsValidIconForKnownApp() {
        let provider = AppIconProvider.shared
        let candidates = [
            "/Applications/Safari.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Applications/Calculator.app"
        ]

        let existingApp = candidates.first { FileManager.default.fileExists(atPath: $0) }
        guard let appPath = existingApp else {
            XCTFail("At least one standard macOS application should exist")
            return
        }

        let icon = provider.icon(forPath: appPath, size: CGSize(width: 64, height: 64))
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 64)
        XCTAssertEqual(icon.size.height, 64)
    }

    func testAppIconProviderCachesLoadedIcons() {
        let provider = AppIconProvider.shared
        provider.clearCache()

        let url = URL(fileURLWithPath: "/Applications")
        let icon1 = provider.icon(for: url, size: CGSize(width: 32, height: 32))
        let icon2 = provider.icon(for: url, size: CGSize(width: 32, height: 32))

        XCTAssertTrue(icon1 === icon2, "Successive calls for the same URL and size should return the cached instance")
    }

    func testAppIconProviderClearCacheEvictsObjects() {
        let provider = AppIconProvider.shared
        let url = URL(fileURLWithPath: "/Applications")

        let icon1 = provider.icon(for: url, size: CGSize(width: 32, height: 32))
        provider.clearCache()
        let icon2 = provider.icon(for: url, size: CGSize(width: 32, height: 32))

        XCTAssertFalse(icon1 === icon2, "After clearCache, a fresh instance should be produced")
    }
}
