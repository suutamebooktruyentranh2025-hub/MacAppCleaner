import Foundation

public final class QuickLookScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .quickLook
    private let searchPaths: [URL]
    private let safetyGuard: SafetyGuardService

    public init(
        searchPaths: [URL] = [
            URL(fileURLWithPath: "/Library/QuickLook"),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Library/QuickLook"),
            URL(fileURLWithPath: "/Library/PreferencePanes"),
            URL(fileURLWithPath: "\(NSHomeDirectory())/Library/PreferencePanes")
        ],
        safetyGuard: SafetyGuardService = .shared
    ) {
        self.searchPaths = searchPaths
        self.safetyGuard = safetyGuard
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []
        let validExtensions = Set(["qlgenerator", "prefpane"])

        for dir in searchPaths {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents where validExtensions.contains(item.pathExtension.lowercased()) {
                let name = item.lastPathComponent
                let size = calculateDirectorySize(at: item)
                let version = extractVersion(from: item)
                let isProtected = safetyGuard.isSystemProtected(url: item) || item.path.hasPrefix("/System")

                let desc = item.pathExtension.lowercased() == "qlgenerator" ? "Tiện ích QuickLook" : "Bảng Cài đặt Preference Pane"

                let lib = InstalledLibrary(
                    name: name,
                    version: version,
                    category: .quickLook,
                    installPath: item,
                    size: size,
                    riskLevel: isProtected ? .systemProtected : .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: desc,
                    isSystemProtected: isProtected
                )
                results.append(lib)
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private func extractVersion(from bundleURL: URL) -> String? {
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
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
