import XCTest
import AppKit
@testable import MacAppCleanerKit

final class AppBrandIconTests: XCTestCase {
    func testAppBrandIconLoadsSuccessfullyWithoutCrashing() {
        let icon = AppBrandIcon.image
        XCTAssertNotNil(icon, "AppBrandIcon should locate the icon via bundle, system, or repository fallback")
        if let icon = icon {
            XCTAssertTrue(icon.isValid, "Loaded icon must be valid")
            XCTAssertGreaterThan(icon.size.width, 0, "Icon width should be positive")
            XCTAssertGreaterThan(icon.size.height, 0, "Icon height should be positive")
        }
    }
}
