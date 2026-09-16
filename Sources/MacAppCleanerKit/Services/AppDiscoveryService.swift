import Foundation

public final class AppDiscoveryService: Sendable {
    public static let shared = AppDiscoveryService()

    public init() {}

    public func discoverInstalledApps() async -> [InstalledApp] {
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [InstalledApp] = []
        let fileManager = FileManager.default

        for directory in searchDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for itemURL in contents where itemURL.pathExtension == "app" {
                if let app = parseAppBundle(at: itemURL) {
                    apps.append(app)
                }
            }
        }

        // Sort by name alphabetically
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func parseAppBundle(at bundleURL: URL) -> InstalledApp? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent

        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
        let isSystemApp = SafetyGuardService.shared.isProtectedApp(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL)

        // Mach-O binary architecture detection
        let executableName = plist["CFBundleExecutable"] as? String
        var architecture: AppArchitecture = .arm64
        if let execName = executableName {
            let execURL = bundleURL.appendingPathComponent("Contents/MacOS/\(execName)")
            architecture = detectArchitecture(of: execURL)
        }

        let size = calculateAppSize(at: bundleURL)
        let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path)
        let installDate = attrs?[.creationDate] as? Date ?? attrs?[.modificationDate] as? Date

        return InstalledApp(
            name: name,
            bundleURL: bundleURL,
            bundleIdentifier: bundleIdentifier,
            version: version,
            architecture: architecture,
            installDate: installDate,
            appSize: size,
            residualFiles: [],
            isSystemApp: isSystemApp
        )
    }

    public func detectArchitecture(of executableURL: URL) -> AppArchitecture {
        guard let handle = try? FileHandle(forReadingFrom: executableURL) else {
            return .unknown
        }
        defer { try? handle.close() }

        guard let magicData = try? handle.read(upToCount: 4), magicData.count == 4 else {
            return .unknown
        }

        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }

        // Universal Fat Binary
        if magic == 0xCAFEBABE || magic == 0xBEBAFECA {
            return .universal
        }
        // 64-bit Mach-O (arm64 or x86_64)
        if magic == 0xFEEDFACF || magic == 0xCFFAEDFE {
            // Read CPU type at offset 4
            if let cpuData = try? handle.read(upToCount: 4), cpuData.count == 4 {
                let cpuType = cpuData.withUnsafeBytes { $0.load(as: UInt32.self) }
                // CPU_TYPE_ARM64 = 0x0100000C
                if cpuType == 0x0100000C || cpuType == 0x0C000001 {
                    return .arm64
                }
                // CPU_TYPE_X86_64 = 0x01000007
                if cpuType == 0x01000007 || cpuType == 0x07000001 {
                    return .intel
                }
            }
            return .arm64
        }

        return .unknown
    }

    private func calculateAppSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
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
