import Foundation

public enum SafetyGuardError: Error, Equatable, Sendable {
    case systemFileProtected
    case userAccountSecretProtected
    case criticalSystemAppProtected
}

public final class SafetyGuardService: Sendable {
    public static let shared = SafetyGuardService()

    public init() {}

    private let protectedSystemPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/vm",
        "/private/var/db",
        "/private/etc",
        "/Library/Apple"
    ]

    private let protectedUserDirectories: [String] = [
        ".ssh",
        "Library/Keychains",
        "Library/Accounts"
    ]

    public func isSystemProtected(url: URL) -> Bool {
        let path = url.standardized.path

        // Check root-level system prefixes
        for prefix in protectedSystemPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }

        // Check sensitive user directories
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardized.path
        for rel in protectedUserDirectories {
            let sensitivePath = (homePath as NSString).appendingPathComponent(rel)
            if path == sensitivePath || path.hasPrefix(sensitivePath + "/") {
                return true
            }
        }

        // Check if inside /System/Applications
        if path.hasPrefix("/System/Applications") {
            return true
        }

        return false
    }

    public func isProtectedApp(bundleIdentifier: String?, bundleURL: URL) -> Bool {
        if isSystemProtected(url: bundleURL) {
            return true
        }
        if let id = bundleIdentifier?.lowercased() {
            if id.hasPrefix("com.apple.") {
                return true
            }
        }
        return false
    }

    public func validateDeletion(url: URL) throws {
        if isSystemProtected(url: url) {
            throw SafetyGuardError.systemFileProtected
        }
    }
}
