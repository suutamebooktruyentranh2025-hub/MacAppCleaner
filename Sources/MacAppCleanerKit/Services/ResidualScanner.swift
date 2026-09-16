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
        while let fileURL = enumerator.nextObject() as? URL {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
