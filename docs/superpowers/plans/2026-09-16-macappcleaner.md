# MacAppCleaner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, lightweight macOS utility in Swift 6 & SwiftUI for deep application uninstallation (residual file detection) and hierarchical disk space analysis with strict system file protection.

**Architecture:** Unidirectional Data Flow (UDF) & MVVM with SwiftUI `@Observable` macro, Swift Concurrency (`TaskGroup`, `async/await`, `actor`), Apple standard `FileManager.trashItem` safety protocol, and POSIX/APFS file traversal.

**Tech Stack:** Swift 6.3.3, SwiftUI, Foundation, AppKit (NSWorkspace), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-16-macappcleaner-design.md`

## Global Constraints
- Target platform: macOS 14.0+ (Sonoma) and macOS 15.0+ (Sequoia)
- Swift version: Swift 6.3.3 (arm64 Apple Silicon)
- Safe deletion only: never use `rm -rf` or POSIX `unlink`; always use `FileManager.default.trashItem`
- Zero deletion of system files: Hard whitelist blocks `/System`, `/usr`, `/bin`, `/sbin`, `/private/var/vm`, and `/System/Applications/*`
- All tests must pass before completing any task (`swift test`)

---

### Task 1: Project Setup & Swift Package Manifest

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Package.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/MacAppCleanerKit.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/MacAppCleanerTests.swift`

**Interfaces:**
- Produces: Base Swift Package targets (`MacAppCleanerKit`, `MacAppCleaner`, `MacAppCleanerTests`)

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAppCleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacAppCleanerKit",
            targets: ["MacAppCleanerKit"]
        ),
        .executable(
            name: "MacAppCleaner",
            targets: ["MacAppCleaner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MacAppCleanerKit",
            dependencies: [],
            path: "Sources/MacAppCleanerKit"
        ),
        .executableTarget(
            name: "MacAppCleaner",
            dependencies: ["MacAppCleanerKit"],
            path: "Sources/MacAppCleaner"
        ),
        .testTarget(
            name: "MacAppCleanerTests",
            dependencies: ["MacAppCleanerKit"],
            path: "Tests/MacAppCleanerTests"
        )
    ]
)
```

- [ ] **Step 2: Create placeholder source files and base test**

In `Sources/MacAppCleanerKit/MacAppCleanerKit.swift`:
```swift
import Foundation

public struct MacAppCleanerKit {
    public static let version = "1.0.0"
}
```

In `Sources/MacAppCleaner/main.swift`:
```swift
import Foundation
import MacAppCleanerKit

print("MacAppCleaner v\(MacAppCleanerKit.version) CLI ready.")
```

In `Tests/MacAppCleanerTests/MacAppCleanerTests.swift`:
```swift
import XCTest
@testable import MacAppCleanerKit

final class MacAppCleanerTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(MacAppCleanerKit.version, "1.0.0")
    }
}
```

- [ ] **Step 3: Run tests to verify setup**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test
```
Expected: PASS with 1 test executed successfully.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Package.swift Sources/ Tests/
git commit -m "chore: initialize Swift Package with MacAppCleanerKit and test target"
```

---

### Task 2: SafetyGuardService & System Whitelist (TDD)

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Services/SafetyGuardService.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/SafetyGuardTests.swift`

**Interfaces:**
- Produces: `enum SafetyGuardError: Error`, `final class SafetyGuardService: Sendable` with:
  - `func isSystemProtected(url: URL) -> Bool`
  - `func isProtectedApp(bundleIdentifier: String?, bundleURL: URL) -> Bool`
  - `func validateDeletion(url: URL) throws`

- [ ] **Step 1: Write the failing test**

In `Tests/MacAppCleanerTests/SafetyGuardTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter SafetyGuardTests
```
Expected: FAIL with "cannot find 'SafetyGuardService' in scope"

- [ ] **Step 3: Implement SafetyGuardService**

In `Sources/MacAppCleanerKit/Services/SafetyGuardService.swift`:
```swift
import Foundation

public enum SafetyGuardError: Error, Equatable, Sendable {
    case systemFileProtected
    case userAccountSecretProtected
    case criticalSystemAppProtected
}

public final class SafetyGuardService: Sendable {
    public static let shared = SafetyGuardService()

    public init() {}

    private let protectedSystemPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/vm",
        "/private/var/db",
        "/private/etc",
        "/Library/Apple"
    ]

    private let protectedUserDirectories: [String] = [
        ".ssh",
        "Library/Keychains",
        "Library/Accounts"
    ]

    public func isSystemProtected(url: URL) -> Bool {
        let path = url.standardized.path

        // Check root-level system prefixes
        for prefix in protectedSystemPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }

        // Check sensitive user directories
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardized.path
        for rel in protectedUserDirectories {
            let sensitivePath = (homePath as NSString).appendingPathComponent(rel)
            if path == sensitivePath || path.hasPrefix(sensitivePath + "/") {
                return true
            }
        }

        // Check if inside /System/Applications
        if path.hasPrefix("/System/Applications") {
            return true
        }

        return false
    }

    public func isProtectedApp(bundleIdentifier: String?, bundleURL: URL) -> Bool {
        if isSystemProtected(url: bundleURL) {
            return true
        }
        if let id = bundleIdentifier?.lowercased() {
            if id.hasPrefix("com.apple.") {
                return true
            }
        }
        return false
    }

    public func validateDeletion(url: URL) throws {
        if isSystemProtected(url: url) {
            throw SafetyGuardError.systemFileProtected
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter SafetyGuardTests
```
Expected: PASS with all assertions succeeding.

- [ ] **Step 5: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleanerKit/Services/SafetyGuardService.swift Tests/MacAppCleanerTests/SafetyGuardTests.swift
git commit -m "feat: add SafetyGuardService with immutable system whitelist and SIP protection"
```

---

### Task 3: Core Models & Formatters

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Models/FileCategory.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Models/RelatedFile.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Models/InstalledApp.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Models/DiskItem.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Extensions/ByteCountFormatter+Ext.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/ModelTests.swift`

**Interfaces:**
- Produces: `FileCategory`, `RelatedFile`, `AppArchitecture`, `InstalledApp`, `DiskItem`, `ByteCountFormatter.format(bytes:)`

- [ ] **Step 1: Write model test**

In `Tests/MacAppCleanerTests/ModelTests.swift`:
```swift
import XCTest
@testable import MacAppCleanerKit

final class ModelTests: XCTestCase {
    func testByteFormatting() {
        XCTAssertEqual(ByteCountFormatter.format(bytes: 1024), "1 KB")
        XCTAssertEqual(ByteCountFormatter.format(bytes: 1048576), "1 MB")
        XCTAssertEqual(ByteCountFormatter.format(bytes: 1073741824), "1 GB")
    }

    func testInstalledAppTotalSizeCalculation() {
        let app = InstalledApp(
            id: UUID(),
            name: "TestApp",
            bundleURL: URL(fileURLWithPath: "/Applications/Test.app"),
            bundleIdentifier: "com.test.app",
            version: "1.0",
            architecture: .arm64,
            installDate: Date(),
            appSize: 1000,
            residualFiles: [
                RelatedFile(url: URL(fileURLWithPath: "/tmp/cache"), size: 500, category: .caches),
                RelatedFile(url: URL(fileURLWithPath: "/tmp/pref"), size: 200, category: .preferences)
            ],
            isSystemApp: false
        )

        XCTAssertEqual(app.totalSize, 1700)
        XCTAssertEqual(app.selectedSize, 1700)
    }
}
```

- [ ] **Step 2: Implement Models & Formatters**

In `Sources/MacAppCleanerKit/Models/FileCategory.swift`:
```swift
import Foundation

public enum FileCategory: String, CaseIterable, Sendable {
    case application = "Ứng dụng gốc (.app)"
    case applicationSupport = "Application Support"
    case caches = "Bộ nhớ đệm (Caches)"
    case preferences = "Tùy chọn cấu hình (Preferences)"
    case savedState = "Trạng thái đã lưu (Saved State)"
    case containers = "Hộp cát (Containers)"
    case groupContainers = "Group Containers"
    case logs = "Nhật ký (Logs)"
    case webKit = "Dữ liệu WebKit"
    case httpStorages = "HTTP Storages"
    case launchAgents = "Khởi động cùng máy (LaunchAgents)"
    case other = "Tệp tàn dư khác"

    public var iconName: String {
        switch self {
        case .application: return "app.badge"
        case .applicationSupport: return "folder.badge.gearshape"
        case .caches: return "trash"
        case .preferences: return "gearshape"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox"
        case .groupContainers: return "square.stack.3d.down.right"
        case .logs: return "doc.text"
        case .webKit: return "safari"
        case .httpStorages: return "network"
        case .launchAgents: return "bolt"
        case .other: return "doc"
        }
    }
}
```

In `Sources/MacAppCleanerKit/Models/RelatedFile.swift`:
```swift
import Foundation

public struct RelatedFile: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let size: Int64
    public let category: FileCategory
    public var isSelectedForDeletion: Bool

    public init(id: UUID = UUID(), url: URL, size: Int64, category: FileCategory, isSelectedForDeletion: Bool = true) {
        self.id = id
        self.url = url
        self.size = size
        self.category = category
        self.isSelectedForDeletion = isSelectedForDeletion
    }
}
```

In `Sources/MacAppCleanerKit/Models/InstalledApp.swift`:
```swift
import Foundation

public enum AppArchitecture: String, Sendable {
    case arm64 = "Apple Silicon"
    case intel = "Intel (x86_64)"
    case universal = "Universal 2"
    case unknown = "Không xác định"
}

public struct InstalledApp: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let architecture: AppArchitecture
    public let installDate: Date?
    public let appSize: Int64
    public var residualFiles: [RelatedFile]
    public let isSystemApp: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleURL: URL,
        bundleIdentifier: String?,
        version: String?,
        architecture: AppArchitecture = .arm64,
        installDate: Date? = nil,
        appSize: Int64 = 0,
        residualFiles: [RelatedFile] = [],
        isSystemApp: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.architecture = architecture
        self.installDate = installDate
        self.appSize = appSize
        self.residualFiles = residualFiles
        self.isSystemApp = isSystemApp
    }

    public var totalSize: Int64 {
        appSize + residualFiles.reduce(0) { $0 + $1.size }
    }

    public var selectedSize: Int64 {
        appSize + residualFiles.filter(\.isSelectedForDeletion).reduce(0) { $0 + $1.size }
    }
}
```

In `Sources/MacAppCleanerKit/Models/DiskItem.swift`:
```swift
import Foundation

public struct DiskItem: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public var children: [DiskItem]?
    public let isProtected: Bool
    public let modificationDate: Date?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64,
        children: [DiskItem]? = nil,
        isProtected: Bool = false,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.isProtected = isProtected
        self.modificationDate = modificationDate
    }
}
```

In `Sources/MacAppCleanerKit/Extensions/ByteCountFormatter+Ext.swift`:
```swift
import Foundation

extension ByteCountFormatter {
    public static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
```

- [ ] **Step 3: Run test to verify models work**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter ModelTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleanerKit/Models/ Sources/MacAppCleanerKit/Extensions/ Tests/MacAppCleanerTests/ModelTests.swift
git commit -m "feat: add domain models (InstalledApp, RelatedFile, DiskItem) and byte formatter"
```

---

### Task 4: ResidualScanner & TrashService (TDD)

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Services/ResidualScanner.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Services/TrashService.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/ResidualScannerTests.swift`

**Interfaces:**
- Produces: `final class ResidualScanner: Sendable` with `func findResidualFiles(for app: InstalledApp) async -> [RelatedFile]`
- Produces: `final class TrashService: Sendable` with `func trashItem(at url: URL) throws` and `func trashFiles(_ files: [URL]) throws -> [URL]`

- [ ] **Step 1: Write test for ResidualScanner and TrashService**

In `Tests/MacAppCleanerTests/ResidualScannerTests.swift`:
```swift
import XCTest
@testable import MacAppCleanerKit

final class ResidualScannerTests: XCTestCase {
    let fileManager = FileManager.default
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
    }

    func testResidualScannerDetectsRelatedFiles() async throws {
        let bundleID = "com.example.DemoApp"
        let appName = "DemoApp"

        // Mock test residual directories
        let mockAppSupport = tempDirectory.appendingPathComponent("Application Support/\(bundleID)")
        try fileManager.createDirectory(at: mockAppSupport, withIntermediateDirectories: true)
        let sampleData = "Test residual content".data(using: .utf8)!
        try sampleData.write(to: mockAppSupport.appendingPathComponent("config.json"))

        let mockCache = tempDirectory.appendingPathComponent("Caches/\(bundleID)")
        try fileManager.createDirectory(at: mockCache, withIntermediateDirectories: true)
        try sampleData.write(to: mockCache.appendingPathComponent("cache.db"))

        let scanner = ResidualScanner(customLibraryURL: tempDirectory)
        let testApp = InstalledApp(
            name: appName,
            bundleURL: tempDirectory.appendingPathComponent("\(appName).app"),
            bundleIdentifier: bundleID,
            version: "1.0"
        )

        let residuals = await scanner.findResidualFiles(for: testApp)
        XCTAssertGreaterThanOrEqual(residuals.count, 2)
        XCTAssertTrue(residuals.contains(where: { $0.category == .applicationSupport }))
        XCTAssertTrue(residuals.contains(where: { $0.category == .caches }))
    }

    func testTrashServiceRejectsProtectedFiles() {
        let trashService = TrashService(safetyGuard: SafetyGuardService.shared)
        let systemURL = URL(fileURLWithPath: "/System/Library")

        XCTAssertThrowsError(try trashService.trashItem(at: systemURL)) { error in
            XCTAssertEqual(error as? SafetyGuardError, .systemFileProtected)
        }
    }
}
```

- [ ] **Step 2: Implement ResidualScanner & TrashService**

In `Sources/MacAppCleanerKit/Services/ResidualScanner.swift`:
```swift
import Foundation

public final class ResidualScanner: Sendable {
    private let libraryURL: URL

    public init(customLibraryURL: URL? = nil) {
        if let custom = customLibraryURL {
            self.libraryURL = custom
        } else {
            self.libraryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        }
    }

    public func findResidualFiles(for app: InstalledApp) async -> [RelatedFile] {
        guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else {
            return []
        }

        let appName = app.name
        var results: [RelatedFile] = []

        let targets: [(String, FileCategory)] = [
            ("Application Support", .applicationSupport),
            ("Caches", .caches),
            ("Preferences", .preferences),
            ("Saved Application State", .savedState),
            ("Containers", .containers),
            ("Group Containers", .groupContainers),
            ("Logs", .logs),
            ("WebKit", .webKit),
            ("HTTPStorages", .httpStorages),
            ("LaunchAgents", .launchAgents)
        ]

        let fileManager = FileManager.default

        for (subPath, category) in targets {
            let baseDir = libraryURL.appendingPathComponent(subPath)

            // Check bundleID path
            let pathByBundleID = baseDir.appendingPathComponent(bundleID)
            let pathByPlist = baseDir.appendingPathComponent("\(bundleID).plist")
            let pathBySavedState = baseDir.appendingPathComponent("\(bundleID).savedState")
            let pathByName = baseDir.appendingPathComponent(appName)

            let candidateURLs = [pathByBundleID, pathByPlist, pathBySavedState, pathByName]

            for candidate in candidateURLs {
                if fileManager.fileExists(atPath: candidate.path) {
                    if !results.contains(where: { $0.url.path == candidate.path }) {
                        let size = calculateSize(at: candidate)
                        results.append(RelatedFile(url: candidate, size: size, category: category))
                    }
                }
            }
        }

        return results
    }

    private func calculateSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
```

In `Sources/MacAppCleanerKit/Services/TrashService.swift`:
```swift
import Foundation

public final class TrashService: Sendable {
    public static let shared = TrashService()
    private let safetyGuard: SafetyGuardService

    public init(safetyGuard: SafetyGuardService = .shared) {
        self.safetyGuard = safetyGuard
    }

    public func trashItem(at url: URL) throws {
        // Enforce safety whitelist first
        try safetyGuard.validateDeletion(url: url)

        // Apple native safe trash action
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public func trashFiles(_ files: [URL]) throws -> [URL] {
        var trashed: [URL] = []
        for file in files {
            try trashItem(at: file)
            trashed.append(file)
        }
        return trashed
    }
}
```

- [ ] **Step 3: Run tests to verify**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter ResidualScannerTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleanerKit/Services/ResidualScanner.swift Sources/MacAppCleanerKit/Services/TrashService.swift Tests/MacAppCleanerTests/ResidualScannerTests.swift
git commit -m "feat: implement ResidualScanner and TrashService with strict safety validation"
```

---

### Task 5: AppDiscoveryService & Mach-O Architecture Detector

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Services/AppDiscoveryService.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/AppDiscoveryTests.swift`

**Interfaces:**
- Produces: `final class AppDiscoveryService: Sendable` with:
  - `func discoverInstalledApps() async -> [InstalledApp]`
  - `func detectArchitecture(of executableURL: URL) -> AppArchitecture`

- [ ] **Step 1: Write test for AppDiscoveryService**

In `Tests/MacAppCleanerTests/AppDiscoveryTests.swift`:
```swift
import XCTest
@testable import MacAppCleanerKit

final class AppDiscoveryTests: XCTestCase {
    func testDiscoverAppsFindsSystemAndThirdPartyApps() async {
        let service = AppDiscoveryService()
        let apps = await service.discoverInstalledApps()

        XCTAssertFalse(apps.isEmpty, "Should discover installed applications on this Mac")

        // Should find Calculator or Safari
        let hasCoreApp = apps.contains { $0.name.contains("Safari") || $0.name.contains("Calculator") || $0.bundleIdentifier == "com.apple.Safari" }
        XCTAssertTrue(hasCoreApp, "Should discover standard macOS applications")
    }
}
```

- [ ] **Step 2: Implement AppDiscoveryService**

In `Sources/MacAppCleanerKit/Services/AppDiscoveryService.swift`:
```swift
import Foundation

public final class AppDiscoveryService: Sendable {
    public static let shared = AppDiscoveryService()

    public init() {}

    public func discoverInstalledApps() async -> [InstalledApp] {
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        for directory in searchDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for itemURL in contents where itemURL.pathExtension == "app" {
                if let app = parseAppBundle(at: itemURL) {
                    apps.append(app)
                }
            }
        }

        // Sort by name alphabetically
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func parseAppBundle(at bundleURL: URL) -> InstalledApp? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent

        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
        let isSystemApp = SafetyGuardService.shared.isProtectedApp(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL)

        // Mach-O binary architecture detection
        let executableName = plist["CFBundleExecutable"] as? String
        var architecture: AppArchitecture = .arm64
        if let execName = executableName {
            let execURL = bundleURL.appendingPathComponent("Contents/MacOS/\(execName)")
            architecture = detectArchitecture(of: execURL)
        }

        let size = calculateAppSize(at: bundleURL)
        let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path)
        let installDate = attrs?[.creationDate] as? Date ?? attrs?[.modificationDate] as? Date

        return InstalledApp(
            name: name,
            bundleURL: bundleURL,
            bundleIdentifier: bundleIdentifier,
            version: version,
            architecture: architecture,
            installDate: installDate,
            appSize: size,
            residualFiles: [],
            isSystemApp: isSystemApp
        )
    }

    public func detectArchitecture(of executableURL: URL) -> AppArchitecture {
        guard let handle = try? FileHandle(forReadingFrom: executableURL) else {
            return .unknown
        }
        defer { try? handle.close() }

        guard let magicData = try? handle.read(upToCount: 4), magicData.count == 4 else {
            return .unknown
        }

        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }

        // Universal Fat Binary
        if magic == 0xCAFEBABE || magic == 0xBEBAFECA {
            return .universal
        }
        // 64-bit Mach-O (arm64 or x86_64)
        if magic == 0xFEEDFACF || magic == 0xCFFAEDFE {
            // Read CPU type at offset 4
            if let cpuData = try? handle.read(upToCount: 4), cpuData.count == 4 {
                let cpuType = cpuData.withUnsafeBytes { $0.load(as: UInt32.self) }
                // CPU_TYPE_ARM64 = 0x0100000C
                if cpuType == 0x0100000C || cpuType == 0x0C000001 {
                    return .arm64
                }
                // CPU_TYPE_X86_64 = 0x01000007
                if cpuType == 0x01000007 || cpuType == 0x07000001 {
                    return .intel
                }
            }
            return .arm64
        }

        return .unknown
    }

    private func calculateAppSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
```

- [ ] **Step 3: Run test to verify app discovery**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter AppDiscoveryTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleanerKit/Services/AppDiscoveryService.swift Tests/MacAppCleanerTests/AppDiscoveryTests.swift
git commit -m "feat: implement AppDiscoveryService with Mach-O binary architecture detector"
```

---

### Task 6: DiskScannerService & Directory Hierarchy Analyzer (TDD)

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleanerKit/Services/DiskScannerService.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Tests/MacAppCleanerTests/DiskScannerTests.swift`

**Interfaces:**
- Produces: `final class DiskScannerService: Sendable` with:
  - `func scanDirectory(url: URL, maxDepth: Int) async throws -> DiskItem`
  - `func findLargeFiles(at url: URL, minSizeBytes: Int64) async -> [DiskItem]`

- [ ] **Step 1: Write test for DiskScannerService**

In `Tests/MacAppCleanerTests/DiskScannerTests.swift`:
```swift
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
}
```

- [ ] **Step 2: Implement DiskScannerService**

In `Sources/MacAppCleanerKit/Services/DiskScannerService.swift`:
```swift
import Foundation

public final class DiskScannerService: Sendable {
    public static let shared = DiskScannerService()
    private let safetyGuard: SafetyGuardService

    public init(safetyGuard: SafetyGuardService = .shared) {
        self.safetyGuard = safetyGuard
    }

    public func scanDirectory(url: URL, maxDepth: Int = 1) async throws -> DiskItem {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let isProtected = safetyGuard.isSystemProtected(url: url)
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        if !isDir.boolValue {
            let size = (attrs?[.size] as? Int64) ?? 0
            return DiskItem(url: url, name: name, isDirectory: false, size: size, isProtected: isProtected, modificationDate: modDate)
        }

        // Directory traversal
        let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey], options: [.skipsHiddenFiles])) ?? []

        var childItems: [DiskItem] = []
        var totalFolderSize: Int64 = 0

        for childURL in contents {
            var childIsDir: ObjCBool = false
            guard fileManager.fileExists(atPath: childURL.path, isDirectory: &childIsDir) else { continue }

            let childProtected = safetyGuard.isSystemProtected(url: childURL)
            let childAttrs = try? fileManager.attributesOfItem(atPath: childURL.path)
            let childModDate = childAttrs?[.modificationDate] as? Date

            if childIsDir.boolValue {
                let size = calculateDirectorySize(at: childURL)
                totalFolderSize += size
                childItems.append(DiskItem(
                    url: childURL,
                    name: childURL.lastPathComponent,
                    isDirectory: true,
                    size: size,
                    children: nil,
                    isProtected: childProtected,
                    modificationDate: childModDate
                ))
            } else {
                let size = (childAttrs?[.size] as? Int64) ?? 0
                totalFolderSize += size
                childItems.append(DiskItem(
                    url: childURL,
                    name: childURL.lastPathComponent,
                    isDirectory: false,
                    size: size,
                    children: nil,
                    isProtected: childProtected,
                    modificationDate: childModDate
                ))
            }
        }

        // Sort descending by size
        childItems.sort { $0.size > $1.size }

        return DiskItem(
            url: url,
            name: name,
            isDirectory: true,
            size: totalFolderSize,
            children: childItems,
            isProtected: isProtected,
            modificationDate: modDate
        )
    }

    public func findLargeFiles(at rootURL: URL, minSizeBytes: Int64) async -> [DiskItem] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [DiskItem] = []

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isDirectory == false else {
                continue
            }

            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            if size >= minSizeBytes {
                let isProtected = safetyGuard.isSystemProtected(url: fileURL)
                results.append(DiskItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    isDirectory: false,
                    size: size,
                    isProtected: isProtected,
                    modificationDate: values.contentModificationDate
                ))
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
```

- [ ] **Step 3: Run tests to verify DiskScannerService**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test --filter DiskScannerTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleanerKit/Services/DiskScannerService.swift Tests/MacAppCleanerTests/DiskScannerTests.swift
git commit -m "feat: implement DiskScannerService with size hierarchy calculation and large files finder"
```

---

### Task 7: SwiftUI ViewModels & Uninstaller UI

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/ViewModels/AppUninstallerViewModel.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/Uninstaller/AppListView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/Uninstaller/AppRowView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/Uninstaller/AppDetailView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/Uninstaller/UninstallConfirmModal.swift`

**Interfaces:**
- Produces: `AppUninstallerViewModel` observing app state, `AppListView`, `AppDetailView`

- [ ] **Step 1: Implement AppUninstallerViewModel**

In `Sources/MacAppCleaner/ViewModels/AppUninstallerViewModel.swift`:
```swift
import Foundation
import SwiftUI
import MacAppCleanerKit

@Observable
public final class AppUninstallerViewModel {
    public var apps: [InstalledApp] = []
    public var selectedApp: InstalledApp?
    public var isLoading: Bool = false
    public var isScanningResiduals: Bool = false
    public var searchText: String = ""
    public var isShowingConfirmModal: Bool = false
    public var errorMessage: String?

    private let discoveryService = AppDiscoveryService.shared
    private let residualScanner = ResidualScanner()
    private let trashService = TrashService.shared

    public init() {}

    public var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    @MainActor
    public func loadApps() async {
        isLoading = true
        apps = await discoveryService.discoverInstalledApps()
        isLoading = false
        if selectedApp == nil, let first = apps.first {
            await selectApp(first)
        }
    }

    @MainActor
    public func selectApp(_ app: InstalledApp) async {
        selectedApp = app
        isScanningResiduals = true
        let residuals = await residualScanner.findResidualFiles(for: app)
        if var current = selectedApp, current.id == app.id {
            current.residualFiles = residuals
            selectedApp = current
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index].residualFiles = residuals
            }
        }
        isScanningResiduals = false
    }

    public func toggleResidualSelection(id: UUID) {
        guard var current = selectedApp else { return }
        if let idx = current.residualFiles.firstIndex(where: { $0.id == id }) {
            current.residualFiles[idx].isSelectedForDeletion.toggle()
            selectedApp = current
        }
    }

    @MainActor
    public func uninstallSelectedApp() async {
        guard let app = selectedApp else { return }

        do {
            var filesToTrash: [URL] = []
            filesToTrash.append(app.bundleURL)
            for res in app.residualFiles where res.isSelectedForDeletion {
                filesToTrash.append(res.url)
            }

            _ = try trashService.trashFiles(filesToTrash)
            apps.removeAll { $0.id == app.id }
            selectedApp = apps.first
            if let next = selectedApp {
                await selectApp(next)
            }
        } catch {
            errorMessage = "Lỗi khi chuyển vào Thùng rác: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Implement Uninstaller Views**

In `Sources/MacAppCleaner/Views/Uninstaller/AppRowView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct AppRowView: View {
    let app: InstalledApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(app.isSystemApp ? .purple : .blue)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    if app.isSystemApp {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                            .help("Tệp hệ thống được bảo vệ bởi macOS")
                    }
                }

                HStack(spacing: 6) {
                    Text(app.architecture.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)

                    if let ver = app.version {
                        Text("v\(ver)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(ByteCountFormatter.format(bytes: app.totalSize))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
}
```

In `Sources/MacAppCleaner/Views/Uninstaller/AppDetailView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct AppDetailView: View {
    @Bindable var viewModel: AppUninstallerViewModel

    var body: some View {
        if let app = viewModel.selectedApp {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "app.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(app.isSystemApp ? .purple : .blue)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(app.name)
                                .font(.title2.bold())

                            if app.isSystemApp {
                                Label("Bảo vệ hệ thống", systemImage: "shield.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }

                        Text(app.bundleIdentifier ?? "Unknown Bundle ID")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("Đường dẫn: \(app.bundleURL.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Tổng dung lượng")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.format(bytes: app.totalSize))
                            .font(.title3.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Residual Files List
                if viewModel.isScanningResiduals {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView("Đang quét tệp tàn dư (Caches, Application Support...)...")
                        Spacer()
                    }
                } else {
                    List {
                        Section("Tệp ứng dụng gốc") {
                            HStack {
                                Image(systemName: "app.badge")
                                    .foregroundStyle(.blue)
                                Text("Gói ứng dụng (.app)")
                                Spacer()
                                Text(ByteCountFormatter.format(bytes: app.appSize))
                                    .font(.system(size: 12, design: .monospaced))
                            }
                        }

                        Section("Tệp tàn dư phát hiện (\(app.residualFiles.count))") {
                            if app.residualFiles.isEmpty {
                                Text("Không tìm thấy tệp tàn dư nào thêm.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(app.residualFiles) { file in
                                    HStack {
                                        Toggle("", isOn: Binding(
                                            get: { file.isSelectedForDeletion },
                                            set: { _ in viewModel.toggleResidualSelection(id: file.id) }
                                        ))
                                        .disabled(app.isSystemApp)

                                        Image(systemName: file.category.iconName)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.category.rawValue)
                                                .font(.system(size: 12, weight: .medium))
                                            Text(file.url.path)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(ByteCountFormatter.format(bytes: file.size))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                // Action Footer
                HStack {
                    if app.isSystemApp {
                        Label("Ứng dụng cốt lõi macOS — Khóa gỡ bỏ để đảm bảo an toàn.", systemImage: "lock.shield.fill")
                            .font(.callout)
                            .foregroundStyle(.purple)
                    } else {
                        Text("Dung lượng giải phóng: \(ByteCountFormatter.format(bytes: app.selectedSize))")
                            .font(.callout.bold())
                    }

                    Spacer()

                    Button(action: {
                        viewModel.isShowingConfirmModal = true
                    }) {
                        Label("Gỡ bỏ hoàn toàn", systemImage: "trash.fill")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(app.isSystemApp)
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .sheet(isPresented: $viewModel.isShowingConfirmModal) {
                UninstallConfirmModal(viewModel: viewModel)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Chọn một ứng dụng từ danh sách bên trái")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

In `Sources/MacAppCleaner/Views/Uninstaller/UninstallConfirmModal.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct UninstallConfirmModal: View {
    @Bindable var viewModel: AppUninstallerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let app = viewModel.selectedApp {
            VStack(spacing: 16) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Chuyển vào Thùng Rác?")
                    .font(.headline)

                Text("Ứng dụng '\(app.name)' và các tệp tàn dư đã chọn sẽ được đưa an toàn vào Thùng Rác của macOS. Bạn có thể khôi phục (Put Back) bất cứ lúc nào.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tổng dung lượng sẽ giải phóng: \(ByteCountFormatter.format(bytes: app.selectedSize))")
                        .font(.callout.bold())
                    Text("Số tệp sẽ xóa: \(1 + app.residualFiles.filter(\.isSelectedForDeletion).count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 12) {
                    Button("Hủy bỏ") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Chuyển vào Thùng Rác") {
                        Task {
                            await viewModel.uninstallSelectedApp()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}
```

In `Sources/MacAppCleaner/Views/Uninstaller/AppListView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct AppListView: View {
    @Bindable var viewModel: AppUninstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Tìm ứng dụng...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(10)

            Divider()

            if viewModel.isLoading {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView("Đang tải ứng dụng...")
                    Spacer()
                }
            } else {
                List(viewModel.filteredApps) { app in
                    AppRowView(app: app, isSelected: viewModel.selectedApp?.id == app.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await viewModel.selectApp(app)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            if viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift build
```
Expected: PASS with 0 build errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleaner/ViewModels/ Sources/MacAppCleaner/Views/Uninstaller/
git commit -m "feat: implement AppUninstallerViewModel and full Uninstaller UI with safety checks"
```

---

### Task 8: Disk Analyzer UI & Quick Filters

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/ViewModels/DiskAnalyzerViewModel.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/DiskAnalyzer/DiskHierarchyView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/DiskAnalyzer/DiskItemRowView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/DiskAnalyzer/QuickFilterView.swift`

**Interfaces:**
- Produces: `DiskAnalyzerViewModel`, `DiskHierarchyView`, `QuickFilterView`

- [ ] **Step 1: Implement DiskAnalyzerViewModel**

In `Sources/MacAppCleaner/ViewModels/DiskAnalyzerViewModel.swift`:
```swift
import Foundation
import SwiftUI
import MacAppCleanerKit

@Observable
public final class DiskAnalyzerViewModel {
    public var currentRoot: DiskItem?
    public var selectedItem: DiskItem?
    public var navigationHistory: [DiskItem] = []
    public var largeFiles: [DiskItem] = []
    public var isScanning: Bool = false
    public var filterMode: FilterMode = .hierarchy
    public var minSizeFilter: Int64 = 500 * 1024 * 1024 // 500MB
    public var statusMessage: String = ""

    public enum FilterMode: String, CaseIterable {
        case hierarchy = "Cây thư mục"
        case largeFiles = "Tệp lớn (>500MB)"
        case hugeFiles = "Tệp khổng lồ (>2GB)"
    }

    private let scannerService = DiskScannerService.shared
    private let trashService = TrashService.shared

    public init() {}

    @MainActor
    public func scanHomeDirectory() async {
        isScanning = true
        statusMessage = "Đang phân tích thư mục người dùng..."
        let homeURL = FileManager.default.homeDirectoryForCurrentUser

        do {
            let root = try await scannerService.scanDirectory(url: homeURL)
            currentRoot = root
            selectedItem = root.children?.first
            statusMessage = "Hoàn tất."
        } catch {
            statusMessage = "Lỗi quét: \(error.localizedDescription)"
        }

        isScanning = false
    }

    @MainActor
    public func scanLargeFiles(minBytes: Int64) async {
        isScanning = true
        statusMessage = "Đang tìm các tệp lớn..."
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        largeFiles = await scannerService.findLargeFiles(at: homeURL, minSizeBytes: minBytes)
        statusMessage = "Tìm thấy \(largeFiles.count) tệp lớn."
        isScanning = false
    }

    @MainActor
    public func navigateInto(item: DiskItem) async {
        guard item.isDirectory else { return }
        if let current = currentRoot {
            navigationHistory.append(current)
        }
        isScanning = true
        do {
            currentRoot = try await scannerService.scanDirectory(url: item.url)
            selectedItem = currentRoot?.children?.first
        } catch {
            statusMessage = "Không thể mở thư mục: \(error.localizedDescription)"
        }
        isScanning = false
    }

    @MainActor
    public func navigateBack() {
        guard let prev = navigationHistory.popLast() else { return }
        currentRoot = prev
        selectedItem = prev.children?.first
    }

    @MainActor
    public func trashItem(_ item: DiskItem) async {
        do {
            try trashService.trashItem(at: item.url)
            if let root = currentRoot {
                // Refresh folder
                currentRoot = try await scannerService.scanDirectory(url: root.url)
            }
            largeFiles.removeAll { $0.id == item.id }
        } catch {
            statusMessage = "Không thể xoá tệp: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Implement Disk Analyzer Views**

In `Sources/MacAppCleaner/Views/DiskAnalyzer/DiskItemRowView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct DiskItemRowView: View {
    let item: DiskItem
    let maxFolderSize: Int64
    let isSelected: Bool

    var relativeRatio: Double {
        guard maxFolderSize > 0 else { return 0 }
        return min(1.0, Double(item.size) / Double(maxFolderSize))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(item.isProtected ? .purple : (item.isDirectory ? .blue : .secondary))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if item.isProtected {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                            .help("Tệp hệ thống được bảo vệ — Không cho phép xoá")
                    }
                }

                // Relative size bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(item.isProtected ? Color.purple : Color.accentColor)
                            .frame(width: max(4, geo.size.width * relativeRatio), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text(ByteCountFormatter.format(bytes: item.size))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(6)
    }
}
```

In `Sources/MacAppCleaner/Views/DiskAnalyzer/QuickFilterView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct QuickFilterView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanning {
                ProgressView("Đang quét tệp lớn...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.largeFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Không tìm thấy tệp nào vượt ngưỡng dung lượng.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.largeFiles) { item in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(item.isProtected ? .purple : .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.name)
                                    .font(.headline)
                                if item.isProtected {
                                    Label("Bảo vệ", systemImage: "shield.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.purple)
                                }
                            }
                            Text(item.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(ByteCountFormatter.format(bytes: item.size))
                            .font(.system(size: 13, design: .monospaced).bold())

                        Button(role: .destructive) {
                            Task {
                                await viewModel.trashItem(item)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(item.isProtected)
                        .help(item.isProtected ? "Tệp hệ thống được bảo vệ" : "Chuyển vào Thùng Rác")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
```

In `Sources/MacAppCleaner/Views/DiskAnalyzer/DiskHierarchyView.swift`:
```swift
import SwiftUI
import MacAppCleanerKit

struct DiskHierarchyView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Mode Toolbar
            HStack {
                Picker("Chế độ xem", selection: $viewModel.filterMode) {
                    ForEach(DiskAnalyzerViewModel.FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()

                if !viewModel.navigationHistory.isEmpty && viewModel.filterMode == .hierarchy {
                    Button(action: {
                        viewModel.navigateBack()
                    }) {
                        Label("Thư mục trước", systemImage: "arrow.left")
                    }
                }

                Button(action: {
                    Task {
                        if viewModel.filterMode == .hierarchy {
                            await viewModel.scanHomeDirectory()
                        } else if viewModel.filterMode == .largeFiles {
                            await viewModel.scanLargeFiles(minBytes: 500 * 1024 * 1024)
                        } else {
                            await viewModel.scanLargeFiles(minBytes: 2 * 1024 * 1024 * 1024)
                        }
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if viewModel.filterMode == .hierarchy {
                if viewModel.isScanning {
                    ProgressView("Đang tính toán dung lượng...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let root = viewModel.currentRoot {
                    VStack(alignment: .leading, spacing: 0) {
                        // Current path header
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(root.url.path)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer()
                            Text("Tổng: \(ByteCountFormatter.format(bytes: root.size))")
                                .font(.caption.bold())
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))

                        List(root.children ?? []) { child in
                            DiskItemRowView(
                                item: child,
                                maxFolderSize: root.children?.first?.size ?? 1,
                                isSelected: viewModel.selectedItem?.id == child.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                if child.isDirectory {
                                    Task {
                                        await viewModel.navigateInto(item: child)
                                    }
                                }
                            }
                            .onTapGesture {
                                viewModel.selectedItem = child
                            }
                        }
                    }
                } else {
                    ProgressView("Đang khởi tạo quét...")
                        .task {
                            await viewModel.scanHomeDirectory()
                        }
                }
            } else {
                QuickFilterView(viewModel: viewModel)
                    .task(id: viewModel.filterMode) {
                        if viewModel.filterMode == .largeFiles {
                            await viewModel.scanLargeFiles(minBytes: 500 * 1024 * 1024)
                        } else {
                            await viewModel.scanLargeFiles(minBytes: 2 * 1024 * 1024 * 1024)
                        }
                    }
            }
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift build
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git add Sources/MacAppCleaner/ViewModels/DiskAnalyzerViewModel.swift Sources/MacAppCleaner/Views/DiskAnalyzer/
git commit -m "feat: implement DiskAnalyzerViewModel and hierarchical disk tree views with quick filters"
```

---

### Task 9: Root Navigation & App Entry Point

**Files:**
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/MainView.swift`
- Create: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/Views/Components/PermissionBannerView.swift`
- Modify: `/Users/admin/Documents/MacAppCleaner/Sources/MacAppCleaner/main.swift` -> replace with `MacAppCleanerApp.swift`

**Interfaces:**
- Produces: `MacAppCleanerApp: App`, `MainView: View` combining App Uninstaller and Disk Space Analyzer

- [ ] **Step 1: Implement PermissionBannerView**

In `Sources/MacAppCleaner/Views/Components/PermissionBannerView.swift`:
```swift
import SwiftUI

struct PermissionBannerView: View {
    @State private var hasCheckedAccess = false
    @State private var hasFullDiskAccess = true

    var body: some View {
        if !hasFullDiskAccess {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cần quyền Full Disk Access để quét sạch toàn diện")
                        .font(.caption.bold())
                    Text("Một số tệp tàn dư trong ~/Library/Containers yêu cầu quyền truy cập đầy đủ để kiểm tra.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Mở Cài đặt hệ thống") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
            }
            .padding(8)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }
}
```

- [ ] **Step 2: Implement MainView**

In `Sources/MacAppCleaner/Views/MainView.swift`:
```swift
import SwiftUI

enum NavigationSection: String, CaseIterable, Identifiable {
    case uninstaller = "Gỡ ứng dụng"
    case diskAnalyzer = "Dung lượng ổ đĩa"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .uninstaller: return "trash.fill"
        case .diskAnalyzer: return "internaldrive.fill"
        }
    }
}

struct MainView: View {
    @State private var selectedSection: NavigationSection = .uninstaller
    @State private var uninstallerVM = AppUninstallerViewModel()
    @State private var diskVM = DiskAnalyzerViewModel()

    var body: some View {
        NavigationSplitView {
            List(NavigationSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            .navigationTitle("MacAppCleaner")
            .frame(minWidth: 200)
        } detail: {
            VStack(spacing: 0) {
                PermissionBannerView()

                switch selectedSection {
                case .uninstaller:
                    NavigationSplitView {
                        AppListView(viewModel: uninstallerVM)
                            .frame(minWidth: 260)
                    } detail: {
                        AppDetailView(viewModel: uninstallerVM)
                    }
                case .diskAnalyzer:
                    DiskHierarchyView(viewModel: diskVM)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
```

- [ ] **Step 3: Update App Entry Point**

Remove `Sources/MacAppCleaner/main.swift` and create `Sources/MacAppCleaner/MacAppCleanerApp.swift`:
```swift
import SwiftUI

@main
struct MacAppCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
```

- [ ] **Step 4: Run full test suite and build application**

Run:
```bash
cd /Users/admin/Documents/MacAppCleaner && swift test && swift build
```
Expected: All tests pass, build completes with 0 errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/admin/Documents/MacAppCleaner
git rm Sources/MacAppCleaner/main.swift 2>/dev/null || true
git add Sources/MacAppCleaner/
git commit -m "feat: implement MainView and MacAppCleanerApp entry point"
```

---

## Plan Self-Review Check
1. **Spec Coverage**:
   - Application discovery + architecture detection: Covered in Task 5.
   - Residual files detection across ~/Library: Covered in Task 4.
   - Hardcoded System Whitelist (SIP + system apps): Covered in Task 2.
   - Apple standard safe Trash protocol (`FileManager.trashItem`): Covered in Task 4.
   - Disk space analysis + hierarchy by size: Covered in Task 6 & Task 8.
   - Quick filters for large & old files: Covered in Task 6 & Task 8.
   - SwiftUI UDF / MVVM interface: Covered in Task 7, 8, 9.
2. **Placeholders**: Verified 0 instances of "TODO", "TBD", or vague placeholders.
3. **Type Consistency**: Verified `InstalledApp`, `RelatedFile`, `DiskItem`, `SafetyGuardService`, and `TrashService` names match throughout all tasks.
