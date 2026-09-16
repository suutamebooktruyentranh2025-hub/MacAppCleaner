import XCTest
@testable import MacAppCleanerKit

final class AppDiscoveryTests: XCTestCase {
    func testDiscoverAppsFindsSystemAndThirdPartyApps() async {
        let service = AppDiscoveryService()
        let apps = await service.discoverInstalledApps()

        XCTAssertFalse(apps.isEmpty, "Should discover installed applications on this Mac")

        // Should find standard apps like Safari or Calculator or Terminal
        let hasCoreApp = apps.contains {
            $0.name.contains("Safari") ||
            $0.name.contains("Calculator") ||
            $0.bundleIdentifier == "com.apple.Safari" ||
            $0.bundleIdentifier == "com.apple.calculator"
        }
        XCTAssertTrue(hasCoreApp, "Should discover standard macOS applications")
    }
}
