import XCTest
@testable import MacAppCleanerKit

final class AppProcessManagerTests: XCTestCase {
    func testNonExistentAppIsNotRunning() {
        let manager = AppProcessManager.shared
        let fakeURL = URL(fileURLWithPath: "/Applications/NonExistentTestApp12345.app")
        let isRunning = manager.isAppRunning(bundleURL: fakeURL, bundleIdentifier: "com.fake.app.test12345")
        XCTAssertFalse(isRunning)

        let processes = manager.runningProcesses(bundleURL: fakeURL, bundleIdentifier: "com.fake.app.test12345")
        XCTAssertTrue(processes.isEmpty)
    }

    func testDetectsRunningFinder() {
        let manager = AppProcessManager.shared
        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        let isRunning = manager.isAppRunning(bundleURL: finderURL, bundleIdentifier: "com.apple.finder")
        XCTAssertTrue(isRunning)

        let processes = manager.runningProcesses(bundleURL: finderURL, bundleIdentifier: "com.apple.finder")
        XCTAssertFalse(processes.isEmpty)
    }

    func testTrashErrorDescriptionsAreInformative() {
        let runningError = TrashError.appIsRunning(appName: "TestApp", pids: [123, 456])
        XCTAssertTrue(runningError.localizedDescription.contains("TestApp"))
        XCTAssertTrue(runningError.localizedDescription.contains("123"))

        let permError = TrashError.permissionDenied(path: "/Applications/RootApp.app", message: "Yêu cầu quyền Admin")
        XCTAssertTrue(permError.localizedDescription.contains("RootApp.app"))
    }
}
