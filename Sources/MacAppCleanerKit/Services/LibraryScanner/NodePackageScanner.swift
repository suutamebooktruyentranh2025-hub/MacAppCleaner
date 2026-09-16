import Foundation

public final class NodePackageScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .node
    private let searchPaths: [URL]

    public init(searchPaths: [URL]? = nil) {
        if let paths = searchPaths {
            self.searchPaths = paths
        } else {
            var defaultPaths: [URL] = [
                URL(fileURLWithPath: "/opt/homebrew/lib/node_modules"),
                URL(fileURLWithPath: "/usr/local/lib/node_modules")
            ]
            // Add NVM paths if present
            let home = NSHomeDirectory()
            let nvmDir = URL(fileURLWithPath: "\(home)/.nvm/versions/node")
            if let versions = try? FileManager.default.contentsOfDirectory(at: nvmDir, includingPropertiesForKeys: nil) {
                for ver in versions {
                    defaultPaths.append(ver.appendingPathComponent("lib/node_modules"))
                }
            }
            self.searchPaths = defaultPaths
        }
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []

        for dir in searchPaths {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for moduleDir in contents {
                guard (try? moduleDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let moduleName = moduleDir.lastPathComponent
                // Skip npm itself if present in global node_modules
                if moduleName == "npm" || moduleName == "corepack" { continue }

                // Check package.json
                let pkgJsonURL = moduleDir.appendingPathComponent("package.json")
                var version: String?
                var desc: String?

                if FileManager.default.fileExists(atPath: pkgJsonURL.path),
                   let data = try? Data(contentsOf: pkgJsonURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    version = json["version"] as? String
                    desc = json["description"] as? String
                }

                let size = calculateDirectorySize(at: moduleDir)
                let lib = InstalledLibrary(
                    name: moduleName,
                    version: version,
                    category: .node,
                    installPath: moduleDir,
                    size: size,
                    riskLevel: .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: desc ?? "Gói Node.js Global Module",
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
