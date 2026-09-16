import XCTest
@testable import MacAppCleanerKit

final class PermissionManagerTests: XCTestCase {
    func testPermissionManagerInstanceExists() {
        let manager = PermissionManager.shared
        // hasFullDiskAccess should evaluate to a boolean without crashing
        let fda = manager.hasFullDiskAccess()
        XCTAssertTrue(fda == true || fda == false)
    }
}
