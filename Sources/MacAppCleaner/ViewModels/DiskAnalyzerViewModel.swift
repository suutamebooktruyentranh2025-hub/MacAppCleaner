import Foundation
import SwiftUI
import MacAppCleanerKit

@Observable
public final class DiskAnalyzerViewModel {
    public var currentRoot: DiskItem?
    public var selectedItem: DiskItem?
    public var navigationHistory: [DiskItem] = []
    public var isScanningHierarchy: Bool = false
    public var isScanningLargeFiles: Bool = false
    public var isScanning: Bool { isScanningHierarchy || isScanningLargeFiles }
    public var filterMode: FilterMode = .hierarchy
    public var minSizeFilter: Int64 = 500 * 1024 * 1024 // 500MB
    public var statusMessage: String = ""
    public var scanScope: ScanScope = .userHome
    public var showHiddenFiles: Bool = false
    public var diskStorageInfo: DiskStorageInfo?
    public var searchText: String = ""

    private static let showHiddenFilesKey = "DiskAnalyzer.showHiddenFiles"
    private var currentCacheKey: String {
        scanScope.cacheKey + (showHiddenFiles ? "_hidden" : "")
    }

    public enum FilterMode: String, CaseIterable {
        case hierarchy = "Cây thư mục"
        case largeFiles = "Tệp lớn (>500MB)"
        case hugeFiles = "Tệp khổng lồ (>2GB)"
    }

