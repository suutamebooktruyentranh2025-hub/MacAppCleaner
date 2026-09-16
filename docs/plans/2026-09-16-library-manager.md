# Libraries & Extensions Manager Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Build a comprehensive, safe Libraries & Extensions Manager in MacAppCleaner that scans, inspects, and safely removes macOS Frameworks, Audio Plugins, QuickLook plugins, and Developer Packages (Homebrew, npm global, Python pip).

**Architecture:** Modular Strategy Pattern where individual scanners implement the `LibraryProvider` protocol, aggregated by `LibraryScannerService`. Safe removal is executed via `SafeLibraryRemovalService` using a dual-engine: macOS Trash with Put-Back support for filesystem bundles, and dependency-checked CLI execution for package managers. The UI integrates as a dedicated 3rd navigation section in `MainView`.

**Tech Stack:** Swift 5.9+, SwiftUI, Foundation, AppKit, Process/CLI interaction.

---

### Task 1: Core Models & Protocols (`InstalledLibrary`, `LibraryCategory`, `LibraryRiskLevel`, `LibraryProvider`)

**Files:**
- Create: `Sources/MacAppCleanerKit/Models/InstalledLibrary.swift`
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/LibraryProvider.swift`
- Test: `Tests/MacAppCleanerTests/LibraryModelTests.swift`

**Step 1: Write failing tests**
- Test `InstalledLibrary` initialization, category icon/title formatting, and risk level enum properties.

**Step 2: Run test to verify it fails**
- Run: `swift test --filter LibraryModelTests`
- Expected: FAIL with missing types.

**Step 3: Implement minimal code**
- Create `InstalledLibrary.swift` with `LibraryCategory`, `LibraryRiskLevel`, and `InstalledLibrary` struct.
- Create `LibraryProvider.swift` protocol defining `var category: LibraryCategory { get }` and `func scanLibraries() async -> [InstalledLibrary]`.

**Step 4: Run test to verify it passes**
- Run: `swift test --filter LibraryModelTests`
- Expected: PASS.

**Step 5: Commit**
- `git add Sources/MacAppCleanerKit/Models/InstalledLibrary.swift Sources/MacAppCleanerKit/Services/LibraryScanner/LibraryProvider.swift Tests/MacAppCleanerTests/LibraryModelTests.swift`
- `git commit -m "feat(libraries): add core library models and LibraryProvider protocol"`

---

### Task 2: macOS Extension Scanners (`MacOSFrameworkScanner`, `AudioPluginScanner`, `QuickLookScanner`)

**Files:**
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/MacOSFrameworkScanner.swift`
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/AudioPluginScanner.swift`
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/QuickLookScanner.swift`
- Test: `Tests/MacAppCleanerTests/MacOSFrameworkScannerTests.swift`

**Step 1: Write failing tests**
- Test scanning a mock directory structure with `.framework`, `.vst3`, `.component`, and `.qlgenerator` bundles. Verify extraction of bundle name, version from `Info.plist`, and total disk size calculation.

**Step 2: Run test to verify it fails**
- Run: `swift test --filter MacOSFrameworkScannerTests`
- Expected: FAIL with unresolved identifiers.

**Step 3: Implement minimal scanners**
- Implement `MacOSFrameworkScanner`: scans `/Library/Frameworks` and `~/Library/Frameworks`.
- Implement `AudioPluginScanner`: scans `/Library/Audio/Plug-Ins/{Components,VST,VST3,CLAP}` and user paths.
- Implement `QuickLookScanner`: scans `/Library/QuickLook` and `/Library/PreferencePanes`.

**Step 4: Run test to verify it passes**
- Run: `swift test --filter MacOSFrameworkScannerTests`
- Expected: PASS.

**Step 5: Commit**
- `git add Sources/MacAppCleanerKit/Services/LibraryScanner/MacOSFrameworkScanner.swift Sources/MacAppCleanerKit/Services/LibraryScanner/AudioPluginScanner.swift Sources/MacAppCleanerKit/Services/LibraryScanner/QuickLookScanner.swift Tests/MacAppCleanerTests/MacOSFrameworkScannerTests.swift`
- `git commit -m "feat(libraries): add macOS frameworks and audio plugin scanners"`

