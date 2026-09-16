import XCTest
@testable import MacAppCleanerKit

final class DeveloperPackageScannerTests: XCTestCase {
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

    func testHomebrewScannerDetectsMockFormula() async throws {
        // Create Cellar/wget/1.21.4
        let cellarDir = tempDir.appendingPathComponent("Cellar")
        let wgetPath = cellarDir.appendingPathComponent("wget/1.21.4")
        try FileManager.default.createDirectory(at: wgetPath, withIntermediateDirectories: true)
        try "dummy binary".data(using: .utf8)!.write(to: wgetPath.appendingPathComponent("INSTALL_RECEIPT.json"))

        let scanner = HomebrewScanner(cellarPaths: [cellarDir], runBrewCLI: false)
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 1)
        let first = libs[0]
        XCTAssertEqual(first.name, "wget")
        XCTAssertEqual(first.version, "1.21.4")
        XCTAssertEqual(first.category, .homebrew)
        XCTAssertFalse(first.isSystemProtected)
    }

    func testNodePackageScannerDetectsMockGlobalModules() async throws {
        let nodeModules = tempDir.appendingPathComponent("node_modules")
        let tsDir = nodeModules.appendingPathComponent("typescript")
        try FileManager.default.createDirectory(at: tsDir, withIntermediateDirectories: true)

        let pkgJson = """
        {
            "name": "typescript",
            "version": "5.3.3",
            "description": "TypeScript is a language for application scale JavaScript development"
        }
        """.data(using: .utf8)!
        try pkgJson.write(to: tsDir.appendingPathComponent("package.json"))

        let scanner = NodePackageScanner(searchPaths: [nodeModules])
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 1)
        let first = libs[0]
        XCTAssertEqual(first.name, "typescript")
        XCTAssertEqual(first.version, "5.3.3")
        XCTAssertEqual(first.category, .node)
        XCTAssertEqual(first.descriptionText, "TypeScript is a language for application scale JavaScript development")
    }

    func testPythonPackageScannerDetectsMockSitePackages() async throws {
        let sitePackages = tempDir.appendingPathComponent("site-packages")
        let distInfo = sitePackages.appendingPathComponent("requests-2.31.0.dist-info")
        let pkgDir = sitePackages.appendingPathComponent("requests")
        try FileManager.default.createDirectory(at: distInfo, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pkgDir, withIntermediateDirectories: true)

        let metadata = """
        Metadata-Version: 2.1
        Name: requests
        Version: 2.31.0
        Summary: Python HTTP for Humans.
        """.data(using: .utf8)!
        try metadata.write(to: distInfo.appendingPathComponent("METADATA"))

        let scanner = PythonPackageScanner(searchPaths: [sitePackages])
        let libs = await scanner.scanLibraries()

        XCTAssertEqual(libs.count, 1)
        let first = libs[0]
        XCTAssertEqual(first.name, "requests")
        XCTAssertEqual(first.version, "2.31.0")
        XCTAssertEqual(first.category, .python)
        XCTAssertEqual(first.descriptionText, "Python HTTP for Humans.")
    }
}
