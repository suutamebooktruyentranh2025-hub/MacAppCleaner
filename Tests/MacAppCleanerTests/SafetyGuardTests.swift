import XCTest
@testable import MacAppCleanerKit

final class SafetyGuardTests: XCTestCase {
    let service = SafetyGuardService()

    func testSystemPathsAreProtected() {
        let systemURLs = [
            URL(fileURLWithPath: "/System"),
            URL(fileURLWithPath: "/System/Library"),
            URL(fileURLWithPath: "/usr"),
            URL(fileURLWithPath: "/usr/bin"),
            URL(fileURLWithPath: "/usr/bin/python3"),
            URL(fileURLWithPath: "/bin"),
            URL(fileURLWithPath: "/bin/zsh"),
            URL(fileURLWithPath: "/sbin"),
            URL(fileURLWithPath: "/private/var/vm"),
            URL(fileURLWithPath: "/private/var/vm/sleepimage"),
            URL(fileURLWithPath: "/Library/Apple"),
            URL(fileURLWithPath: "/System/Applications/Finder.app"),
            URL(fileURLWithPath: "/System/Applications/Safari.app")
        ]

        for url in systemURLs {
            XCTAssertTrue(service.isSystemProtected(url: url), "Path should be protected: \(url.path)")
            XCTAssertThrowsError(try service.validateDeletion(url: url)) { error in
                guard let safetyError = error as? SafetyGuardError else {
                    XCTFail("Unexpected error: \(error)")
                    return
                }
                XCTAssertEqual(safetyError, .systemFileProtected)
            }
        }
    }

    func testUserFilesAreNotProtected() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let userURLs = [
            homeDir.appendingPathComponent("Downloads/some_file.zip"),
            homeDir.appendingPathComponent("Documents/my_doc.pdf"),
            URL(fileURLWithPath: "/Applications/SomeThirdPartyApp.app")
        ]

        for url in userURLs {
            XCTAssertFalse(service.isSystemProtected(url: url), "User path should NOT be protected: \(url.path)")
            XCTAssertNoThrow(try service.validateDeletion(url: url))
        }
    }

    func testAppleBundleIDsAreProtected() {
        XCTAssertTrue(service.isProtectedApp(bundleIdentifier: "com.apple.finder", bundleURL: URL(fileURLWithPath: "/System/Applications/Finder.app")))
        XCTAssertTrue(service.isProtectedApp(bundleIdentifier: "com.apple.Safari", bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")))
        XCTAssertFalse(service.isProtectedApp(bundleIdentifier: "com.google.Chrome", bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome.app")))
    }
}
