# MacAppCleaner Technical Design Specification

- **Date:** 2026-09-16
- **Status:** Approved
- **Target Platform:** macOS 14.0+ (Sonoma) & macOS 15.0+ (Sequoia)
- **Primary Language & Framework:** Swift 6.3.3, SwiftUI, Swift Concurrency
- **Project Directory:** `/Users/admin/Documents/MacAppCleaner`

---

## 1. Executive Summary & Goals

**MacAppCleaner** is a native, lightweight, high-performance macOS utility designed to solve two core system maintenance challenges:
1. **Deep Application Uninstallation**: Locating all installed applications, displaying detailed metadata (architectures, version, bundle identifier, installation date), and thoroughly detecting all residual files (Caches, Application Support, Containers, Preferences, Logs, LaunchAgents) for safe removal.
2. **Disk Storage & Large File Analysis**: Recursively scanning and visualizing disk space usage in a hierarchical directory tree (inspired by OmniDiskSweeper), combined with quick filters for large (>500MB, >1GB) and old forgotten files.
3. **Ironclad System Protection (SafetyGuard)**: Absolute restriction preventing the deletion or modification of any macOS system-critical files (SIP directories, `/System`, `/usr`, `/bin`, `/sbin`, swapfiles, and Apple core system apps).

---

## 2. Technical Stack & Architecture

### 2.1 Core Technologies
- **UI Framework:** SwiftUI with `@Observable` macro (Swift Observation framework).
- **Concurrency Model:** Swift Concurrency (`async`/`await`, `actor`, `TaskGroup`, `AsyncStream`) for non-blocking file I/O.
- **System APIs:**
  - `Foundation` & `NSWorkspace`: Application discovery, icon retrieval, metadata extraction.
  - `FileManager.default.trashItem`: Safe Apple-native deletion protocol (moves to `.Trash` with "Put Back" capability).
  - `URL.resourceValues(forKeys:)`: High-speed APFS allocated file size computation (`totalFileAllocatedSizeKey`).
  - Mach-O binary parsing: Determining executable binary architecture (`arm64`, `x86_64`, `Universal 2`).

### 2.2 Project Structure
```
MacAppCleaner/
├── Package.swift / MacAppCleaner.xcodeproj
├── docs/
│   ├── superpowers/
│   │   ├── specs/
│   │   │   └── 2026-09-16-macappcleaner-design.md
│   │   └── plans/
│   │       └── 2026-09-16-macappcleaner.md
├── Sources/
│   ├── MacAppCleanerApp.swift           # Application entry point & window configuration
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── InstalledApp.swift       # Application entity with metadata & residual files
│   │   │   ├── RelatedFile.swift        # Residual file entity with path, size, & category
│   │   │   ├── DiskItem.swift           # Recursive tree node for disk usage analysis
│   │   │   └── FileCategory.swift       # Classification enum (App, Cache, Container, Log, etc.)
│   │   ├── Services/
│   │   │   ├── AppDiscoveryService.swift# Scans /Applications, ~/Applications, reads Info.plist
│   │   │   ├── ResidualScanner.swift    # Locates leftover files across standard ~/Library paths
│   │   │   ├── DiskScannerService.swift # Multi-threaded directory traversal & size calculations
│   │   │   ├── SafetyGuardService.swift # SIP paths whitelist & system app protection logic
│   │   │   └── TrashService.swift       # Safe recycling via FileManager.trashItem
│   │   └── Extensions/
│   │       ├── ByteCountFormatter+Ext.swift # Standardized byte/KB/MB/GB formatting
│   │       └── URL+ResourceValues.swift     # File size & metadata helpers
│   ├── UI/
│   │   ├── MainView.swift               # Root NavigationSplitView (Sidebar + Detail)
│   │   ├── Navigation/
│   │   │   └── SidebarNavigation.swift  # Switch between "Gỡ ứng dụng" and "Dung lượng ổ đĩa"
│   │   ├── Uninstaller/
│   │   │   ├── AppListView.swift        # Filterable & sortable list of installed apps
│   │   │   ├── AppRowView.swift         # Individual app row with icon, name, architecture badge
│   │   │   ├── AppDetailView.swift      # Expanded view displaying residual file tree with toggles
│   │   │   └── UninstallConfirmModal.swift # Confirmation sheet showing files and freed space
│   │   ├── DiskAnalyzer/
│   │   │   ├── DiskHierarchyView.swift  # Columnar hierarchical directory tree by size
│   │   │   ├── DiskItemRowView.swift    # Folder/File row with relative size progress bar
│   │   │   ├── QuickFilterView.swift    # Chips for Large Files (>500MB, >1GB) & Old Files (>6m)
│   │   │   └── ProtectedBadgeView.swift # Shield icon (🛡️) and tooltip for locked system files
│   │   └── Components/
│   │       ├── PermissionBannerView.swift # Warning & button to grant Full Disk Access (FDA)
│   │       └── StatSummaryHeader.swift    # Storage bar showing used vs free space
│   └── Resources/
│       └── Assets.xcassets
└── Tests/
    ├── MacAppCleanerTests/
    │   ├── ResidualScannerTests.swift
    │   ├── SafetyGuardTests.swift
    │   └── DiskScannerTests.swift
```

