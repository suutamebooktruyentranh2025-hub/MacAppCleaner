import Foundation

public final class LibraryScannerService: Sendable {
    public static let shared = LibraryScannerService()

    private let providers: [LibraryProvider]

    public init(providers: [LibraryProvider]? = nil) {
        if let customProviders = providers {
            self.providers = customProviders
        } else {
            self.providers = [
                MacOSFrameworkScanner(),
                AudioPluginScanner(),
                QuickLookScanner(),
                HomebrewScanner(),
                NodePackageScanner(),
                PythonPackageScanner(),
                AIModelScanner()
            ]
        }
    }

    /// Scans all registered library providers concurrently
    public func scanAllLibraries() async -> [InstalledLibrary] {
        await withTaskGroup(of: [InstalledLibrary].self) { group in
            for provider in providers {
                group.addTask {
                    await provider.scanLibraries()
                }
            }

            var allLibraries: [InstalledLibrary] = []
            for await batch in group {
                allLibraries.append(contentsOf: batch)
            }

            return allLibraries.sorted { $0.size > $1.size }
        }
    }

    /// Filters libraries by category and search query
    public func filter(
        libraries: [InstalledLibrary],
        by category: LibraryCategory,
        query: String
    ) -> [InstalledLibrary] {
        var filtered = libraries

        if category != .all {
            filtered = filtered.filter { $0.category == category }
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                ($0.descriptionText?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
                $0.installPath.path.localizedCaseInsensitiveContains(trimmed)
            }
        }

        return filtered
    }

    /// Calculates total storage occupied by the given libraries
    public func totalLibrariesSize(libraries: [InstalledLibrary]) -> Int64 {
        libraries.reduce(0) { $0 + $1.size }
    }
}
