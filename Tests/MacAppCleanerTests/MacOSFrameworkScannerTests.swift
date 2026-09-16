import XCTest
@testable import MacAppCleanerKit

final class MacOSFrameworkScannerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFrameworkScannerDetectsMockFramework() async throws {
        // Create mock framework
        let fwDir = tempDir.appendingPathComponent("SampleTool.framework")
        let resDir = fwDir.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resDir, withIntermediateDirectories: true)
        
        let plistData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.sample.SampleTool</string>
            <key>CFBundleShortVersionString</key>
            <string>1.2.3</string>
        </dict>
        </plist>
        """.data(using: .utf8)!
        try plistData.write(to: resDir.appendingPathComponent("Info.plist"))
        try "dummy binary payload".data(using: .utf8)!.write(to: fwDir.appendingPathComponent("SampleTool"))

        let scanner = MacOSFrameworkScanner(searchPaths: [tempDir])
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 1)
        let first = libs[0]
        XCTAssertEqual(first.name, "SampleTool")
        XCTAssertEqual(first.version, "1.2.3")
        XCTAssertEqual(first.category, .frameworks)
        XCTAssertGreaterThan(first.size, 0)
        XCTAssertFalse(first.isSystemProtected)
    }

    func testAudioPluginScannerDetectsVSTAndComponent() async throws {
        let vstDir = tempDir.appendingPathComponent("Synth.vst3")
        let compDir = tempDir.appendingPathComponent("Filter.component")
        try FileManager.default.createDirectory(at: vstDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: compDir, withIntermediateDirectories: true)

        let scanner = AudioPluginScanner(searchPaths: [tempDir])
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 2)
        XCTAssertTrue(libs.contains { $0.name == "Synth.vst3" && $0.category == .audioPlugins })
        XCTAssertTrue(libs.contains { $0.name == "Filter.component" && $0.category == .audioPlugins })
    }

    func testQuickLookScannerDetectsQLAndPrefPanes() async throws {
        let qlDir = tempDir.appendingPathComponent("Markdown.qlgenerator")
        let prefDir = tempDir.appendingPathComponent("CustomSettings.prefPane")
        try FileManager.default.createDirectory(at: qlDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefDir, withIntermediateDirectories: true)

        let scanner = QuickLookScanner(searchPaths: [tempDir])
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 2)
        XCTAssertTrue(libs.contains { $0.name == "Markdown.qlgenerator" && $0.category == .quickLook })
        XCTAssertTrue(libs.contains { $0.name == "CustomSettings.prefPane" && $0.category == .quickLook })
    }
}
