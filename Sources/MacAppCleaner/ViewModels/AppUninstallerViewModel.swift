import Foundation
import SwiftUI
import MacAppCleanerKit

public enum AppFilterCategory: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case userOnly = "Người dùng"
    case systemOnly = "Hệ thống"
    case large = "> 500MB"

    public var id: String { rawValue }
}

public enum AppSortOrder: String, CaseIterable, Identifiable {
    case name = "Tên (A-Z)"
    case size = "Dung lượng (Cao nhất)"
    case installDate = "Ngày cài đặt"

    public var id: String { rawValue }
}

@Observable
public final class AppUninstallerViewModel {
    public var apps: [InstalledApp] = []
    public var selectedApp: InstalledApp?
    public var isLoading: Bool = false
    public var isScanningResiduals: Bool = false
    public var searchText: String = ""
    public var selectedCategory: AppFilterCategory = .all
    public var sortOrder: AppSortOrder = .name
    public var isShowingConfirmModal: Bool = false
    public var alertTitle: String = "Không thể gỡ bỏ ứng dụng"
    public var errorMessage: String?
    public var showErrorAlert: Bool = false
    public var needsFullDiskAccess: Bool = false
    public var isRunningApp: Bool = false
    public var runningPIDs: [pid_t] = []
    public var isTerminatingApp: Bool = false
    public var isUninstalling: Bool = false
    public var lastCachedDate: Date?

    private let discoveryService = AppDiscoveryService.shared
    private let residualScanner = ResidualScanner()
    private let trashService = TrashService.shared
    private let cacheService = AppCacheService.shared

    public init() {
        if let cached = cacheService.loadCachedApps() {
            self.apps = cached.apps
            self.lastCachedDate = cached.date
            self.selectedApp = self.filteredApps.first
        }
    }

    public var filteredApps: [InstalledApp] {
        var result = apps

        // Category filter
        switch selectedCategory {
        case .all:
            break
        case .userOnly:
            result = result.filter { !$0.isSystemApp }
        case .systemOnly:
            result = result.filter { $0.isSystemApp }
        case .large:
            result = result.filter { $0.totalSize >= 500 * 1024 * 1024 }
        }

        // Search text
        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        // Sort order
        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            result.sort { $0.totalSize > $1.totalSize }
        case .installDate:
            result.sort { ($0.installDate ?? .distantPast) > ($1.installDate ?? .distantPast) }
        }

