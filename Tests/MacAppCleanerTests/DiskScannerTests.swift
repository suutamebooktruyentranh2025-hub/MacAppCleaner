import XCTest
@testable import MacAppCleanerKit

final class DiskScannerTests: XCTestCase {
    let fileManager = FileManager.default
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
    }

    func testScanDirectoryComputesHierarchyAndSizes() async throws {
        // Create subdirectories and dummy files
        let folderA = tempDirectory.appendingPathComponent("FolderA")
        try fileManager.createDirectory(at: folderA, withIntermediateDirectories: true)
        let dataA = Data(repeating: 0x41, count: 5000)
        try dataA.write(to: folderA.appendingPathComponent("fileA.bin"))

        let folderB = tempDirectory.appendingPathComponent("FolderB")
        try fileManager.createDirectory(at: folderB, withIntermediateDirectories: true)
        let dataB = Data(repeating: 0x42, count: 2000)
        try dataB.write(to: folderB.appendingPathComponent("fileB.bin"))

        let service = DiskScannerService()
        let result = try await service.scanDirectory(url: tempDirectory, maxDepth: 2)

        XCTAssertTrue(result.isDirectory)
        XCTAssertGreaterThanOrEqual(result.size, 7000)
        XCTAssertNotNil(result.children)
        XCTAssertEqual(result.children?.count, 2)
        // Children should be sorted descending by size
        XCTAssertEqual(result.children?.first?.name, "FolderA")
    }

    func testFindLargeFiles() async throws {
        let largeFile = tempDirectory.appendingPathComponent("large.bin")
        try Data(repeating: 0xFF, count: 1024 * 1024).write(to: largeFile) // 1MB

        let smallFile = tempDirectory.appendingPathComponent("small.txt")
        try Data("small".utf8).write(to: smallFile)

        let service = DiskScannerService()
        let largeFiles = await service.findLargeFiles(at: tempDirectory, minSizeBytes: 500 * 1024)

        XCTAssertEqual(largeFiles.count, 1)
        XCTAssertEqual(largeFiles.first?.name, "large.bin")
    }

    func testScanDirectoryIncludeHiddenFiles() async throws {
        let hiddenFolder = tempDirectory.appendingPathComponent(".hiddenFolder")
        try fileManager.createDirectory(at: hiddenFolder, withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 100).write(to: hiddenFolder.appendingPathComponent("data.bin"))

        let visibleFolder = tempDirectory.appendingPathComponent("VisibleFolder")
        try fileManager.createDirectory(at: visibleFolder, withIntermediateDirectories: true)

        let service = DiskScannerService()

        // By default, hidden files are skipped
        let defaultResult = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: false)
        XCTAssertEqual(defaultResult.children?.count, 1)
        XCTAssertEqual(defaultResult.children?.first?.name, "VisibleFolder")

        // When includeHiddenFiles is true, hidden items are returned
        let withHiddenResult = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: true)
        let names = withHiddenResult.children?.map { $0.name } ?? []
        XCTAssertTrue(names.contains(".hiddenFolder"))
        XCTAssertTrue(names.contains("VisibleFolder"))
    }

    func testFindLargeFilesInHiddenDirectories() async throws {
        let hiddenDir = tempDirectory.appendingPathComponent(".ollama/models/blobs")
        try fileManager.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        let hiddenModelFile = hiddenDir.appendingPathComponent("sha256-mockblob")
        try Data(repeating: 0xAA, count: 1024 * 1024).write(to: hiddenModelFile) // 1MB

        let service = DiskScannerService()

        // With includeHiddenFiles: true, should detect the large file in .ollama
        let found = await service.findLargeFiles(at: tempDirectory, minSizeBytes: 500 * 1024, includeHiddenFiles: true)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.name, "sha256-mockblob")

        // With includeHiddenFiles: false, should skip hidden directories
        let skipped = await service.findLargeFiles(at: tempDirectory, minSizeBytes: 500 * 1024, includeHiddenFiles: false)
        XCTAssertEqual(skipped.count, 0)
    }

    func testScanDirectoryWithHiddenCaltrashAndCalnotes() async throws {
        let caltrash = tempDirectory.appendingPathComponent(".caltrash")
        try fileManager.createDirectory(at: caltrash, withIntermediateDirectories: true)
        try Data(repeating: 0xBB, count: 5000).write(to: caltrash.appendingPathComponent("book.mobi"))

        let calnotes = tempDirectory.appendingPathComponent(".calnotes")
        try fileManager.createDirectory(at: calnotes, withIntermediateDirectories: true)
        try Data(repeating: 0xCC, count: 1000).write(to: calnotes.appendingPathComponent("notes.json"))

        let visibleFile = tempDirectory.appendingPathComponent("metadata.db")
        try Data(repeating: 0xDD, count: 2000).write(to: visibleFile)

        let service = DiskScannerService()

        // 1. When includeHiddenFiles is false: only metadata.db is shown
        let withoutHidden = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: false)
        XCTAssertEqual(withoutHidden.children?.count, 1)
        XCTAssertEqual(withoutHidden.children?.first?.name, "metadata.db")

        // 2. When includeHiddenFiles is true: .caltrash and .calnotes are shown, sorted by size descending (.caltrash 5000 > metadata.db 2000 > .calnotes 1000)
        let withHidden = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: true)
        let names = withHidden.children?.map { $0.name } ?? []
        XCTAssertTrue(names.contains(".caltrash"))
        XCTAssertTrue(names.contains(".calnotes"))
        XCTAssertTrue(names.contains("metadata.db"))
        XCTAssertEqual(withHidden.children?.first?.name, ".caltrash")

        let caltrashItem = withHidden.children?.first(where: { $0.name == ".caltrash" })
        XCTAssertTrue(caltrashItem?.isHidden == true)
        let visibleItem = withHidden.children?.first(where: { $0.name == "metadata.db" })
        XCTAssertFalse(visibleItem?.isHidden == true)
    }

    func testDiskItemIsHiddenDetectionAndCodableBackwardsCompatibility() throws {
        let visibleURL = URL(fileURLWithPath: "/Users/admin/Documents")
        let hiddenURL = URL(fileURLWithPath: "/Users/admin/.Trash")

        let visible = DiskItem(url: visibleURL, name: "Documents", isDirectory: true, size: 100)
        let hidden = DiskItem(url: hiddenURL, name: ".Trash", isDirectory: true, size: 200)

        XCTAssertFalse(visible.isHidden)
        XCTAssertTrue(hidden.isHidden)

        // Test backward-compatible JSON decoding without isHidden field
        let jsonWithoutIsHidden = """
        {
            "id": "\(UUID().uuidString)",
            "url": "file:///Users/admin/.secret",
            "name": ".secret",
            "isDirectory": false,
            "size": 50,
            "isProtected": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DiskItem.self, from: jsonWithoutIsHidden)
        XCTAssertTrue(decoded.isHidden)
        XCTAssertEqual(decoded.name, ".secret")

        // Round-trip encoding/decoding
        let encoded = try JSONEncoder().encode(hidden)
        let roundTrip = try JSONDecoder().decode(DiskItem.self, from: encoded)
        XCTAssertTrue(roundTrip.isHidden)
        XCTAssertEqual(roundTrip.name, ".Trash")
    }

    func testConcurrentDirectoryScanWithMultipleSubfoldersAndHiddenFiles() async throws {
        // Create 5 folders: 2 hidden, 3 visible
        for i in 1...3 {
            let folder = tempDirectory.appendingPathComponent("Folder_\(i)")
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(repeating: UInt8(i), count: i * 1000).write(to: folder.appendingPathComponent("data.bin"))
        }
        for i in 1...2 {
            let hiddenFolder = tempDirectory.appendingPathComponent(".hidden_\(i)")
            try fileManager.createDirectory(at: hiddenFolder, withIntermediateDirectories: true)
            try Data(repeating: 0xFF, count: i * 2000).write(to: hiddenFolder.appendingPathComponent("file.bin"))
        }

        let service = DiskScannerService()

        // 1. Without hidden
        let noHidden = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: false)
        XCTAssertEqual(noHidden.children?.count, 3)
        XCTAssertFalse(noHidden.children?.contains(where: { $0.name.hasPrefix(".") }) ?? true)

        // 2. With hidden
        let withHidden = try await service.scanDirectory(url: tempDirectory, includeHiddenFiles: true)
        XCTAssertEqual(withHidden.children?.count, 5)
        let hiddenItems = withHidden.children?.filter { $0.isHidden } ?? []
        XCTAssertEqual(hiddenItems.count, 2)
    }
}