---

## 3. Detailed Component Specifications

### 3.1 Data Models

#### `InstalledApp`
- `id: UUID`
- `name: String` (e.g. "Google Chrome")
- `bundleURL: URL` (e.g. `/Applications/Google Chrome.app`)
- `bundleIdentifier: String` (e.g. `com.google.Chrome`)
- `version: String` (e.g. `128.0.6613.120`)
- `icon: NSImage`
- `architecture: AppArchitecture` (`.arm64`, `.intel`, `.universal`, `.unknown`)
- `installDate: Date?`
- `appSize: Int64` (allocated bytes of the `.app` bundle)
- `residualFiles: [RelatedFile]`
- `isSystemApp: Bool` (flagged `true` if bundle is in `/System/Applications` or Apple bundle ID)
- `totalSize: Int64` (computed property: `appSize + sum(residualFiles.size)`)

#### `RelatedFile`
- `id: UUID`
- `url: URL`
- `relativePath: String`
- `size: Int64`
- `category: FileCategory` (`.applicationSupport`, `.caches`, `.preferences`, `.savedState`, `.containers`, `.groupContainers`, `.logs`, `.webKit`, `.launchAgents`)
- `isSelectedForDeletion: Bool`

#### `DiskItem`
- `id: UUID`
- `url: URL`
- `name: String`
- `isDirectory: Bool`
- `size: Int64`
- `children: [DiskItem]?`
- `isProtected: Bool` (set by `SafetyGuardService`)
- `modificationDate: Date?`

---

### 3.2 Core Services

#### A. `AppDiscoveryService`
- **Responsibilities:**
  - Scans `/Applications`, `~/Applications`, and `/Users/Shared/Applications`.
  - Parses `Contents/Info.plist` for `CFBundleDisplayName`, `CFBundleName`, `CFBundleIdentifier`, `CFBundleShortVersionString`, `CFBundleIconFile`.
  - Inspects the executable binary header (via Mach-O magic numbers) to determine CPU architecture:
    - `0xFEEDFACF`: 64-bit Mach-O (`arm64` or `x86_64` depending on `cputype`).
    - `0xCAFEBABE`: Fat / Universal 2 binary containing both architectures.
  - Computes allocated size of `.app` directory recursively using APFS block allocation keys.

#### B. `ResidualScanner` (Pearcleaner Algorithm)
- **Standard residual search roots:**
  1. `~/Library/Application Support/{BundleID | AppName}`
  2. `~/Library/Caches/{BundleID | AppName}`
  3. `~/Library/Preferences/{BundleID}.plist`
  4. `~/Library/Saved Application State/{BundleID}.savedState`
  5. `~/Library/Containers/{BundleID}`
  6. `~/Library/Group Containers/{AppGroup}`
  7. `~/Library/Logs/{BundleID | AppName}`
  8. `~/Library/WebKit/{BundleID}`
  9. `~/Library/HTTPStorages/{BundleID}`
  10. `~/Library/LaunchAgents/{BundleID}.plist` & `/Library/LaunchAgents/{BundleID}.plist`
- **Fallback Matcher:** Matches case-insensitive sanitized AppName within `Application Support` and `Caches` for non-standard bundle IDs.

#### C. `DiskScannerService`
- **High-Performance Traversal:**
  - Employs `FileManager.default.enumerator(at:includingPropertiesForKeys:options:)` with `[.totalFileAllocatedSizeKey, .isDirectoryKey, .contentModificationDateKey]`.
  - Multi-threaded subfolder scanning using `withTaskGroup`.
  - Lazy loading: root level directories are summarized first, allowing instant UI rendering while deep folders compute in the background.
  - Sorting: Sorts nodes strictly descending by allocated size (`size > $1.size`).

#### D. `SafetyGuardService` (System File Protection)
- **Immutable System Whitelist:**
  - SIP-protected directories:
    - `/System`, `/System/Applications`, `/System/Library`
    - `/usr`, `/bin`, `/sbin`
    - `/private/var/vm` (macOS kernel swapfiles and sleepimage)
    - `/private/var/db`, `/private/etc`
    - `/Library/Apple`, dynamic linkers, boot caches.
  - Essential User System Configs:
    - `~/.ssh`
    - `~/Library/Keychains`
    - `~/Library/Accounts`
    - `/Library/Preferences/com.apple.*`
  - Core Apple Applications: Any application located in `/System/Applications` or carrying a `com.apple.*` bundle identifier.
