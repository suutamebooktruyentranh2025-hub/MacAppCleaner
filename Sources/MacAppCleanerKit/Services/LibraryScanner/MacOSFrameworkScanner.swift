import Foundation

public final class MacOSFrameworkScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .frameworks
    private let searchPaths: [URL]
    private let safetyGuard: SafetyGuardService

    public init(
        searchPaths: [URL] = [
            URL(fileURLWithPath: "/Library/Frameworks"),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Frameworks")
        ],
        safetyGuard: SafetyGuardService = .shared
    ) {
        self.searchPaths = searchPaths
        self.safetyGuard = safetyGuard
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []

        for dir in searchPaths {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension.lowercased() == "framework" {
                let name = url.deletingPathExtension().lastPathComponent
                let size = calculateDirectorySize(at: url)
                let version = extractVersion(from: url)
                let isProtected = safetyGuard.isSystemProtected(url: url) || url.path.hasPrefix("/System")

                let riskLevel: LibraryRiskLevel = isProtected ? .systemProtected : .safe

                let lib = InstalledLibrary(
                    name: name,
                    version: version,
                    category: .frameworks,
                    installPath: url,
                    size: size,
                    riskLevel: riskLevel,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: "Gói macOS Framework",
                    isSystemProtected: isProtected
                )
                results.append(lib)
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func extractVersion(from frameworkURL: URL) -> String? {
        let possiblePlistURLs = [
            frameworkURL.appendingPathComponent("Resources/Info.plist"),
            frameworkURL.appendingPathComponent("Versions/Current/Resources/Info.plist"),
            frameworkURL.appendingPathComponent("Info.plist")
        ]

        for plistURL in possiblePlistURLs {
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