---

### Task 3: Developer Package Scanners (`HomebrewScanner`, `NodePackageScanner`, `PythonPackageScanner`)

**Files:**
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/HomebrewScanner.swift`
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/NodePackageScanner.swift`
- Create: `Sources/MacAppCleanerKit/Services/LibraryScanner/PythonPackageScanner.swift`
- Test: `Tests/MacAppCleanerTests/DeveloperPackageScannerTests.swift`

**Step 1: Write failing tests**
- Test Homebrew Cellar folder scanning fallback and JSON parsing.
- Test global Node modules detection in `node_modules` folders.
- Test Python `site-packages` metadata parsing.

**Step 2: Run test to verify it fails**
- Run: `swift test --filter DeveloperPackageScannerTests`
- Expected: FAIL.

**Step 3: Implement minimal scanners**
- `HomebrewScanner`: Checks `/opt/homebrew/Cellar` and `/usr/local/Cellar`, queries `brew info --json=v2 --installed` when `brew` CLI is available.
- `NodePackageScanner`: Checks `npm root -g` and `~/.nvm/versions/node/*/lib/node_modules`.
- `PythonPackageScanner`: Checks `/Library/Python/*/site-packages`, `~/Library/Python/*/lib/python/site-packages`.

**Step 4: Run test to verify it passes**
- Run: `swift test --filter DeveloperPackageScannerTests`
- Expected: PASS.

**Step 5: Commit**
- `git add Sources/MacAppCleanerKit/Services/LibraryScanner/HomebrewScanner.swift Sources/MacAppCleanerKit/Services/LibraryScanner/NodePackageScanner.swift Sources/MacAppCleanerKit/Services/LibraryScanner/PythonPackageScanner.swift Tests/MacAppCleanerTests/DeveloperPackageScannerTests.swift`
- `git commit -m "feat(libraries): add developer package scanners for Homebrew, Node, and Python"`

---

### Task 4: Library Aggregator Service (`LibraryScannerService`)

**Files:**
- Create: `Sources/MacAppCleanerKit/Services/LibraryScannerService.swift`
- Test: `Tests/MacAppCleanerTests/LibraryScannerServiceTests.swift`

**Step 1: Write failing tests**
- Test aggregating all providers concurrently, handling empty providers gracefully, sorting by category and size.

**Step 2: Run test to verify it fails**
- Run: `swift test --filter LibraryScannerServiceTests`
- Expected: FAIL.

**Step 3: Implement aggregator service**
- Implement `LibraryScannerService.shared.scanAllLibraries()` executing scanner providers concurrently with `TaskGroup`.

**Step 4: Run test to verify it passes**
- Run: `swift test --filter LibraryScannerServiceTests`
- Expected: PASS.

**Step 5: Commit**
- `git add Sources/MacAppCleanerKit/Services/LibraryScannerService.swift Tests/MacAppCleanerTests/LibraryScannerServiceTests.swift`
- `git commit -m "feat(libraries): add LibraryScannerService concurrent aggregator"`

---

### Task 5: Safe Library Removal Service (`SafeLibraryRemovalService`)

**Files:**
- Create: `Sources/MacAppCleanerKit/Services/SafeLibraryRemovalService.swift`
- Test: `Tests/MacAppCleanerTests/SafeLibraryRemovalServiceTests.swift`

**Step 1: Write failing tests**
- Test blocking deletion of `/System/Library` items.
- Test trashing non-protected frameworks into macOS Trash.
- Test reverse-dependency checking query.

**Step 2: Run test to verify it fails**
- Run: `swift test --filter SafeLibraryRemovalServiceTests`
- Expected: FAIL.

**Step 3: Implement SafeLibraryRemovalService**
- Implement safety check (`SafetyGuardService.shared.isSystemProtected`).
- Implement `trashFilesystemLibrary(library: InstalledLibrary)` via `TrashService.shared.trashItem(at:)`.
- Implement `uninstallPackageLibrary(library: InstalledLibrary)` via CLI with preflight dependency checks.

**Step 4: Run test to verify it passes**
- Run: `swift test --filter SafeLibraryRemovalServiceTests`
- Expected: PASS.