- **Enforcement Rules:**
  - If `url.path` matches any prefix or item in the whitelist:
    - `isProtected` is set to `true`.
    - Deletion check/action in UI is disabled.
    - An explicit safety shield 🛡️ is rendered.
    - If a programmatic deletion call attempts to delete a protected item, `SafetyGuardService` throws `SafetyGuardError.systemFileProtected` and aborts immediately.

#### E. `TrashService`
- **Safe Recycling:**
  - Invokes `FileManager.default.trashItem(at: url, resultingItemURL: nil)`.
  - Never uses permanent destruction (`unlink` / `rm -rf`) in standard cleanup operations.
  - Guarantees items land in macOS Trash where users can right-click "Put Back".
  - Collects audit logs of moved items for user reference.

---

## 4. User Interface & Experience

### 4.1 Root Layout (`NavigationSplitView`)
- **Left Sidebar:**
  - **Quản lý Ứng dụng (App Uninstaller)**: View list of apps, total apps count, sort by Size, Name, Date.
  - **Phân tích Dung lượng (Disk Analyzer)**: Storage meter, directory tree, large files filters.
  - **Trạng thái Quyền Full Disk Access**: Indicator showing green checkmark (Full Disk Access granted) or warning prompt with a 1-click guide to open `System Settings > Privacy & Security > Full Disk Access`.

### 4.2 App Uninstaller View
- **Search & Sort Toolbar:** Search field with instant fuzzy search on App Name & Bundle ID. Sorting pills for Size (descending), Name (A-Z), and Install Date.
- **Application Item Row:**
  - 32x32 Application Icon.
  - App Name & Version.
  - Architecture badge (`ARM64` in purple, `Intel` in orange, `Universal` in blue).
  - Total size (App + residual files).
  - Protection Badge 🛡️ for system apps.
- **Detail View:**
  - Header: Large icon, App name, bundle ID, location link ("Show in Finder").
  - Breakdown Table:
    - [x] Application Binary (`.app`) — e.g. 240 MB
    - [x] Caches (`~/Library/Caches/...`) — e.g. 1.2 GB
    - [x] Application Support (`~/Library/Application Support/...`) — e.g. 450 MB
    - [x] Preferences (`~/Library/Preferences/...`) — e.g. 12 KB
    - [x] Containers / Sandbox — e.g. 80 MB
  - Action Footer: "Gỡ bỏ hoàn toàn (Uninstall)" button with total selected size badge (e.g. "Dọn dẹp 1.97 GB").

### 4.3 Disk Analyzer View
- **Columnar Tree View:**
  - Horizontal multi-column drill down (OmniDiskSweeper style).
  - Relative size bar chart for each folder.
  - Shield icon on `/System`, `/Library/Apple`, `/usr`, etc.
- **Quick Filter Bar:**
  - `Tệp lớn (>500MB)`
  - `Tệp khổng lồ (>2GB)`
  - `Tệp cũ (>6 tháng không mở)`
  - `Developer Caches (DerivedData, node_modules)`

---

## 5. Security, Permissions & Error Handling

1. **Full Disk Access (FDA) Detection:**
   - Detects FDA by checking read access to `~/Library/Safari` or `~/Library/Containers`.
   - If not granted, displays a polite banner explaining that macOS sandbox restrictions prevent discovering leftover files in `~/Library/Containers` and `~/Library/Application Support`.
   - Provides a direct link button: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.
2. **Error Boundaries:**
   - Permission errors (`EACCES`, `EPERM`) are gracefully caught and reported without crashing.
   - Busy/Locked files (applications currently running): Checks `NSRunningApplication` before deletion and prompts the user to close the app first.

---

## 6. Testing Strategy

1. **Unit Tests (`SafetyGuardTests`)**:
   - Verify that all SIP paths (`/System`, `/usr/bin`, `/sbin`, `/private/var/vm`) return `isProtected == true`.
   - Verify that attempting to trash a protected URL throws `SafetyGuardError.systemFileProtected`.
   - Verify that user files in `~/Downloads` return `isProtected == false`.
2. **Unit Tests (`ResidualScannerTests`)**:
   - Mock application bundles and verify that matching `Application Support`, `Caches`, and `Preferences` are correctly mapped to the test bundle identifier.
3. **Unit Tests (`DiskScannerTests`)**:
   - Verify size calculation accuracy against standard test directory fixtures.
