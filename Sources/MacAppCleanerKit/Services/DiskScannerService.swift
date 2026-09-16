import Foundation

public final class DiskScannerService: Sendable {
    public static let shared = DiskScannerService()
    private let safetyGuard: SafetyGuardService

    public init(safetyGuard: SafetyGuardService = .shared) {
        self.safetyGuard = safetyGuard
    }

    public func getStorageInfo(for url: URL = URL(fileURLWithPath: "/")) -> DiskStorageInfo {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]

        var volumeName = "Ổ đĩa Macintosh"
        var totalCapacity: Int64 = 0
        var availableCapacity: Int64 = 0

        if let values = try? url.resourceValues(forKeys: keys) {
            if let name = values.volumeName, !name.isEmpty {
                volumeName = name
            }
            if let total = values.volumeTotalCapacity {
                totalCapacity = Int64(total)
            }
            if let availableImportant = values.volumeAvailableCapacityForImportantUsage {
                availableCapacity = availableImportant
            } else if let available = values.volumeAvailableCapacity {
                availableCapacity = Int64(available)
            }
        }

        // Fallback to FileManager filesystem attributes if needed
        if totalCapacity <= 0 {
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.path) {
                if let size = attrs[.systemSize] as? NSNumber {
                    totalCapacity = size.int64Value
                }
                if let free = attrs[.systemFreeSize] as? NSNumber, availableCapacity <= 0 {
                    availableCapacity = free.int64Value
                }
            }
        }

        return DiskStorageInfo(
            volumeName: volumeName,
            totalCapacity: totalCapacity,
            availableCapacity: availableCapacity,
            volumeURL: url
        )
    }

    public func scanDirectory(url: URL, maxDepth: Int = 1, includeHiddenFiles: Bool = false) async throws -> DiskItem {
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
        let options: FileManager.DirectoryEnumerationOptions = includeHiddenFiles ? [] : [.skipsHiddenFiles]
        let contents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isHiddenKey],
            options: options
        )) ?? []

        var childItems: [DiskItem] = []
        var totalFolderSize: Int64 = 0

        // Separate directories and files
        var dirURLs: [URL] = []
        var fileItems: [DiskItem] = []

        for childURL in contents {
            var childIsDir: ObjCBool = false
            guard fileManager.fileExists(atPath: childURL.path, isDirectory: &childIsDir) else { continue }

            let childProtected = safetyGuard.isSystemProtected(url: childURL)
            let childAttrs = try? fileManager.attributesOfItem(atPath: childURL.path)
            let childModDate = childAttrs?[.modificationDate] as? Date
            let isHidden = childURL.lastPathComponent.hasPrefix(".") || ((try? childURL.resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false)

            if childIsDir.boolValue {
                dirURLs.append(childURL)
            } else {
                let size = (childAttrs?[.size] as? Int64) ?? 0
                totalFolderSize += size
                fileItems.append(DiskItem(
                    url: childURL,
                    name: childURL.lastPathComponent,
                    isDirectory: false,
                    size: size,
                    children: nil,
                    isProtected: childProtected,
                    modificationDate: childModDate,
                    isHidden: isHidden
                ))
            }
        }

        // Concurrently calculate directory sizes across available cores
        var dirSizes: [URL: Int64] = [:]
        await withTaskGroup(of: (URL, Int64).self) { group in
            for dirURL in dirURLs {
                group.addTask {
                    if Task.isCancelled { return (dirURL, 0) }
                    let s = self.calculateDirectorySize(at: dirURL)
                    return (dirURL, s)
                }
            }
            for await (dirURL, s) in group {
                dirSizes[dirURL] = s
            }
        }

        for dirURL in dirURLs {
            let childProtected = safetyGuard.isSystemProtected(url: dirURL)
            let childAttrs = try? fileManager.attributesOfItem(atPath: dirURL.path)
            let childModDate = childAttrs?[.modificationDate] as? Date
            let isHidden = dirURL.lastPathComponent.hasPrefix(".") || ((try? dirURL.resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false)
            let size = dirSizes[dirURL] ?? 0
            totalFolderSize += size

            childItems.append(DiskItem(
                url: dirURL,
                name: dirURL.lastPathComponent,
                isDirectory: true,
                size: size,
                children: nil,
                isProtected: childProtected,
                modificationDate: childModDate,
                isHidden: isHidden
            ))
        }

        childItems.append(contentsOf: fileItems)

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

    public func findLargeFiles(at rootURL: URL, minSizeBytes: Int64, includeHiddenFiles: Bool = true) async -> [DiskItem] {
        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = includeHiddenFiles ? [.skipsPackageDescendants] : [.skipsPackageDescendants, .skipsHiddenFiles]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: options
        ) else {
            return []
        }

        var results: [DiskItem] = []

        while let fileURL = enumerator.nextObject() as? URL {
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
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return 0
        }
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
