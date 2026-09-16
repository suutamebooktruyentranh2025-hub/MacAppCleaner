import Foundation
import AppKit

public final class AppProcessManager: Sendable {
    public static let shared = AppProcessManager()

    public init() {}

    /// Returns all running applications that match either the bundle identifier or bundle URL.
    public func runningProcesses(bundleURL: URL, bundleIdentifier: String?) -> [NSRunningApplication] {
        var matched: [NSRunningApplication] = []
        var seenPIDs: Set<pid_t> = []

        // 1. Search by bundle identifier
        if let bundleID = bundleIdentifier, !bundleID.isEmpty {
            let byID = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            for app in byID {
                if seenPIDs.insert(app.processIdentifier).inserted {
                    matched.append(app)
                }
            }
        }

        // 2. Search by bundle URL or executable path
        let standardURL = bundleURL.standardizedFileURL
        let allRunning = NSWorkspace.shared.runningApplications
        for app in allRunning {
            guard !seenPIDs.contains(app.processIdentifier) else { continue }
            if let appURL = app.bundleURL?.standardizedFileURL {
                if appURL == standardURL || appURL.path.hasPrefix(standardURL.path + "/") {
                    seenPIDs.insert(app.processIdentifier)
                    matched.append(app)
                    continue
                }
            }

            if let execURL = app.executableURL?.standardizedFileURL {
                if execURL.path.hasPrefix(standardURL.path + "/") {
                    seenPIDs.insert(app.processIdentifier)
                    matched.append(app)
                }
            }
        }

        return matched
    }

    /// Checks if any processes associated with the app are running.
    public func isAppRunning(bundleURL: URL, bundleIdentifier: String?) -> Bool {
        !runningProcesses(bundleURL: bundleURL, bundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Attempts to terminate running processes gracefully, with optional force quit fallback.
    public func terminateProcesses(_ processes: [NSRunningApplication], force: Bool = false) async -> Bool {
        guard !processes.isEmpty else { return true }

        for proc in processes {
            if force {
                _ = proc.forceTerminate()
            } else {
                _ = proc.terminate()
            }
        }

        // Wait up to 1.5 seconds for processes to exit
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let stillRunning = processes.filter { !$0.isTerminated }
            if stillRunning.isEmpty {
                return true
            }
        }

        // If not terminated and not yet forced, force quit if requested
        if !force {
            for proc in processes where !proc.isTerminated {
                _ = proc.forceTerminate()
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return processes.allSatisfy { $0.isTerminated }
    }

    /// Convenience to terminate all processes for an app bundle.
    public func terminateApp(bundleURL: URL, bundleIdentifier: String?, force: Bool = false) async -> Bool {
        let procs = runningProcesses(bundleURL: bundleURL, bundleIdentifier: bundleIdentifier)
        guard !procs.isEmpty else { return true }
        return await terminateProcesses(procs, force: force)
    }
}
