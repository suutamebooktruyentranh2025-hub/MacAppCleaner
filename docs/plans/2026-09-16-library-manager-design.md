# Design Document: Libraries & Extensions Manager (Quản lý Thư viện & Tiện ích)

**Date**: 2026-09-16  
**Status**: Approved  
**Author**: Antigravity  

---

## 1. Overview & Objectives

Mac users frequently accumulate deep system frameworks, audio plugins, and package manager libraries (Homebrew, npm global packages, Python pip libraries) over months and years of software development and usage. These libraries often consume gigabytes of disk space and leave orphaned files when host applications are uninstalled.

The **Libraries & Extensions Manager** adds a dedicated 3rd navigation section to MacAppCleaner, allowing users to:
1. Scan and inspect all installed macOS Frameworks, Audio Plugins, QuickLook plugins, and Developer Libraries (Homebrew, Node.js global npm, Python pip).
2. View deep metadata: installation path, total disk size, version, and **reverse dependencies** (which other tools or apps depend on this library).
3. Safely delete libraries with protection against breaking dependencies and ability to restore via macOS Trash (**Put Back**).

---

## 2. Scope

### A. macOS System & User Extensions
* **macOS Frameworks**: `/Library/Frameworks` and `~/Library/Frameworks` (e.g., Python.framework, Adobe, Mono, Steam).
* **Audio Plugins**: `/Library/Audio/Plug-Ins/` and `~/Library/Audio/Plug-Ins/` (`Components`, `VST`, `VST3`, `CLAP`).
* **QuickLook Plugins**: `/Library/QuickLook` and `~/Library/QuickLook`.
* **Preference Panes**: `/Library/PreferencePanes` and `~/Library/PreferencePanes`.

### B. Developer Package Managers
* **Homebrew**: Formulae and Casks installed in `/opt/homebrew/Cellar` (Apple Silicon) or `/usr/local/Cellar` (Intel), queried via `brew list` & `brew info --json=v2`.
* **Node.js (Global npm)**: Globally installed packages in `npm root -g` (or `~/.nvm`, `/usr/local/lib/node_modules`).
* **Python (pip)**: Packages installed in global/user `site-packages` or detected via `python3 -m pip list --format=json`.

---

## 3. Architecture & Modular Design

To ensure stability, testability, and resilience against missing CLI tools on a user's Mac, the system uses a **Modular Strategy Pattern** with a unified `LibraryProvider` protocol.

```
MacAppCleanerKit/
  └── Services/
       ├── LibraryScanner/
       │    ├── LibraryProvider.swift (Protocol)
       │    ├── MacOSFrameworkScanner.swift
       │    ├── AudioPluginScanner.swift
       │    ├── HomebrewScanner.swift
       │    ├── NodePackageScanner.swift
       │    └── PythonPackageScanner.swift
       ├── LibraryScannerService.swift (Aggregator & coordinator)
       └── SafeLibraryRemovalService.swift (Deletion engine with safety guards)
MacAppCleaner/
  ├── ViewModels/
  │    └── LibraryManagerViewModel.swift
  └── Views/
       └── Libraries/
            ├── LibraryManagerView.swift (Main split view)
            ├── LibraryListView.swift (Search, filter pills, library rows)
            ├── LibraryDetailView.swift (Inspection card, reverse deps, action buttons)
            └── LibraryRemovalModal.swift (Safe confirmation modal with dependency warnings)
```

---

## 4. Core Data Models

```swift
public enum LibraryCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "Tất cả"
    case frameworks = "Frameworks macOS"
    case audioPlugins = "Audio Plugins (VST/AU)"
    case homebrew = "Homebrew"
    case node = "Node.js (npm)"
    case python = "Python (pip)"
    case quickLook = "QuickLook / Panes"

    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .frameworks: return "shippingbox.fill"
        case .audioPlugins: return "waveform.badge.magnifyingglass"
        case .homebrew: return "mug.fill"
        case .node: return "shippingbox.circle.fill"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .quickLook: return "eye.fill"
        }
    }
}

public enum LibraryRiskLevel: String, Sendable {
    case safe = "An toàn để xóa"
    case caution = "Cần lưu ý (Có công cụ phụ thuộc)"
    case systemProtected = "Được bảo vệ bởi hệ thống"
}

public struct InstalledLibrary: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let version: String?
    public let category: LibraryCategory
    public let installPath: URL
    public let size: Int64
    public let riskLevel: LibraryRiskLevel
    public let dependencies: [String]      // What this library needs
    public let requiredBy: [String]        // What needs this library
    public let descriptionText: String?
    public let isSystemProtected: Bool
}
```

---

## 5. Safe Deletion Engine (`SafeLibraryRemovalService`)

The removal logic implements a **dual safe-handling mechanism**:

1. **System Protection Guard (`SafetyGuardService`)**:
   - Strictly rejects any item under `/System/Library` or items marked with Apple bundle identifiers (`com.apple.*`).
   - Marks system-critical frameworks as `.systemProtected` with deletion disabled.

2. **Filesystem Items (Frameworks, Audio Plugins, QuickLook)**:
   - Uses `TrashService.shared.trashItem(at: url)` to safely move the bundle to `~/.Trash`.
   - Never calls permanent `rm -rf`. Users can right-click the item in macOS Trash and select **Put Back** to restore instantly.

3. **Package Manager Items (Homebrew, npm, pip)**:
   - **Pre-flight Dependency Check**:
     - Homebrew: Queries `brew uses --installed <name>`. If other packages depend on it, sets `riskLevel = .caution` and displays an explicit warning list in the UI before confirmation.
   - **Removal Execution**:
     - Homebrew: Executes `/opt/homebrew/bin/brew uninstall <name>` (or `/usr/local/bin/brew`).
     - Node: Executes `npm uninstall -g <name>`.
     - Python: Executes `python3 -m pip uninstall -y <name>`.

---

## 6. User Experience & UI Workflow

1. **Sidebar Entry**:
   - `NavigationSection.libraries = "Thư viện & Tiện ích"` with icon `books.vertical.fill`.
   - Displays live badge of total detected libraries.
2. **Top Filter Bar**:
   - Smooth horizontal pills for switching between categories: `[Tất cả] [Frameworks] [Audio] [Homebrew] [Node.js] [Python]`.
   - Real-time search by name, path, or dependent package.
3. **Master-Detail Layout**:
   - **Left Column**: List of libraries showing category icon, name, version pill, disk size, and safety badge (Green: Safe / Orange: Has dependents / Purple: Protected).
   - **Right Column**: Comprehensive inspection card with path link to Finder, dependency graph pills, and the red action button `"Xóa thư viện"`.
4. **Interactive Confirmation Modal**:
   - Breakdown of files to be trashed or CLI command to be executed.
   - Distinct alert banner if reverse dependencies exist.
   - Action buttons: `"Hủy bỏ"` and `"Xác nhận gỡ bỏ"`.

---

## 7. Verification & Testing Strategy

* **Unit Tests (`MacAppCleanerTests`)**:
  - `MacOSFrameworkScannerTests`: Scanning mock framework directory hierarchy and extracting versions.
  - `AudioPluginScannerTests`: Parsing mock VST/Component bundles.
  - `SafeLibraryRemovalServiceTests`: Ensuring system-protected items throw error; verifying reverse-dependency warnings.
* **Packaging & Integrity**:
  - `swift test` passing with 100% success.
  - `./scripts/build-app.sh` generating signed `.app` and valid DMG (`hdiutil verify`).
