import Foundation

public enum TrashError: LocalizedError, Sendable, Equatable {
    case appIsRunning(appName: String, pids: [pid_t])
    case permissionDenied(path: String, message: String)
    case systemProtected(path: String)
    case trashingFailed(path: String, errorDescription: String)

    public var errorDescription: String? {
        switch self {
        case .appIsRunning(let appName, let pids):
            let pidList = pids.map(String.init).joined(separator: ", ")
            return "Ứng dụng '\(appName)' hiện đang chạy trên máy (PID: \(pidList)). Vui lòng đóng ứng dụng trước khi gỡ bỏ để tránh lỗi tệp bị khóa."
        case .permissionDenied(let path, let message):
            return "Không có quyền truy cập để xóa '\(path)'. \(message)"
        case .systemProtected(let path):
            return "Tệp '\(path)' là tệp hệ thống được macOS bảo vệ và không thể xóa."
        case .trashingFailed(let path, let errorDescription):
            return "Không thể chuyển '\(path)' vào Thùng Rác: \(errorDescription)"
        }
    }
}

public final class TrashService: Sendable {
    public static let shared = TrashService()
    private let safetyGuard: SafetyGuardService

    public init(safetyGuard: SafetyGuardService = .shared) {
        self.safetyGuard = safetyGuard
    }

    public func trashItem(at url: URL) throws {
        // Enforce safety whitelist first
        guard !safetyGuard.isSystemProtected(url: url) else {
            throw TrashError.systemProtected(path: url.path)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        // Apple native safe trash action
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch let nsError as NSError {
            // Check for permission denied (code 513 or POSIX EACCES/EPERM or OSStatus -5000)
            let isPermissionDenied = (nsError.domain == NSCocoaErrorDomain && nsError.code == 513)
                || nsError.domain == NSPOSIXErrorDomain && (nsError.code == Int(EACCES) || nsError.code == Int(EPERM))

            if isPermissionDenied {
                let isSystemOrAppsLocation = url.path.hasPrefix("/Applications") || url.path.hasPrefix("/Library")

                if isSystemOrAppsLocation {
                    // Fallback: Request Finder to delete the item (which invokes macOS Admin Touch ID / password prompt)
                    do {
                        try trashViaFinder(at: url)
                        return
                    } catch let finderError as NSError {
                        if finderError.code == -128 {
                            throw TrashError.permissionDenied(
                                path: url.lastPathComponent,
                                message: "Bạn đã hủy hộp thoại xác thực quyền Quản trị viên (Admin)."
                            )
                        }
                        throw TrashError.permissionDenied(
                            path: url.lastPathComponent,
                            message: "Tệp yêu cầu quyền Quản trị viên (Admin) hoặc đang bị khóa bởi hệ thống."
                        )
                    }
                } else {
                    // For user home directory (~/Library/Containers etc.), do NOT invoke Finder (which shows modal error)
                    // Attempt direct removal first
                    do {
                        try FileManager.default.removeItem(at: url)
                        return
                    } catch {
                        throw TrashError.permissionDenied(
                            path: url.lastPathComponent,
                            message: "Thư mục này được macOS Sandbox bảo vệ. Cần cấp quyền Full Disk Access trong Cài đặt để xóa."
                        )
                    }
                }
            }

            throw TrashError.trashingFailed(
                path: url.lastPathComponent,
                errorDescription: nsError.localizedDescription
            )
        }
    }

    public func trashFiles(_ files: [URL]) throws -> [URL] {
        var trashed: [URL] = []
        for file in files {
            try trashItem(at: file)
            trashed.append(file)
        }
        return trashed
    }

    private func trashViaFinder(at url: URL) throws {
        let script = """
        tell application "Finder"
            delete (POSIX file "\(url.path)")
        end tell
        """
        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&errorDict)
            if let err = errorDict {
                let code = (err[NSAppleScript.errorNumber] as? Int) ?? -1
                let msg = (err[NSAppleScript.errorMessage] as? String) ?? "Lỗi Finder không xác định"
                throw NSError(domain: "FinderError", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } else {
            throw NSError(domain: "FinderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo NSAppleScript"])
        }
    }
}
