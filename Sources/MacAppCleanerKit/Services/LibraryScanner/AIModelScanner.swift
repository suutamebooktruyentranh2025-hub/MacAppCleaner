import Foundation

public final class AIModelScanner: LibraryProvider, Sendable {
    public let category: LibraryCategory = .aiModels

    private let customOllamaManifestsPath: URL?
    private let customHuggingFaceHubPath: URL?
    private let customLMStudioPath: URL?

    public init(
        ollamaManifestsPath: URL? = nil,
        huggingFaceHubPath: URL? = nil,
        lmStudioPath: URL? = nil
    ) {
        self.customOllamaManifestsPath = ollamaManifestsPath
        self.customHuggingFaceHubPath = huggingFaceHubPath
        self.customLMStudioPath = lmStudioPath
    }

    public func scanLibraries() async -> [InstalledLibrary] {
        var results: [InstalledLibrary] = []

        // 1. Scan Ollama Models
        results.append(contentsOf: scanOllamaModels())

        // 2. Scan Hugging Face Hub Cache
        results.append(contentsOf: scanHuggingFaceModels())

        // 3. Scan LM Studio Models
        results.append(contentsOf: scanLMStudioModels())

        // 4. Scan Jan.ai Models
        results.append(contentsOf: scanJanModels())

        return results.sorted { $0.size > $1.size }
    }

    // MARK: - Ollama Scanner
    private func scanOllamaModels() -> [InstalledLibrary] {
        let home = NSHomeDirectory()
        let manifestsBaseURL = customOllamaManifestsPath ?? URL(fileURLWithPath: "\(home)/.ollama/models/manifests")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: manifestsBaseURL.path) else { return [] }

        var results: [InstalledLibrary] = []
        let enumerator = fileManager.enumerator(
            at: manifestsBaseURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            // Parse manifest JSON
            guard let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Calculate model size from layer sizes
            var totalSize: Int64 = 0
            if let config = json["config"] as? [String: Any], let configSize = config["size"] as? Int64 {
                totalSize += configSize
            }
            if let layers = json["layers"] as? [[String: Any]] {
                for layer in layers {
                    if let size = layer["size"] as? Int64 {
                        totalSize += size
                    } else if let sizeNum = layer["size"] as? NSNumber {
                        totalSize += sizeNum.int64Value
                    }
                }
            }

            // Derive human-readable name e.g. "qwen2.5:7b" or "gemma4:12b"
            let relativePath = fileURL.path.replacingOccurrences(of: manifestsBaseURL.path, with: "")
            let components = relativePath.split(separator: "/").map(String.init)

            var modelName = fileURL.lastPathComponent
            var version: String? = nil

            if components.count >= 2 {
                let tag = components.last ?? ""
                let name = components[components.count - 2]
                modelName = "\(name):\(tag)"
                version = tag
            } else if let last = components.last {
                modelName = last
            }

            // Clean registry prefix like "registry.ollama.ai/library/" if present
            if modelName.contains("registry.ollama.ai/library/") {
                modelName = modelName.replacingOccurrences(of: "registry.ollama.ai/library/", with: "")
            }

            results.append(InstalledLibrary(
                name: modelName,
                version: version,
                category: .aiModels,
                installPath: fileURL,
                size: totalSize,
                riskLevel: .safe,
                dependencies: [],
                requiredBy: [],
                descriptionText: "Mô hình Ollama (Tệp manifest & layer blobs)",
                isSystemProtected: false
            ))
        }

        return results
    }

    // MARK: - Hugging Face Hub Cache Scanner
    private func scanHuggingFaceModels() -> [InstalledLibrary] {
        let home = NSHomeDirectory()
        let hfBaseURL = customHuggingFaceHubPath ?? URL(fileURLWithPath: "\(home)/.cache/huggingface/hub")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: hfBaseURL.path) else { return [] }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: hfBaseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [InstalledLibrary] = []

        for itemURL in contents {
            let folderName = itemURL.lastPathComponent
            guard folderName.hasPrefix("models--") else { continue }

            // Extract repo name: models--org--name -> org/name
            let rawRepo = folderName.dropFirst("models--".count)
            let formattedName = rawRepo.replacingOccurrences(of: "--", with: "/")
            let size = calculateDirectorySize(at: itemURL)

            results.append(InstalledLibrary(
                name: formattedName,
                version: "Hub Cache",
                category: .aiModels,
                installPath: itemURL,
                size: size,
                riskLevel: .safe,
                dependencies: [],
                requiredBy: [],
                descriptionText: "Mô hình Hugging Face Transformers / Diffusers cache",
                isSystemProtected: false
            ))
        }

        return results
    }

    // MARK: - LM Studio Scanner
    private func scanLMStudioModels() -> [InstalledLibrary] {
        let home = NSHomeDirectory()
        let searchDirs = [
            customLMStudioPath ?? URL(fileURLWithPath: "\(home)/.cache/lm-studio/models"),
            URL(fileURLWithPath: "\(home)/.lmstudio/models")
        ]

        var results: [InstalledLibrary] = []
        let fileManager = FileManager.default

        for baseDir in searchDirs {
            guard fileManager.fileExists(atPath: baseDir.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for itemURL in contents {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { continue }

                let size = isDir.boolValue ? calculateDirectorySize(at: itemURL) : (try? fileManager.attributesOfItem(atPath: itemURL.path)[.size] as? Int64) ?? 0

                results.append(InstalledLibrary(
                    name: "lm-studio/\(itemURL.lastPathComponent)",
                    version: "Local GGUF",
                    category: .aiModels,
                    installPath: itemURL,
                    size: size,
                    riskLevel: .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: "Mô hình LM Studio local LLM",
                    isSystemProtected: false
                ))
            }
        }

        return results
    }

    // MARK: - Jan.ai Scanner
    private func scanJanModels() -> [InstalledLibrary] {
        let home = NSHomeDirectory()
        let searchDirs = [
            URL(fileURLWithPath: "\(home)/jan/models"),
            URL(fileURLWithPath: "\(home)/.jan/models")
        ]

        var results: [InstalledLibrary] = []
        let fileManager = FileManager.default

        for baseDir in searchDirs {
            guard fileManager.fileExists(atPath: baseDir.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for itemURL in contents {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { continue }

                let size = isDir.boolValue ? calculateDirectorySize(at: itemURL) : (try? fileManager.attributesOfItem(atPath: itemURL.path)[.size] as? Int64) ?? 0

                results.append(InstalledLibrary(
                    name: "jan/\(itemURL.lastPathComponent)",
                    version: "Local Model",
                    category: .aiModels,
                    installPath: itemURL,
                    size: size,
                    riskLevel: .safe,
                    dependencies: [],
                    requiredBy: [],
                    descriptionText: "Mô hình Jan.ai offline LLM",
                    isSystemProtected: false
                ))
            }
        }

        return results
    }

    private func calculateDirectorySize(at url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
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
