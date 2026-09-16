import Foundation

public final class PythonPackageScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .python
    private let searchPaths: [URL]

    public init(searchPaths: [URL]? = nil) {
        if let paths = searchPaths {
            self.searchPaths = paths
        } else {
            var defaultPaths: [URL] = []
            let home = NSHomeDirectory()
            let fileManager = FileManager.default

            // 1. System/Admin Python paths
            let libPython = URL(fileURLWithPath: "/Library/Python")
            if let vers = try? fileManager.contentsOfDirectory(at: libPython, includingPropertiesForKeys: nil) {
                for v in vers {
                    defaultPaths.append(v.appendingPathComponent("site-packages"))
                }
            }

            // 2. User Python paths
            let userPython = URL(fileURLWithPath: "\(home)/Library/Python")
            if let vers = try? fileManager.contentsOfDirectory(at: userPython, includingPropertiesForKeys: nil) {
                for v in vers {
                    defaultPaths.append(v.appendingPathComponent("lib/python/site-packages"))
                }
            }

            // 3. Homebrew Python paths
            let brewLib = URL(fileURLWithPath: "/opt/homebrew/lib")
            if let items = try? fileManager.contentsOfDirectory(at: brewLib, includingPropertiesForKeys: nil) {
                for item in items where item.lastPathComponent.hasPrefix("python") {
                    defaultPaths.append(item.appendingPathComponent("site-packages"))
                }
            }

            self.searchPaths = defaultPaths
        }
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []

        for sitePackages in searchPaths {
            guard FileManager.default.fileExists(atPath: sitePackages.path) else { continue }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: sitePackages,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            // Group dist-info folders
            let distInfos = contents.filter { $0.lastPathComponent.hasSuffix(".dist-info") }

            for dist in distInfos {
                let metadataURL = dist.appendingPathComponent("METADATA")
                guard FileManager.default.fileExists(atPath: metadataURL.path),
                      let content = try? String(contentsOf: metadataURL, encoding: .utf8) else {
                    continue
                }

                var name: String?
                var version: String?
                var summary: String?

                for line in content.components(separatedBy: .newlines) {
                    if line.hasPrefix("Name: ") {
                        name = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("Version: ") {
                        version = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("Summary: ") {
                        summary = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    }
                }

                guard let pkgName = name, !pkgName.isEmpty else { continue }

                // Associated package directory or dist-info itself
                let mainPackageURL = sitePackages.appendingPathComponent(pkgName)
                let targetURL = FileManager.default.fileExists(atPath: mainPackageURL.path) ? mainPackageURL : dist
                let size = calculateDirectorySize(at: targetURL) + calculateDirectorySize(at: dist)

                let lib = InstalledLibrary(
                    name: pkgName,
                    version: version,
                    category: .python,
                    installPath: targetURL,
                    size: size,
                    riskLevel: .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: summary ?? "Thư viện Python (pip package)",
                    isSystemProtected: false
                )
                results.append(lib)
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