    public enum ScanScope: String, CaseIterable, Identifiable {
        case userHome = "Thư mục cá nhân (~)"
        case systemRoot = "Toàn bộ ổ đĩa (/)"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .userHome: return "house.fill"
            case .systemRoot: return "internaldrive.fill"
            }
        }

        public var cacheKey: String {
            switch self {
            case .userHome: return "home"
            case .systemRoot: return "system"
            }
        }
    }

    private let scannerService = DiskScannerService.shared
    private let trashService = TrashService.shared
    private let cacheService = AppCacheService.shared

    public var lastCachedDate: Date?
    private var cachedRoots: [String: DiskItem] = [:]
    private var cachedRootDates: [String: Date] = [:]
    private var cachedLargeFiles: [String: [DiskItem]] = [:]
    private var navigationHistories: [ScanScope: [DiskItem]] = [:]
    private var selectedItems: [ScanScope: DiskItem] = [:]
    private var scanTask: Task<Void, Never>?

    public var largeFiles: [DiskItem] {
        let minBytes: Int64 = (filterMode == .hugeFiles) ? (2 * 1024 * 1024 * 1024) : (500 * 1024 * 1024)
        var files = (cachedLargeFiles[currentCacheKey] ?? []).filter { $0.size >= minBytes }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            files = files.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.url.path.localizedCaseInsensitiveContains(query)
            }
        }
        return files
    }

    public init() {
        self.showHiddenFiles = UserDefaults.standard.bool(forKey: Self.showHiddenFilesKey)
        let initialScope = ScanScope.userHome
        let initialKey = initialScope.cacheKey + (showHiddenFiles ? "_hidden" : "")

        for scope in ScanScope.allCases {
            for hidden in [false, true] {
                let key = scope.cacheKey + (hidden ? "_hidden" : "")
                if let cached = cacheService.loadCachedDiskRoot(scope: key) {
                    cachedRoots[key] = cached.item
                    cachedRootDates[key] = cached.date
                }
                if let diskCached = cacheService.loadCachedLargeFiles(minBytes: 500 * 1024 * 1024, scope: key) {
                    cachedLargeFiles[key] = diskCached.files
                }
            }
        }
        if let homeCached = cachedRoots[initialKey] {
            self.currentRoot = homeCached
            self.selectedItem = homeCached.children?.first
            self.lastCachedDate = cachedRootDates[initialKey]
        }
        let initialURL = FileManager.default.homeDirectoryForCurrentUser
        self.diskStorageInfo = scannerService.getStorageInfo(for: initialURL)
    }

    @MainActor
    public func refreshStorageInfo() {
        let targetURL = scanScope == .userHome ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: "/")
        self.diskStorageInfo = scannerService.getStorageInfo(for: targetURL)
    }

    @MainActor
    public func setScope(_ newScope: ScanScope) {
        guard newScope != scanScope else { return }
        if let current = currentRoot, navigationHistory.isEmpty {
            cachedRoots[currentCacheKey] = current
        }
        navigationHistories[scanScope] = navigationHistory
        selectedItems[scanScope] = selectedItem

        scanScope = newScope
        currentRoot = cachedRoots[currentCacheKey]
        navigationHistory = navigationHistories[newScope] ?? []
        selectedItem = selectedItems[newScope] ?? currentRoot?.children?.first
        lastCachedDate = cachedRootDates[currentCacheKey]
        refreshStorageInfo()
    }

    @MainActor
    public func scanHomeDirectory() async {
        await scan(scope: .userHome, force: false)
    }

    @MainActor
    public func scan(scope: ScanScope? = nil, force: Bool = false) async {
        guard !isScanningHierarchy else { return }

        if let s = scope, s != scanScope {
            setScope(s)
        }

        let key = currentCacheKey

        // Check cache if not forcing re-scan
        if !force {
            if let inMemory = cachedRoots[key] {
                self.currentRoot = inMemory
                self.navigationHistory = navigationHistories[scanScope] ?? []
                self.selectedItem = selectedItems[scanScope] ?? inMemory.children?.first
                self.lastCachedDate = cachedRootDates[key]
                self.statusMessage = "Hoàn tất (từ bộ nhớ đệm)."
                return
            }
            if let diskCached = cacheService.loadCachedDiskRoot(scope: key) {
                cachedRoots[key] = diskCached.item
                cachedRootDates[key] = diskCached.date
                self.currentRoot = diskCached.item
                self.navigationHistory = []
                self.selectedItem = diskCached.item.children?.first
                self.lastCachedDate = diskCached.date
                self.statusMessage = "Hoàn tất (từ bộ nhớ đệm)."
                return
            }
        }

        isScanningHierarchy = true
        statusMessage = scanScope == .userHome ? "Đang phân tích thư mục người dùng..." : "Đang phân tích toàn bộ ổ đĩa hệ thống..."

        let targetURL = scanScope == .userHome ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: "/")
        refreshStorageInfo()

        do {
            let root = try await scannerService.scanDirectory(url: targetURL, includeHiddenFiles: showHiddenFiles)
            currentRoot = root
            selectedItem = root.children?.first
            navigationHistory = []
            cachedRoots[key] = root
            navigationHistories[scanScope] = []
            selectedItems[scanScope] = selectedItem
            let now = Date()
            lastCachedDate = now
            cachedRootDates[key] = now
            cacheService.saveDiskRoot(root, scope: key)
            statusMessage = "Hoàn tất."
        } catch {
            statusMessage = "Lỗi quét: \(error.localizedDescription)"
        }

        isScanningHierarchy = false
    }

    @MainActor
    public func toggleHiddenFiles() async {
        showHiddenFiles.toggle()
        UserDefaults.standard.set(showHiddenFiles, forKey: Self.showHiddenFilesKey)

        // Cancel any pending or in-flight scan immediately
        scanTask?.cancel()
        scanTask = nil

        guard let current = currentRoot else {
            await scan(force: true)
            return
        }

        let key = currentCacheKey

        // 1. If at root level, check cache first (Instant 0ms response!)
        if navigationHistory.isEmpty {
            if let inMemory = cachedRoots[key] {
                self.currentRoot = inMemory
                self.selectedItem = selectedItems[scanScope] ?? inMemory.children?.first
                self.lastCachedDate = cachedRootDates[key]
                self.statusMessage = "Hoàn tất (từ bộ nhớ đệm)."
                self.isScanningHierarchy = false
                if filterMode != .hierarchy {
                    await ensureLargeFilesScanned(force: false)
                }
                return
            }
            if let diskCached = cacheService.loadCachedDiskRoot(scope: key) {
                cachedRoots[key] = diskCached.item
                cachedRootDates[key] = diskCached.date
                self.currentRoot = diskCached.item
                self.selectedItem = diskCached.item.children?.first
                self.lastCachedDate = diskCached.date
                self.statusMessage = "Hoàn tất (từ bộ nhớ đệm)."
                self.isScanningHierarchy = false
                if filterMode != .hierarchy {
                    await ensureLargeFilesScanned(force: false)
                }
                return
            }
        } else {
            // 2. In a subdirectory: If turning hidden files OFF, filter immediately in-memory (Instant 0ms!)
            if !showHiddenFiles, let children = current.children {
                let filtered = children.filter { !$0.isHidden }
                let updated = DiskItem(
                    id: current.id,
                    url: current.url,
                    name: current.name,
                    isDirectory: current.isDirectory,
                    size: filtered.reduce(0) { $0 + $1.size },
                    children: filtered,
                    isProtected: current.isProtected,
                    modificationDate: current.modificationDate,
                    isHidden: current.isHidden
                )
                self.currentRoot = updated
                self.selectedItem = updated.children?.first
                self.statusMessage = "Hoàn tất."
                self.isScanningHierarchy = false
                if filterMode != .hierarchy {
                    await ensureLargeFilesScanned(force: false)
                }
                return
            }
        }

        // 3. Scan directory asynchronously
        isScanningHierarchy = true
        statusMessage = showHiddenFiles ? "Đang hiển thị tệp ẩn..." : "Đang ẩn tệp ẩn..."

        let targetURL = current.url
        let targetHidden = showHiddenFiles

        let newTask = Task { [weak self, scannerService, cacheService] in
            do {
                let refreshed = try await scannerService.scanDirectory(url: targetURL, includeHiddenFiles: targetHidden)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.showHiddenFiles == targetHidden else { return }
                    self.currentRoot = refreshed
                    self.selectedItem = refreshed.children?.first

                    if self.navigationHistory.isEmpty {
                        self.cachedRoots[key] = refreshed
                        let now = Date()
                        self.lastCachedDate = now
                        self.cachedRootDates[key] = now
                        cacheService.saveDiskRoot(refreshed, scope: key)
                    }
                    self.statusMessage = "Hoàn tất."
                    self.isScanningHierarchy = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self else { return }
                    self.statusMessage = "Lỗi khi cập nhật thư mục ẩn: \(error.localizedDescription)"
                    self.isScanningHierarchy = false
                }
            }
        }
        self.scanTask = newTask
        await newTask.value

        if filterMode != .hierarchy {
            await ensureLargeFilesScanned(force: true)
        }
    }

    @MainActor
    public func ensureLargeFilesScanned(force: Bool = false) async {
        guard !isScanningLargeFiles else { return }

        let key = currentCacheKey
        let minBytes: Int64 = 500 * 1024 * 1024

        // 1. In-memory cache
        if !force, cachedLargeFiles[key] != nil {
            return
        }

        // 2. Disk cache
        if !force, let diskCached = cacheService.loadCachedLargeFiles(minBytes: minBytes, scope: key) {
            cachedLargeFiles[key] = diskCached.files
            statusMessage = "Tìm thấy \(diskCached.files.count) tệp lớn (từ bộ nhớ đệm)."
            return
        }

        // 3. Scan disk
        isScanningLargeFiles = true
        statusMessage = "Đang tìm các tệp lớn..."
        let targetURL = scanScope == .userHome ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: "/")
        let files = await scannerService.findLargeFiles(at: targetURL, minSizeBytes: minBytes, includeHiddenFiles: showHiddenFiles)

        cachedLargeFiles[key] = files
        cacheService.saveLargeFiles(files, minBytes: minBytes, scope: key)
        statusMessage = "Tìm thấy \(files.count) tệp lớn."
        isScanningLargeFiles = false
    }

    @MainActor
    public func scanLargeFiles(minBytes: Int64 = 500 * 1024 * 1024, force: Bool = false) async {
        await ensureLargeFilesScanned(force: force)
    }

    @MainActor
    public func navigateInto(item: DiskItem) async {
        guard item.isDirectory else { return }
        if let current = currentRoot {
            navigationHistory.append(current)
        }
        isScanningHierarchy = true
        do {
            currentRoot = try await scannerService.scanDirectory(url: item.url, includeHiddenFiles: showHiddenFiles)
            selectedItem = currentRoot?.children?.first
            navigationHistories[scanScope] = navigationHistory
            selectedItems[scanScope] = selectedItem
        } catch {
            statusMessage = "Không thể mở thư mục: \(error.localizedDescription)"
        }
        isScanningHierarchy = false
    }

    public var breadcrumbs: [DiskItem] {
        var list = navigationHistory
        if let current = currentRoot {
            list.append(current)
        }
        return list
    }

    @MainActor
    public func navigateBack() async {
        guard let prev = navigationHistory.popLast() else { return }
        navigationHistories[scanScope] = navigationHistory

        if navigationHistory.isEmpty, let cached = cachedRoots[currentCacheKey] {
            currentRoot = cached
            selectedItem = cached.children?.first
            selectedItems[scanScope] = selectedItem
            return
        }

        isScanningHierarchy = true
        do {
            let refreshed = try await scannerService.scanDirectory(url: prev.url, includeHiddenFiles: showHiddenFiles)
            currentRoot = refreshed
            selectedItem = refreshed.children?.first
            selectedItems[scanScope] = selectedItem
        } catch {
            currentRoot = prev
            selectedItem = prev.children?.first
        }
        isScanningHierarchy = false
    }

    @MainActor
    public func navigateToBreadcrumb(_ item: DiskItem) async {
        guard item.id != currentRoot?.id else { return }
        guard let index = navigationHistory.firstIndex(where: { $0.url == item.url || $0.id == item.id }) else { return }
        let targetURL = navigationHistory[index].url
        navigationHistory = Array(navigationHistory.prefix(upTo: index))
        navigationHistories[scanScope] = navigationHistory

        if navigationHistory.isEmpty, let cached = cachedRoots[currentCacheKey] {
            currentRoot = cached
            selectedItem = cached.children?.first
            selectedItems[scanScope] = selectedItem
            return
        }

        isScanningHierarchy = true
        do {
            let refreshed = try await scannerService.scanDirectory(url: targetURL, includeHiddenFiles: showHiddenFiles)
            currentRoot = refreshed
            selectedItem = refreshed.children?.first
            selectedItems[scanScope] = selectedItem
        } catch {
            statusMessage = "Không thể mở thư mục: \(error.localizedDescription)"
        }
        isScanningHierarchy = false
    }

    @MainActor
    public func trashItem(_ item: DiskItem) async {
        do {
            try trashService.trashItem(at: item.url)
            if let root = currentRoot {
                currentRoot = try await scannerService.scanDirectory(url: root.url, includeHiddenFiles: showHiddenFiles)
                if navigationHistory.isEmpty {
                    cachedRoots[currentCacheKey] = currentRoot
                }
            }
            if var scopeFiles = cachedLargeFiles[currentCacheKey] {
                scopeFiles.removeAll { $0.id == item.id }
                cachedLargeFiles[currentCacheKey] = scopeFiles
                cacheService.saveLargeFiles(scopeFiles, minBytes: 500 * 1024 * 1024, scope: currentCacheKey)
            }
            refreshStorageInfo()
        } catch {
            statusMessage = "Không thể xoá tệp: \(error.localizedDescription)"
        }
    }
}
