import Foundation

public final class AudioPluginScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .audioPlugins
    private let searchPaths: [URL]
    private let safetyGuard: SafetyGuardService

    public init(
        searchPaths: [URL] = [
            URL(fileURLWithPath: "/Library/Audio/Plug-Ins"),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Audio/Plug-Ins")
        ],
        safetyGuard: SafetyGuardService = .shared
    ) {
        self.searchPaths = searchPaths
        self.safetyGuard = safetyGuard
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []
        let validExtensions = Set(["vst", "vst3", "component", "clap", "aaxplugin"])

        for rootDir in searchPaths {
            guard FileManager.default.fileExists(atPath: rootDir.path) else { continue }

            // If rootDir itself contains plugin bundles directly (e.g. In tests)
            if let directContents = try? FileManager.default.contentsOfDirectory(
                at: rootDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for item in directContents {
                    if validExtensions.contains(item.pathExtension.lowercased()) {
                        results.append(createLibrary(for: item))
                    } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        // Subdirectory (e.g. /Library/Audio/Plug-Ins/VST3)
                        if let subContents = try? FileManager.default.contentsOfDirectory(
                            at: item,
                            includingPropertiesForKeys: nil,
                            options: [.skipsHiddenFiles]
                        ) {
                            for subItem in subContents where validExtensions.contains(subItem.pathExtension.lowercased()) {
                                results.append(createLibrary(for: subItem))
                            }
                        }
                    }
                }
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func createLibrary(for url: URL) -> InstalledLibrary {
        let name = url.lastPathComponent
        let size = calculateDirectorySize(at: url)
        let version = extractVersion(from: url)
        let isProtected = safetyGuard.isSystemProtected(url: url)

        let pluginType = url.pathExtension.uppercased()
        return InstalledLibrary(
            name: name,
            version: version,
            category: .audioPlugins,
            installPath: url,
            size: size,
            riskLevel: isProtected ? .systemProtected : .safe,
            dependencies: [],
            requiredBy: [],
            descriptionText: "Định dạng Audio Plugin: \(pluginType)",
            isSystemProtected: isProtected
        )
    }

    private func extractVersion(from pluginURL: URL) -> String? {
        let plistURL = pluginURL.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: plistURL.path),
           let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let shortVer = plist["CFBundleShortVersionString"] as? String, !shortVer.isEmpty {
                return shortVer
            }
            if let ver = plist["CFBundleVersion"] as? String, !ver.isEmpty {
                return ver
            }
        }
        return nil
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
