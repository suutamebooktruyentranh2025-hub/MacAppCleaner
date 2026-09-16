import Foundation

public enum LibraryRemovalError: LocalizedError, Sendable, Equatable {
    case systemProtected(name: String)
    case hasDependencies(name: String, dependents: [String])
    case executionFailed(name: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .systemProtected(let name):
            return "Thư viện '\(name)' là thành phần hệ thống được macOS bảo vệ và không thể xóa."
        case .hasDependencies(let name, let dependents):
            let list = dependents.joined(separator: ", ")
            return "Không thể xóa '\(name)' vì các công cụ sau đang phụ thuộc vào nó: \(list)."
        case .executionFailed(let name, let message):
            return "Gỡ bỏ '\(name)' thất bại: \(message)"
        }
    }
}

public final class SafeLibraryRemovalService: Sendable {
    public static let shared = SafeLibraryRemovalService()

    private let safetyGuard: SafetyGuardService
    private let trashService: TrashService

    public init(
        safetyGuard: SafetyGuardService = .shared,
        trashService: TrashService = .shared
    ) {
        self.safetyGuard = safetyGuard
        self.trashService = trashService
    }

    /// Checks if other packages or tools depend on this library
    public func checkReverseDependencies(for library: InstalledLibrary) async -> [String] {
        guard library.category == .homebrew else {
            return []
        }

        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewExe = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewExe)
                process.arguments = ["uses", "--installed", library.name]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if let output = String(data: data, encoding: .utf8) {
                        let lines = output.components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        continuation.resume(returning: lines)
                        return
                    }
                } catch {
                    // Fallback
                }
                continuation.resume(returning: [])
            }
        }
    }

    /// Safely removes an installed library using either TrashService or official CLI command
    public func removeLibrary(_ library: InstalledLibrary) async throws {
        // 1. Guard against system protection
        guard !library.isSystemProtected else {
            throw LibraryRemovalError.systemProtected(name: library.name)
        }
        guard !safetyGuard.isSystemProtected(url: library.installPath) else {
            throw LibraryRemovalError.systemProtected(name: library.name)
        }
        if library.installPath.path.hasPrefix("/System") {
            throw LibraryRemovalError.systemProtected(name: library.name)
        }

        // 2. Package Managers (CLI uninstallation)
        switch library.category {
        case .homebrew:
            try await runCLICommand(
                executable: findBrewExecutable(),
                arguments: ["uninstall", library.name],
                libraryName: library.name
            )
        case .node:
            try await runCLICommand(
                executable: findExecutable(named: "npm"),
                arguments: ["uninstall", "-g", library.name],
                libraryName: library.name
            )
        case .python:
            // Try pip uninstall, or trash site-packages directory
            if let pipExe = findExecutable(named: "pip3") ?? findExecutable(named: "pip") {
                do {
                    try await runCLICommand(
                        executable: pipExe,
                        arguments: ["uninstall", "-y", library.name],
                        libraryName: library.name
                    )
                    return
                } catch {
                    // Fallback to trashing folder
                }
            }
            try trashService.trashItem(at: library.installPath)

        case .aiModels:
            if let ollamaExe = findExecutable(named: "ollama"),
               library.descriptionText?.contains("Ollama") == true {
                do {
                    try await runCLICommand(
                        executable: ollamaExe,
                        arguments: ["rm", library.name],
                        libraryName: library.name
                    )
                    return
                } catch {
                    // Fallback to filesystem trash
                }
            }
            try trashService.trashItem(at: library.installPath)

        case .frameworks, .audioPlugins, .quickLook, .all:
            // Safe filesystem trash with Put Back support
            try trashService.trashItem(at: library.installPath)
        }
    }

    private func findBrewExecutable() -> String? {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    private func findExecutable(named name: String) -> String? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(NSHomeDirectory())/.nvm/versions/node/current/bin/\(name)"
        ]
        return paths.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    private func runCLICommand(
        executable: String?,
        arguments: [String],
        libraryName: String
    ) async throws {
        guard let exe = executable, FileManager.default.fileExists(atPath: exe) else {
            throw LibraryRemovalError.executionFailed(
                name: libraryName,
                message: "Không tìm thấy công cụ dòng lệnh cần thiết trên hệ thống."
            )
        }

        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: exe)
                process.arguments = arguments
                let errPipe = Pipe()
                process.standardError = errPipe
                process.standardOutput = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? "Mã lỗi: \(process.terminationStatus)"
                        continuation.resume(throwing: LibraryRemovalError.executionFailed(
                            name: libraryName,
                            message: errStr
                        ))
                    }
                } catch {
                    continuation.resume(throwing: LibraryRemovalError.executionFailed(
                        name: libraryName,
                        message: error.localizedDescription
                    ))
                }
            }
        }
    }
}
