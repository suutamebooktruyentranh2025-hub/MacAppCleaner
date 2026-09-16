import Foundation
import SwiftUI
import MacAppCleanerKit

public enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case size = "Dung lượng (Cao nhất)"
    case name = "Tên (A-Z)"

    public var id: String { rawValue }
}

@Observable
public final class LibraryManagerViewModel {
    public var libraries: [InstalledLibrary] = []
    public var selectedLibrary: InstalledLibrary?
    public var selectedCategory: LibraryCategory = .all
    public var searchText: String = ""
    public var sortOrder: LibrarySortOrder = .size
    public var isLoading: Bool = false
    public var isRemoving: Bool = false
    public var showRemovalModal: Bool = false
    public var reverseDependencies: [String] = []
    public var isCheckingDependencies: Bool = false
    public var errorMessage: String?
    public var showErrorAlert: Bool = false
    public var lastCachedDate: Date?

    private let scannerService: LibraryScannerService
    private let removalService: SafeLibraryRemovalService
    private let cacheService = AppCacheService.shared

    public init(
        scannerService: LibraryScannerService = .shared,
        removalService: SafeLibraryRemovalService = .shared
    ) {
        self.scannerService = scannerService
        self.removalService = removalService

        if let cached = cacheService.loadCachedLibraries() {
            self.libraries = cached.libraries
            self.lastCachedDate = cached.date
            self.selectedLibrary = self.filteredLibraries.first
        }
    }

    public var filteredLibraries: [InstalledLibrary] {
        var result = scannerService.filter(
            libraries: libraries,
            by: selectedCategory,
            query: searchText
        )

        switch sortOrder {
        case .size:
            result.sort { $0.size > $1.size }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }

    public var totalSize: Int64 {
        scannerService.totalLibrariesSize(libraries: libraries)
    }

    public func count(for category: LibraryCategory) -> Int {
        if category == .all {
            return libraries.count
        }
        return libraries.filter { $0.category == category }.count
    }

    @MainActor
    public func loadLibraries(force: Bool = false) async {
        if !force && !libraries.isEmpty {
            return
        }
        isLoading = true
        libraries = await scannerService.scanAllLibraries()
        cacheService.saveLibraries(libraries)
        lastCachedDate = Date()
        isLoading = false

        if selectedLibrary == nil, let first = filteredLibraries.first {
            await selectLibrary(first)
        }
    }

    @MainActor
    public func selectLibrary(_ library: InstalledLibrary) async {
        selectedLibrary = library
        reverseDependencies = []

        if library.category == .homebrew {
            isCheckingDependencies = true
            reverseDependencies = await removalService.checkReverseDependencies(for: library)
            isCheckingDependencies = false
        }
    }

    @MainActor
    public func removeSelectedLibrary() async -> Bool {
        guard let library = selectedLibrary else { return false }

        isRemoving = true
        defer { isRemoving = false }

        do {
            try await removalService.removeLibrary(library)
            libraries.removeAll { $0.id == library.id }
            cacheService.saveLibraries(libraries)
            selectedLibrary = filteredLibraries.first
            if let next = selectedLibrary {
                await selectLibrary(next)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return false
        }
    }
}
