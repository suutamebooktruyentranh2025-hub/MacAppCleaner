import Foundation

public final class HomebrewScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .homebrew
    private let cellarPaths: [URL]
    private let runBrewCLI: Bool

    public init(
        cellarPaths: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/Cellar"),
            URL(fileURLWithPath: "/usr/local/Cellar")
        ],
        runBrewCLI: Bool = true
    ) {
        self.cellarPaths = cellarPaths
        self.runBrewCLI = runBrewCLI
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        // Fast direct directory inspection first
        var results: [InstalledLibrary] = []

        for cellar in cellarPaths {
            guard FileManager.default.fileExists(atPath: cellar.path) else { continue }
            guard let packages = try? FileManager.default.contentsOfDirectory(
                at: cellar,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for pkgDir in packages {
                guard (try? pkgDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let name = pkgDir.lastPathComponent

                // In Cellar, versions are subdirectories (e.g. wget/1.21.4)
                let versions = (try? FileManager.default.contentsOfDirectory(at: pkgDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                let latestVersionURL = versions.first ?? pkgDir
                let version = latestVersionURL.lastPathComponent

                let size = calculateDirectorySize(at: pkgDir)
                let lib = InstalledLibrary(
                    name: name,
                    version: version == name ? nil : version,
                    category: .homebrew,
                    installPath: pkgDir,
                    size: size,
                    riskLevel: .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: "Gói Homebrew Formula",
                    isSystemProtected: false
                )
                results.append(lib)
            }
        }

        // If Homebrew CLI is available and requested, enrich with dependencies
        if runBrewCLI && !results.isEmpty {
            return await enrichWithBrewCLI(libraries: results)
        }

        return results.sorted { $0.size > $1.size }
    }

    private func enrichWithBrewCLI(libraries: [InstalledLibrary]) async -> [InstalledLibrary] {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewExe = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return libraries
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewExe)
                process.arguments = ["info", "--json=v2", "--installed"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let formulae = json["formulae"] as? [[String: Any]] {
                        var updatedLibs: [InstalledLibrary] = []
                        let formulaDict = Dictionary(uniqueKeysWithValues: formulae.compactMap { dict -> (String, [String: Any])? in
                            guard let name = dict["name"] as? String else { return nil }
                            return (name, dict)
                        })

                        for lib in libraries {
                            if let info = formulaDict[lib.name] {
                                let deps = (info["dependencies"] as? [String]) ?? []
                                let desc = (info["desc"] as? String) ?? lib.descriptionText
                                updatedLibs.append(InstalledLibrary(
                                    id: lib.id,
                                    name: lib.name,
                                    version: lib.version,
                                    category: lib.category,
                                    installPath: lib.installPath,
                                    size: lib.size,
                                    riskLevel: lib.riskLevel,
                                    dependencies: deps,
                                    requiredBy: lib.requiredBy,
                                    descriptionText: desc,
                                    isSystemProtected: false
                                ))
                            } else {
                                updatedLibs.append(lib)
                            }
                        }
                        continuation.resume(returning: updatedLibs.sorted { $0.size > $1.size })
                        return
                    }
                } catch {
                    // Fallback to un-enriched
                }
                continuation.resume(returning: libraries.sorted { $0.size > $1.size })
            }
        }
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
