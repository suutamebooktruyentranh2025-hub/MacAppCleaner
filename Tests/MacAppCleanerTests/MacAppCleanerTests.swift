import XCTest
@testable import MacAppCleanerKit

final class MacAppCleanerTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(MacAppCleanerKit.version, "1.0.0")
    }
}