**Step 5: Commit**
- `git add Sources/MacAppCleanerKit/Services/SafeLibraryRemovalService.swift Tests/MacAppCleanerTests/SafeLibraryRemovalServiceTests.swift`
- `git commit -m "feat(libraries): add SafeLibraryRemovalService with reverse dependency guard and Trash support"`

---

### Task 6: Library Manager ViewModel (`LibraryManagerViewModel`)

**Files:**
- Create: `Sources/MacAppCleaner/ViewModels/LibraryManagerViewModel.swift`

**Step 1: Implement LibraryManagerViewModel**
- State properties: `libraries`, `selectedLibrary`, `selectedCategory`, `searchText`, `sortOrder`, `isLoading`, `isRemoving`, `showRemovalModal`, `errorMessage`, `showErrorAlert`.
- Computed `filteredLibraries`.
- Methods: `loadLibraries()`, `selectLibrary()`, `removeSelectedLibrary()`.

**Step 2: Verify compilation**
- Run: `swift build`
- Expected: Build complete.

**Step 3: Commit**
- `git add Sources/MacAppCleaner/ViewModels/LibraryManagerViewModel.swift`
- `git commit -m "feat(libraries): add LibraryManagerViewModel for state and filtering"`

---

### Task 7: Library Manager SwiftUI Views

**Files:**
- Create: `Sources/MacAppCleaner/Views/Libraries/LibraryRowView.swift`
- Create: `Sources/MacAppCleaner/Views/Libraries/LibraryListView.swift`
- Create: `Sources/MacAppCleaner/Views/Libraries/LibraryDetailView.swift`
- Create: `Sources/MacAppCleaner/Views/Libraries/LibraryRemovalModal.swift`
- Create: `Sources/MacAppCleaner/Views/Libraries/LibraryManagerView.swift`

**Step 1: Implement Views**
- `LibraryRowView`: Category icon, name, version pill, formatted size, safety badge.
- `LibraryListView`: Search field, horizontal category pills (`Tất cả`, `Frameworks`, `Audio`, `Homebrew`, `Node.js`, `Python`), sort dropdown.
- `LibraryDetailView`: Detailed inspection header, path with Finder button, dependency list, red "Xóa thư viện an toàn" button.
- `LibraryRemovalModal`: Safe removal confirmation with Put Back assurance note and dependency warnings.
- `LibraryManagerView`: `HSplitView` assembling list and detail views.

**Step 2: Verify compilation**
- Run: `swift build`
- Expected: Build complete.

**Step 3: Commit**
- `git add Sources/MacAppCleaner/Views/Libraries/`
- `git commit -m "feat(libraries): implement complete Library Manager UI components"`

---

### Task 8: Navigation & Sidebar Integration in `MainView`

**Files:**
- Modify: `Sources/MacAppCleaner/Views/MainView.swift`

**Step 1: Add libraries section to NavigationSection**
- `case libraries = "Thư viện & Tiện ích"` with icon `books.vertical.fill`.
- Update detail switch to render `LibraryManagerView(viewModel: libraryVM)`.
- Add badge showing library count.

**Step 2: Verify compilation & layout**
- Run: `swift build`
- Expected: Build complete.

**Step 3: Commit**
- `git add Sources/MacAppCleaner/Views/MainView.swift`
- `git commit -m "feat(navigation): integrate Libraries & Extensions Manager into MainView sidebar"`

---

### Task 9: End-to-End Verification, Release Build & DMG Packaging

**Files:**
- Modify: `docs/plans/task.md`

**Step 1: Run all unit tests**
- Run: `swift test`
- Expected: All tests pass (0 failures).

**Step 2: Build release application and disk image**
- Run: `./scripts/build-app.sh`
- Expected: `MacAppCleaner.app` signed with stable designated requirement and `MacAppCleaner.dmg` verified with `hdiutil verify: checksum VALID`.

**Step 3: Update task tracker**
- Update `docs/plans/task.md`.

**Step 4: Commit**
- `git add docs/plans/task.md`
- `git commit -m "chore: complete Libraries & Extensions Manager feature and package release DMG"`
