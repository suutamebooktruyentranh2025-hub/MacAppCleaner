import Foundation
import AppKit

public final class PermissionManager: Sendable {
    public static let shared = PermissionManager()

    public init() {}

    /// Checks if the application currently has Full Disk Access (FDA).
    /// On macOS, certain directories like ~/Library/Safari, ~/Library/Mail, or ~/.Trash
    /// are strictly gated by Full Disk Access TCC entitlements.
    public func hasFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        // Directories strictly guarded by macOS TCC (Full Disk Access / kTCCServiceSystemPolicyAllFiles)
        let protectedPaths = [
            "\(home)/Library/Safari",
            "\(home)/Library/Mail",
            "\(home)/Library/Cookies",
            "\(home)/Library/Suggestions",
            "\(home)/.Trash"
        ]

        for path in protectedPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: path)
                // Successfully enumerated at least one strictly protected folder -> FDA granted!
                return true
            } catch {
                // Denied on this path, continue checking others
                continue
            }
        }
        return false
    }

    /// Resets TCC entry for this app to eliminate stale code requirement cache
    @discardableResult
    public func resetTCCPermissions() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "SystemPolicyAllFiles", "com.macappcleaner.app"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Full Disk Access
    @MainActor
    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Automation
    @MainActor
    public func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