        return result
    }

    public var totalAppsSize: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    @MainActor
    public func loadApps(force: Bool = false) async {
        if !force && !apps.isEmpty {
            return
        }
        isLoading = true
        apps = await discoveryService.discoverInstalledApps()
        cacheService.saveApps(apps)
        lastCachedDate = Date()
        isLoading = false
        if selectedApp == nil, let first = filteredApps.first {
            await selectApp(first)
        }
    }

    @MainActor
    public func checkRunningState(for app: InstalledApp) {
        let procs = AppProcessManager.shared.runningProcesses(
            bundleURL: app.bundleURL,
            bundleIdentifier: app.bundleIdentifier
        )
        isRunningApp = !procs.isEmpty
        runningPIDs = procs.map(\.processIdentifier)
    }

    @MainActor
    public func terminateRunningApp() async -> Bool {
        guard let app = selectedApp else { return true }
        isTerminatingApp = true
        let success = await AppProcessManager.shared.terminateApp(
            bundleURL: app.bundleURL,
            bundleIdentifier: app.bundleIdentifier,
            force: true
        )
        checkRunningState(for: app)
        isTerminatingApp = false
        return success
    }

    @MainActor
    public func selectApp(_ app: InstalledApp) async {
        selectedApp = app
        checkRunningState(for: app)
        isScanningResiduals = true
        let residuals = await residualScanner.findResidualFiles(for: app)
        if var current = selectedApp, current.id == app.id {
            current.residualFiles = residuals
            selectedApp = current
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index].residualFiles = residuals
            }
        }
        isScanningResiduals = false
    }

    public func toggleResidualSelection(id: UUID) {
        guard var current = selectedApp else { return }
        if let idx = current.residualFiles.firstIndex(where: { $0.id == id }) {
            current.residualFiles[idx].isSelectedForDeletion.toggle()
            selectedApp = current
        }
    }

    public func selectAllResiduals(select: Bool) {
        guard var current = selectedApp else { return }
        for i in 0..<current.residualFiles.count {
            current.residualFiles[i].isSelectedForDeletion = select
        }
        selectedApp = current
    }

    @MainActor
    public func uninstallSelectedApp() async -> Bool {
        guard let app = selectedApp else { return false }

        // 1. Kiểm tra nếu app đang chạy
        checkRunningState(for: app)
        if isRunningApp {
            let pidList = runningPIDs.map(String.init).joined(separator: ", ")
            alertTitle = "Ứng dụng đang chạy"
            errorMessage = "Ứng dụng '\(app.name)' hiện đang chạy trên hệ thống (PID: \(pidList)). Vui lòng nhấn nút 'Thoát ứng dụng' hoặc đóng app trước khi xóa."
            needsFullDiskAccess = false
            showErrorAlert = true
            return false
        }

        isUninstalling = true
        defer { isUninstalling = false }

        var failedResiduals: [(file: RelatedFile, reason: String)] = []

        // 2. Chuyển gói ứng dụng (.app) vào Thùng Rác trước
        var appBundleTrashed = false
        do {
            try trashService.trashItem(at: app.bundleURL)
            appBundleTrashed = true
        } catch {
            // Nếu tệp không còn tồn tại trên đĩa (ví dụ đã được chuyển vào Thùng rác), coi như đã xóa thành công
            if !FileManager.default.fileExists(atPath: app.bundleURL.path) {
                appBundleTrashed = true
            } else {
                alertTitle = "Không thể gỡ bỏ ứng dụng"
                errorMessage = error.localizedDescription
                needsFullDiskAccess = false
                showErrorAlert = true
                return false
            }
        }

        // 3. Chuyển các tệp tàn dư đã chọn vào Thùng Rác
        for res in app.residualFiles where res.isSelectedForDeletion {
            do {
                try trashService.trashItem(at: res.url)
            } catch {
                if FileManager.default.fileExists(atPath: res.url.path) {
                    failedResiduals.append((res, error.localizedDescription))
                }
            }
        }

        // 4. Nếu gói ứng dụng (.app) đã vào Thùng Rác: Gỡ bỏ app khỏi danh sách hiển thị ngay lập tức!
        if appBundleTrashed {
            apps.removeAll { $0.id == app.id }
            cacheService.saveApps(apps)
            selectedApp = filteredApps.first
            if let next = selectedApp {
                await selectApp(next)
            }
        }

        // 5. Kết luận trạng thái phản hồi cho người dùng
        if failedResiduals.isEmpty {
            alertTitle = ""
            errorMessage = nil
            showErrorAlert = false
            needsFullDiskAccess = false
            return true
        } else {
            let failedNames = failedResiduals.map { $0.file.url.lastPathComponent }.joined(separator: ", ")
            alertTitle = "Đã chuyển ứng dụng vào Thùng Rác"
            errorMessage = "Đã gỡ bỏ gói ứng dụng '\(app.name)' thành công! Tuy nhiên còn \(failedResiduals.count) mục tàn dư (\(failedNames)) chưa thể dọn dẹp do macOS Sandbox bảo vệ thư mục Containers.\n\nĐể dọn sạch hoàn toàn các tệp này, bạn có thể cấp quyền Full Disk Access cho MacAppCleaner."
            needsFullDiskAccess = true
            showErrorAlert = true
            return true // Trả về true để đóng modal xác nhận xóa
        }
    }
}
