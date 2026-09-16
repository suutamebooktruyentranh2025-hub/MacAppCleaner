import Foundation

public struct CacheEntry<T: Codable>: Codable {
    public let data: T
    public let timestamp: Date

    public init(data: T, timestamp: Date = Date()) {
        self.data = data
        self.timestamp = timestamp
    }
}

public final class AppCacheService: Sendable {
    public static let shared = AppCacheService()

    private let cacheDirectoryURL: URL

    public init(customCacheDirectory: URL? = nil) {
        if let custom = customCacheDirectory {
            self.cacheDirectoryURL = custom
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Caches")
            self.cacheDirectoryURL = base.appendingPathComponent("com.macappcleaner")
        }
    }

    private func ensureDirectoryExists() {
        if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private var appsCacheFile: URL {
        cacheDirectoryURL.appendingPathComponent("installed_apps_cache.json")
    }

    private var librariesCacheFile: URL {
        cacheDirectoryURL.appendingPathComponent("installed_libraries_cache.json")
    }

    private func diskRootCacheFile(scope: String) -> URL {
        cacheDirectoryURL.appendingPathComponent("disk_root_\(scope)_cache.json")
    }

    private func largeFilesCacheFile(minBytes: Int64, scope: String) -> URL {
        cacheDirectoryURL.appendingPathComponent("large_files_\(scope)_\(minBytes)_cache.json")
    }

    // MARK: - Apps Cache
    public func saveApps(_ apps: [InstalledApp]) {
        ensureDirectoryExists()
        Task.detached(priority: .utility) { [appsCacheFile] in
            let entry = CacheEntry(data: apps)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(entry) {
                try? data.write(to: appsCacheFile, options: .atomic)
            }
        }
    }

    public func loadCachedApps() -> (apps: [InstalledApp], date: Date)? {
        guard FileManager.default.fileExists(atPath: appsCacheFile.path),
              let data = try? Data(contentsOf: appsCacheFile) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(CacheEntry<[InstalledApp]>.self, from: data) else {
            return nil
        }
        return (apps: entry.data, date: entry.timestamp)
    }

    // MARK: - Libraries Cache
    public func saveLibraries(_ libraries: [InstalledLibrary]) {
        ensureDirectoryExists()
        Task.detached(priority: .utility) { [librariesCacheFile] in
            let entry = CacheEntry(data: libraries)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(entry) {
                try? data.write(to: librariesCacheFile, options: .atomic)
            }
        }
    }

    public func loadCachedLibraries() -> (libraries: [InstalledLibrary], date: Date)? {
        guard FileManager.default.fileExists(atPath: librariesCacheFile.path),
              let data = try? Data(contentsOf: librariesCacheFile) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(CacheEntry<[InstalledLibrary]>.self, from: data) else {
            return nil
        }
        return (libraries: entry.data, date: entry.timestamp)
    }

    // MARK: - Disk Root Cache
    public func saveDiskRoot(_ root: DiskItem, scope: String = "home") {
        ensureDirectoryExists()
        let targetFile = diskRootCacheFile(scope: scope)
        Task.detached(priority: .utility) {
            let entry = CacheEntry(data: root)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(entry) {
                try? data.write(to: targetFile, options: .atomic)
            }
        }
    }

    public func loadCachedDiskRoot(scope: String = "home") -> (item: DiskItem, date: Date)? {
        let targetFile = diskRootCacheFile(scope: scope)
        guard FileManager.default.fileExists(atPath: targetFile.path),
              let data = try? Data(contentsOf: targetFile) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(CacheEntry<DiskItem>.self, from: data) else {
            return nil
        }
        return (item: entry.data, date: entry.timestamp)
    }

    // MARK: - Large Files Cache
    public func saveLargeFiles(_ files: [DiskItem], minBytes: Int64, scope: String = "home") {
        ensureDirectoryExists()
        let targetFile = largeFilesCacheFile(minBytes: minBytes, scope: scope)
        Task.detached(priority: .utility) {
            let entry = CacheEntry(data: files)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(entry) {
                try? data.write(to: targetFile, options: .atomic)
            }
        }
    }

    public func loadCachedLargeFiles(minBytes: Int64, scope: String = "home") -> (files: [DiskItem], date: Date)? {
        let targetFile = largeFilesCacheFile(minBytes: minBytes, scope: scope)
        if FileManager.default.fileExists(atPath: targetFile.path),
           let data = try? Data(contentsOf: targetFile) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let entry = try? decoder.decode(CacheEntry<[DiskItem]>.self, from: data) {
                return (files: entry.data, date: entry.timestamp)
            }
        }
        if scope == "home" {
            let legacyFile = cacheDirectoryURL.appendingPathComponent("large_files_\(minBytes)_cache.json")
            if FileManager.default.fileExists(atPath: legacyFile.path),
               let data = try? Data(contentsOf: legacyFile) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let entry = try? decoder.decode(CacheEntry<[DiskItem]>.self, from: data) {
                    return (files: entry.data, date: entry.timestamp)
                }
            }
        }
        return nil
    }

    // MARK: - Clear Cache
    public func clearAllCache() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL)
    }
}
